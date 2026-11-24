-- =====================================================================
-- PROYECTO INTEGRADOR - SISTEMA DE DOMICILIOS
-- ENTREGA 3: Objetos procedimentales de la base de datos
--
-- Orden de ejecución:
--   1. 01_ProyectoIntegrador.sql      (tablas + datos de prueba)
--   2. 02_Entrega3_LenguajeProcedimental.sql   <- este archivo
--   3. 03_Entrega4_Backend.sql
--   4. 04_Pruebas_Entrega3_y_4.sql    (pruebas, una por una)
--
-- Este archivo solo CREA los objetos, por eso se puede ejecutar completo
-- (rayo) sin errores. Las pruebas de cada objeto están en
-- 04_Pruebas_Entrega3_y_4.sql.
-- Cada objeto se borra antes de crearse (DROP ... IF EXISTS), así el
-- script se puede volver a ejecutar sin el error "already exists".
-- =====================================================================
USE ProyectoIntegrador;


-- ---------------------------------------------------------------------
-- 1 -- Consulta con JOIN
-- sp_solicitudes_por_fecha: lista las solicitudes creadas en una fecha
-- dada, con el cliente, el origen (establecimiento o recogida externa),
-- el barrio y la comuna de entrega, el domiciliario, el estado, el
-- método de pago y la cantidad de incidentes registrados.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_solicitudes_por_fecha;

DELIMITER $$
CREATE PROCEDURE sp_solicitudes_por_fecha (IN p_fecha DATE)
BEGIN
    SELECT
        s.numeroSolicitud,
        s.horaCreacion,
        CONCAT(uc.nombre, ' ', uc.apellido_Paterno) AS cliente,
        IFNULL(e.nombreComercial, 'Recogida externa') AS origen,
        d.ubicacion AS direccion_entrega,
        b.nombreBarrio AS barrio,
        c.nombreComuna AS comuna,
        IFNULL(CONCAT(ud.nombre, ' ', ud.apellido_Paterno), 'Sin asignar') AS domiciliario,
        es.nombreEstadoSolicitud AS estado,
        mp.nombreMetodo AS metodo_pago,
        s.montoTotal,
        (SELECT COUNT(*)
           FROM Incidente i
          WHERE i.numeroSolicitud = s.numeroSolicitud) AS incidentes
    FROM Solicitud s
    INNER JOIN Usuario uc
        ON s.idCliente = uc.numeroIdentificacion
    INNER JOIN Direccion d
        ON s.idDireccion = d.idDireccion
    INNER JOIN Barrio b
        ON d.idBarrio = b.idBarrio
    INNER JOIN Comuna c
        ON b.idComuna = c.idComuna
    INNER JOIN EstadoSolicitud es
        ON s.idEstadoSolicitud = es.idEstadoSolicitud
    INNER JOIN MetodoPago mp
        ON s.idMetodoPago = mp.idMetodoPago
    LEFT JOIN Establecimiento e
        ON s.idEstablecimiento = e.idEstablecimiento
    LEFT JOIN Usuario ud
        ON s.idDomiciliario = ud.numeroIdentificacion
    WHERE s.fechaCreacion = p_fecha
    ORDER BY s.horaCreacion;
END $$
DELIMITER ;


-- ---------------------------------------------------------------------
-- 2 -- Funciones
-- Todas leen tablas, por eso se declaran READS SQL DATA (su resultado
-- cambia cuando cambian los datos). La única DETERMINISTIC es
-- fn_minutos_asignacion, que solo calcula con sus parámetros.
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_nombre_completo;
DROP FUNCTION IF EXISTS fn_solicitudes_cliente;
DROP FUNCTION IF EXISTS fn_total_movilizado_domiciliario;
DROP FUNCTION IF EXISTS fn_solicitudes_activas;
DROP FUNCTION IF EXISTS fn_minutos_asignacion;


-- 2a. fn_nombre_completo: nombre completo de un usuario (cliente o
--     domiciliario). Devuelve 'No registrado' si el documento no existe.
DELIMITER $$
CREATE FUNCTION fn_nombre_completo (p_documento INT)
RETURNS VARCHAR(310)
READS SQL DATA
BEGIN
    DECLARE v_nombre VARCHAR(310);

    IF p_documento IS NULL THEN
        RETURN NULL;
    END IF;

    SET v_nombre = (SELECT CONCAT(nombre, ' ', apellido_Paterno, ' ', apellido_Materno)
                      FROM Usuario
                     WHERE numeroIdentificacion = p_documento);

    RETURN IFNULL(v_nombre, 'No registrado');
END $$
DELIMITER ;


-- 2b. fn_solicitudes_cliente: cantidad de solicitudes finalizadas de un cliente
DELIMITER $$
CREATE FUNCTION fn_solicitudes_cliente (p_idCliente INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_cantidad INT DEFAULT 0;

    SELECT COUNT(*) INTO v_cantidad
    FROM Solicitud s
    INNER JOIN EstadoSolicitud es
        ON s.idEstadoSolicitud = es.idEstadoSolicitud
    WHERE s.idCliente = p_idCliente
      AND es.nombreEstadoSolicitud = 'Finalizada';

    RETURN v_cantidad;
END $$
DELIMITER ;


-- 2c. fn_total_movilizado_domiciliario: suma de los montos de las
--     solicitudes finalizadas por un domiciliario
DELIMITER $$
CREATE FUNCTION fn_total_movilizado_domiciliario (p_idDomiciliario INT)
RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(12,2) DEFAULT 0;

    SELECT IFNULL(SUM(s.montoTotal), 0) INTO v_total
    FROM Solicitud s
    INNER JOIN EstadoSolicitud es
        ON s.idEstadoSolicitud = es.idEstadoSolicitud
    WHERE s.idDomiciliario = p_idDomiciliario
      AND es.nombreEstadoSolicitud = 'Finalizada';

    RETURN v_total;
END $$
DELIMITER ;


-- 2d. fn_solicitudes_activas: solicitudes activas (Asignada o En curso)
--     de un domiciliario. La usan los triggers trg_validar_domiciliario
--     y trg_validar_inactivar_domiciliario.
DELIMITER $$
CREATE FUNCTION fn_solicitudes_activas (p_idDomiciliario INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_activas INT DEFAULT 0;

    SELECT COUNT(*) INTO v_activas
    FROM Solicitud s
    INNER JOIN EstadoSolicitud es
        ON s.idEstadoSolicitud = es.idEstadoSolicitud
    WHERE s.idDomiciliario = p_idDomiciliario
      AND es.nombreEstadoSolicitud IN ('Asignada', 'En curso');

    RETURN v_activas;
END $$
DELIMITER ;


-- 2e. fn_minutos_asignacion: minutos entre la creación y la asignación
--     de una solicitud (NULL si todavía no se ha asignado)
DELIMITER $$
CREATE FUNCTION fn_minutos_asignacion (
    p_fechaCreacion   DATE,
    p_horaCreacion    TIME,
    p_fechaAsignacion DATE,
    p_horaAsignacion  TIME
)
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE v_minutos INT;

    IF p_fechaAsignacion IS NULL OR p_horaAsignacion IS NULL THEN
        SET v_minutos = NULL;
    ELSE
        SET v_minutos = TIMESTAMPDIFF(MINUTE,
                            TIMESTAMP(p_fechaCreacion, p_horaCreacion),
                            TIMESTAMP(p_fechaAsignacion, p_horaAsignacion));
    END IF;

    RETURN v_minutos;
END $$
DELIMITER ;


-- ---------------------------------------------------------------------
-- 3 -- Procedimiento de resumen
-- sp_resumen_domiciliario: dado un domiciliario, muestra
--    * Nombre, código único, medio de transporte y estado
--    * Total de solicitudes, finalizadas, canceladas y activas
--    * Total movilizado en solicitudes finalizadas
--    * Cantidad de incidentes y promedio de minutos de asignación
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_resumen_domiciliario;

DELIMITER $$
CREATE PROCEDURE sp_resumen_domiciliario (IN p_idDomiciliario INT)
BEGIN
    DECLARE v_nombre       VARCHAR(310);
    DECLARE v_codigo       INT;
    DECLARE v_transporte   VARCHAR(50);
    DECLARE v_estado       VARCHAR(50);
    DECLARE v_total        INT DEFAULT 0;
    DECLARE v_finalizadas  INT DEFAULT 0;
    DECLARE v_canceladas   INT DEFAULT 0;
    DECLARE v_activas      INT DEFAULT 0;
    DECLARE v_movilizado   DECIMAL(12,2) DEFAULT 0;
    DECLARE v_incidentes   INT DEFAULT 0;
    DECLARE v_promedio_min DECIMAL(6,1);

    SELECT fn_nombre_completo(d.idDomiciliario), d.codigoUnico,
           mt.nombreMedioTransporte, ed.nombreEstadoDomiciliario
      INTO v_nombre, v_codigo, v_transporte, v_estado
      FROM Domiciliario d
     INNER JOIN MedioTransporte mt
        ON d.idMedioTransporte = mt.idMedioTransporte
     INNER JOIN EstadoDomiciliario ed
        ON d.idEstadoDomiciliario = ed.idEstadoDomiciliario
     WHERE d.idDomiciliario = p_idDomiciliario;

    IF v_nombre IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El domiciliario no existe';
    END IF;

    SELECT COUNT(*) INTO v_total
      FROM Solicitud
     WHERE idDomiciliario = p_idDomiciliario;

    SELECT COUNT(*) INTO v_finalizadas
      FROM Solicitud s
     INNER JOIN EstadoSolicitud es
        ON s.idEstadoSolicitud = es.idEstadoSolicitud
     WHERE s.idDomiciliario = p_idDomiciliario
       AND es.nombreEstadoSolicitud = 'Finalizada';

    SELECT COUNT(*) INTO v_canceladas
      FROM Solicitud s
     INNER JOIN EstadoSolicitud es
        ON s.idEstadoSolicitud = es.idEstadoSolicitud
     WHERE s.idDomiciliario = p_idDomiciliario
       AND es.nombreEstadoSolicitud = 'Cancelada';

    SET v_activas    = fn_solicitudes_activas(p_idDomiciliario);
    SET v_movilizado = fn_total_movilizado_domiciliario(p_idDomiciliario);

    SELECT COUNT(*) INTO v_incidentes
      FROM Incidente i
     INNER JOIN Solicitud s
        ON i.numeroSolicitud = s.numeroSolicitud
     WHERE s.idDomiciliario = p_idDomiciliario;

    SELECT AVG(fn_minutos_asignacion(fechaCreacion, horaCreacion, fechaAsignacion, horaAsignacion))
      INTO v_promedio_min
      FROM Solicitud
     WHERE idDomiciliario = p_idDomiciliario;

    SELECT
        v_nombre       AS domiciliario,
        v_codigo       AS codigo_unico,
        v_transporte   AS medio_transporte,
        v_estado       AS estado_domiciliario,
        v_total        AS total_solicitudes,
        v_finalizadas  AS finalizadas,
        v_canceladas   AS canceladas,
        v_activas      AS activas,
        v_movilizado   AS total_movilizado,
        v_incidentes   AS incidentes,
        v_promedio_min AS promedio_min_asignacion;
END $$
DELIMITER ;


-- ---------------------------------------------------------------------
-- 4 -- Trigger: regla de negocio
-- trg_validar_domiciliario: impide asignar una solicitud a un
-- domiciliario que:
--    * esté Inactivo
--    * sea el mismo cliente que hizo la solicitud
--    * ya tenga 2 solicitudes activas (usa fn_solicitudes_activas)
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_validar_domiciliario;

DELIMITER $$
CREATE TRIGGER trg_validar_domiciliario
BEFORE UPDATE ON Solicitud
FOR EACH ROW
BEGIN
    DECLARE v_estado VARCHAR(50);

    -- Solo se valida cuando se asigna o se cambia el domiciliario
    IF NEW.idDomiciliario IS NOT NULL
       AND (OLD.idDomiciliario IS NULL OR OLD.idDomiciliario <> NEW.idDomiciliario) THEN

        SELECT ed.nombreEstadoDomiciliario INTO v_estado
          FROM Domiciliario d
         INNER JOIN EstadoDomiciliario ed
            ON d.idEstadoDomiciliario = ed.idEstadoDomiciliario
         WHERE d.idDomiciliario = NEW.idDomiciliario;

        IF v_estado = 'Inactivo' THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'No se puede asignar un domiciliario inactivo';
        END IF;

        IF NEW.idDomiciliario = NEW.idCliente THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'El domiciliario no puede atender su propia solicitud';
        END IF;

        IF fn_solicitudes_activas(NEW.idDomiciliario) >= 2 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'El domiciliario ya tiene 2 solicitudes activas';
        END IF;
    END IF;
END $$
DELIMITER ;


-- ---------------------------------------------------------------------
-- 5 -- Trigger: validación
-- trg_validar_solicitud_insert: al registrar una solicitud valida que
--    * El monto total sea mayor que 0
--    * Tenga establecimiento O dirección de recogida externa (solo uno)
--    * La dirección de entrega exista y pertenezca al cliente
--    * Se registre en estado 'Creada' y sin domiciliario
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_validar_solicitud_insert;

DELIMITER $$
CREATE TRIGGER trg_validar_solicitud_insert
BEFORE INSERT ON Solicitud
FOR EACH ROW
BEGIN
    DECLARE v_clienteDireccion INT;
    DECLARE v_estado VARCHAR(50);

    -- Regla 1: monto válido
    IF NEW.montoTotal <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El monto de la solicitud debe ser mayor que 0';
    END IF;

    -- Regla 2: exactamente un lugar de recogida
    IF (NEW.idEstablecimiento IS NULL AND NEW.direccionRecogidaExterna IS NULL)
       OR (NEW.idEstablecimiento IS NOT NULL AND NEW.direccionRecogidaExterna IS NOT NULL) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La solicitud debe tener un establecimiento o una direccion externa, no ambos';
    END IF;

    -- Regla 3: la dirección existe y es del cliente
    -- (se pregunta también por NULL: si la dirección no existe,
    --  NULL <> cliente no dispararía el error)
    SELECT idCliente INTO v_clienteDireccion
      FROM Direccion
     WHERE idDireccion = NEW.idDireccion;

    IF v_clienteDireccion IS NULL OR v_clienteDireccion <> NEW.idCliente THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La direccion de entrega no pertenece al cliente de la solicitud';
    END IF;

    -- Regla 4: estado inicial
    SELECT nombreEstadoSolicitud INTO v_estado
      FROM EstadoSolicitud
     WHERE idEstadoSolicitud = NEW.idEstadoSolicitud;

    IF v_estado <> 'Creada' OR NEW.idDomiciliario IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Toda solicitud nueva debe quedar en estado Creada y sin domiciliario';
    END IF;
END $$
DELIMITER ;


-- ---------------------------------------------------------------------
-- RETO (cursor)
-- sp_reporte_desempeno_domiciliarios: recorre con un cursor todos los
-- domiciliarios y, para cada uno, calcula cuántas solicitudes atendió,
-- cuántos incidentes tuvo, su tasa de incidentes (incidentes por
-- solicitud) y lo clasifica:
--   0 = Excelente | <= 0.5 = Bueno | <= 1 = Regular | > 1 = Por mejorar
-- Se usa cursor porque cada fila requiere varios cálculos y una decisión
-- (IF) antes de guardar el resultado.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_reporte_desempeno_domiciliarios;

DELIMITER $$
CREATE PROCEDURE sp_reporte_desempeno_domiciliarios ()
BEGIN
    -- 1. Variables
    DECLARE fin INT DEFAULT 0;
    DECLARE v_id INT;
    DECLARE v_codigo INT;
    DECLARE v_atendidas INT DEFAULT 0;
    DECLARE v_incidentes INT DEFAULT 0;
    DECLARE v_tasa DECIMAL(5,2);
    DECLARE v_clasificacion VARCHAR(20);
    -- 2. Cursor
    DECLARE cur_domiciliarios CURSOR FOR
        SELECT idDomiciliario, codigoUnico
          FROM Domiciliario
         ORDER BY codigoUnico;
    -- 3. Handler: avisa cuando no hay más filas
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET fin = 1;

    -- Tabla temporal donde se acumula el reporte
    DROP TEMPORARY TABLE IF EXISTS tmp_desempeno;
    CREATE TEMPORARY TABLE tmp_desempeno (
        codigoUnico           INT,
        domiciliario          VARCHAR(310),
        solicitudes_atendidas INT,
        incidentes            INT,
        tasa_incidentes       DECIMAL(5,2),
        clasificacion         VARCHAR(20)
    );

    OPEN cur_domiciliarios;                              -- 4. Abrir
    ciclo: LOOP                                          -- 5. Recorrer
        FETCH cur_domiciliarios INTO v_id, v_codigo;     -- 6. Leer fila
        IF fin THEN LEAVE ciclo; END IF;                 -- 7. Salir

        -- 8. Procesar la fila
        SELECT COUNT(*) INTO v_atendidas
          FROM Solicitud
         WHERE idDomiciliario = v_id;

        SELECT COUNT(*) INTO v_incidentes
          FROM Incidente i
         INNER JOIN Solicitud s
            ON i.numeroSolicitud = s.numeroSolicitud
         WHERE s.idDomiciliario = v_id;

        IF v_atendidas = 0 THEN
            SET v_tasa = NULL;
            SET v_clasificacion = 'Sin solicitudes';
        ELSE
            SET v_tasa = v_incidentes / v_atendidas;
            IF v_tasa = 0 THEN
                SET v_clasificacion = 'Excelente';
            ELSEIF v_tasa <= 0.5 THEN
                SET v_clasificacion = 'Bueno';
            ELSEIF v_tasa <= 1 THEN
                SET v_clasificacion = 'Regular';
            ELSE
                SET v_clasificacion = 'Por mejorar';
            END IF;
        END IF;

        INSERT INTO tmp_desempeno
        VALUES (v_codigo, fn_nombre_completo(v_id), v_atendidas,
                v_incidentes, v_tasa, v_clasificacion);
    END LOOP;
    CLOSE cur_domiciliarios;                             -- 9. Cerrar

    -- Un solo resultado al final
    SELECT * FROM tmp_desempeno
     ORDER BY solicitudes_atendidas DESC, tasa_incidentes;

    DROP TEMPORARY TABLE IF EXISTS tmp_desempeno;
END $$
DELIMITER ;


-- ---------------------------------------------------------------------
-- VERIFICACIÓN: objetos creados en la base de datos
-- ---------------------------------------------------------------------
SHOW TRIGGERS FROM ProyectoIntegrador;
SHOW FUNCTION STATUS WHERE Db = 'ProyectoIntegrador';
SHOW PROCEDURE STATUS WHERE Db = 'ProyectoIntegrador';
