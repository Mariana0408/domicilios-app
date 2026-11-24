-- =====================================================================
-- PROYECTO INTEGRADOR - SISTEMA DE DOMICILIOS
-- ENTREGA 4: Lógica del sistema dentro de la base de datos
--            (auditoría, reglas de negocio, procedimientos y vistas)
--
-- Orden de ejecución:
--   1. 01_ProyectoIntegrador.sql
--   2. 02_Entrega3_LenguajeProcedimental.sql
--   3. 03_Entrega4_Backend.sql        <- este archivo
--   4. 04_Pruebas_Entrega3_y_4.sql    (pruebas, una por una)
--
-- Este archivo solo CREA objetos y se puede ejecutar completo.
-- Complementa el backend en Spring Boot: la aplicación usa los triggers
-- (reglas de negocio y auditoría), las vistas y los procedimientos de
-- reporte de este script.
-- =====================================================================
USE ProyectoIntegrador;


-- =====================================================================
-- PARTE A. AUDITORÍA
-- Guarda el historial de cada solicitud: cuándo se creó, cada cambio de
-- estado y cada cambio de domiciliario.
-- =====================================================================
DROP TABLE IF EXISTS AuditoriaSolicitud;

CREATE TABLE AuditoriaSolicitud (
    idAuditoria          INT AUTO_INCREMENT PRIMARY KEY,
    numeroSolicitud      INT NOT NULL,
    accion               VARCHAR(20) NOT NULL,
    estadoAnterior       VARCHAR(50),
    estadoNuevo          VARCHAR(50) NOT NULL,
    domiciliarioAnterior INT,
    domiciliarioNuevo    INT,
    usuarioBD            VARCHAR(100),
    fechaCambio          DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (numeroSolicitud) REFERENCES Solicitud(numeroSolicitud)
);


-- ---------------------------------------------------------------------
-- A1 -- Trigger: registrar la creación de una solicitud
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_auditar_creacion_solicitud;

DELIMITER $$
CREATE TRIGGER trg_auditar_creacion_solicitud
AFTER INSERT ON Solicitud
FOR EACH ROW
BEGIN
    DECLARE v_estado VARCHAR(50);

    SELECT nombreEstadoSolicitud INTO v_estado
      FROM EstadoSolicitud
     WHERE idEstadoSolicitud = NEW.idEstadoSolicitud;

    INSERT INTO AuditoriaSolicitud
        (numeroSolicitud, accion, estadoAnterior, estadoNuevo,
         domiciliarioAnterior, domiciliarioNuevo, usuarioBD)
    VALUES (NEW.numeroSolicitud, 'CREACION', NULL, v_estado,
            NULL, NEW.idDomiciliario, CURRENT_USER());
END $$
DELIMITER ;


-- ---------------------------------------------------------------------
-- A2 -- Trigger: registrar cambios de estado o de domiciliario
-- Se usa AFTER porque solo se registra el cambio cuando ya ocurrió.
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_auditar_cambio_solicitud;

DELIMITER $$
CREATE TRIGGER trg_auditar_cambio_solicitud
AFTER UPDATE ON Solicitud
FOR EACH ROW
BEGIN
    DECLARE v_anterior VARCHAR(50);
    DECLARE v_nuevo VARCHAR(50);

    IF OLD.idEstadoSolicitud <> NEW.idEstadoSolicitud
       OR NOT (OLD.idDomiciliario <=> NEW.idDomiciliario) THEN

        SELECT nombreEstadoSolicitud INTO v_anterior
          FROM EstadoSolicitud
         WHERE idEstadoSolicitud = OLD.idEstadoSolicitud;

        SELECT nombreEstadoSolicitud INTO v_nuevo
          FROM EstadoSolicitud
         WHERE idEstadoSolicitud = NEW.idEstadoSolicitud;

        INSERT INTO AuditoriaSolicitud
            (numeroSolicitud, accion, estadoAnterior, estadoNuevo,
             domiciliarioAnterior, domiciliarioNuevo, usuarioBD)
        VALUES (NEW.numeroSolicitud, 'ACTUALIZACION', v_anterior, v_nuevo,
                OLD.idDomiciliario, NEW.idDomiciliario, CURRENT_USER());
    END IF;
END $$
DELIMITER ;


-- =====================================================================
-- PARTE B. REGLAS DE NEGOCIO (triggers de validación)
-- =====================================================================

-- ---------------------------------------------------------------------
-- B1 -- Flujo de estados de una solicitud
--    Creada   -> Asignada | Cancelada
--    Asignada -> En curso | Cancelada
--    En curso -> Finalizada | Cancelada
--    Finalizada y Cancelada son estados finales: no se pueden modificar.
-- Además:
--    * Asignada, En curso y Finalizada exigen domiciliario.
--    * No se puede cambiar el domiciliario de una solicitud En curso.
--    * Al asignar domiciliario se guarda fecha y hora de asignación.
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_flujo_estado_solicitud;

DELIMITER $$
CREATE TRIGGER trg_flujo_estado_solicitud
BEFORE UPDATE ON Solicitud
FOR EACH ROW
BEGIN
    DECLARE v_anterior VARCHAR(50);
    DECLARE v_nuevo VARCHAR(50);

    SELECT nombreEstadoSolicitud INTO v_anterior
      FROM EstadoSolicitud
     WHERE idEstadoSolicitud = OLD.idEstadoSolicitud;

    SELECT nombreEstadoSolicitud INTO v_nuevo
      FROM EstadoSolicitud
     WHERE idEstadoSolicitud = NEW.idEstadoSolicitud;

    IF v_anterior IN ('Finalizada', 'Cancelada') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se puede modificar una solicitud finalizada o cancelada';
    END IF;

    IF v_anterior <> v_nuevo THEN
        IF NOT ((v_anterior = 'Creada'   AND v_nuevo IN ('Asignada', 'Cancelada'))
             OR (v_anterior = 'Asignada' AND v_nuevo IN ('En curso', 'Cancelada'))
             OR (v_anterior = 'En curso' AND v_nuevo IN ('Finalizada', 'Cancelada'))) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Cambio de estado no permitido';
        END IF;
    END IF;

    IF v_nuevo IN ('Asignada', 'En curso', 'Finalizada') AND NEW.idDomiciliario IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La solicitud necesita un domiciliario asignado';
    END IF;

    IF v_anterior = 'En curso' AND NOT (OLD.idDomiciliario <=> NEW.idDomiciliario) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se puede cambiar el domiciliario de una solicitud en curso';
    END IF;

    IF NEW.idDomiciliario IS NOT NULL
       AND NOT (OLD.idDomiciliario <=> NEW.idDomiciliario) THEN
        SET NEW.fechaAsignacion = CURDATE();
        SET NEW.horaAsignacion  = CURTIME();
    END IF;
END $$
DELIMITER ;


-- ---------------------------------------------------------------------
-- B2 -- Validación de incidentes
--    * La solicitud debe tener domiciliario asignado.
--    * La fecha y hora del incidente no puede ser anterior a la creación
--      de la solicitud.
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_validar_incidente;

DELIMITER $$
CREATE TRIGGER trg_validar_incidente
BEFORE INSERT ON Incidente
FOR EACH ROW
BEGIN
    DECLARE v_fecha DATE;
    DECLARE v_hora TIME;
    DECLARE v_domiciliario INT;

    SELECT fechaCreacion, horaCreacion, idDomiciliario
      INTO v_fecha, v_hora, v_domiciliario
      FROM Solicitud
     WHERE numeroSolicitud = NEW.numeroSolicitud;

    IF v_fecha IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La solicitud no existe';
    END IF;

    IF v_domiciliario IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se registran incidentes en solicitudes sin domiciliario';
    END IF;

    IF TIMESTAMP(NEW.fechaIncidente, NEW.horaIncidente) < TIMESTAMP(v_fecha, v_hora) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El incidente no puede ser anterior a la creacion de la solicitud';
    END IF;
END $$
DELIMITER ;


-- ---------------------------------------------------------------------
-- B3 -- No se puede inactivar un domiciliario con solicitudes activas
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_validar_inactivar_domiciliario;

DELIMITER $$
CREATE TRIGGER trg_validar_inactivar_domiciliario
BEFORE UPDATE ON Domiciliario
FOR EACH ROW
BEGIN
    DECLARE v_estado VARCHAR(50);

    SELECT nombreEstadoDomiciliario INTO v_estado
      FROM EstadoDomiciliario
     WHERE idEstadoDomiciliario = NEW.idEstadoDomiciliario;

    IF v_estado = 'Inactivo'
       AND OLD.idEstadoDomiciliario <> NEW.idEstadoDomiciliario
       AND fn_solicitudes_activas(NEW.idDomiciliario) > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El domiciliario tiene solicitudes activas y no se puede inactivar';
    END IF;
END $$
DELIMITER ;


-- =====================================================================
-- PARTE C. PROCEDIMIENTOS DE OPERACIÓN
-- Permiten realizar las operaciones del sistema directamente en MySQL.
-- Nota: las tablas no usan AUTO_INCREMENT, por eso los procedimientos
-- calculan el siguiente código con MAX() + 1.
-- =====================================================================

-- ---------------------------------------------------------------------
-- C1 -- Registrar un cliente (Usuario + Cliente en una sola transacción)
-- Si el usuario ya existe (por ejemplo, es domiciliario) solo se crea
-- el rol de cliente.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_registrar_cliente;

DELIMITER $$
CREATE PROCEDURE sp_registrar_cliente (
    IN p_documento       INT,
    IN p_nombre          VARCHAR(100),
    IN p_apellidoPaterno VARCHAR(100),
    IN p_apellidoMaterno VARCHAR(100),
    IN p_telefono        VARCHAR(20),
    IN p_correo          VARCHAR(100)
)
BEGIN
    -- Si algo falla, se deshace todo
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM Usuario WHERE numeroIdentificacion = p_documento) THEN
        INSERT INTO Usuario (numeroIdentificacion, nombre, apellido_Paterno,
                             apellido_Materno, numeroTelefono, correoElectronico)
        VALUES (p_documento, p_nombre, p_apellidoPaterno,
                p_apellidoMaterno, p_telefono, p_correo);
    END IF;

    IF EXISTS (SELECT 1 FROM Cliente WHERE idCliente = p_documento) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El cliente ya esta registrado';
    END IF;

    INSERT INTO Cliente (idCliente) VALUES (p_documento);

    COMMIT;
END $$
DELIMITER ;


-- ---------------------------------------------------------------------
-- C2 -- Registrar un domiciliario (Usuario + Domiciliario, queda Activo)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_registrar_domiciliario;

DELIMITER $$
CREATE PROCEDURE sp_registrar_domiciliario (
    IN p_documento         INT,
    IN p_nombre            VARCHAR(100),
    IN p_apellidoPaterno   VARCHAR(100),
    IN p_apellidoMaterno   VARCHAR(100),
    IN p_telefono          VARCHAR(20),
    IN p_correo            VARCHAR(100),
    IN p_codigoUnico       INT,
    IN p_idMedioTransporte INT
)
BEGIN
    DECLARE v_idActivo INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SELECT idEstadoDomiciliario INTO v_idActivo
      FROM EstadoDomiciliario
     WHERE nombreEstadoDomiciliario = 'Activo';

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM Usuario WHERE numeroIdentificacion = p_documento) THEN
        INSERT INTO Usuario (numeroIdentificacion, nombre, apellido_Paterno,
                             apellido_Materno, numeroTelefono, correoElectronico)
        VALUES (p_documento, p_nombre, p_apellidoPaterno,
                p_apellidoMaterno, p_telefono, p_correo);
    END IF;

    IF EXISTS (SELECT 1 FROM Domiciliario WHERE idDomiciliario = p_documento) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El domiciliario ya esta registrado';
    END IF;

    INSERT INTO Domiciliario (idDomiciliario, codigoUnico, idEstadoDomiciliario, idMedioTransporte)
    VALUES (p_documento, p_codigoUnico, v_idActivo, p_idMedioTransporte);

    COMMIT;
END $$
DELIMITER ;


-- ---------------------------------------------------------------------
-- C3 -- Registrar una dirección de un cliente (devuelve el id con OUT)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_registrar_direccion;

DELIMITER $$
CREATE PROCEDURE sp_registrar_direccion (
    IN  p_idCliente  INT,
    IN  p_ubicacion  VARCHAR(255),
    IN  p_referencia VARCHAR(255),
    IN  p_idBarrio   INT,
    OUT p_idDireccion INT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Cliente WHERE idCliente = p_idCliente) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El cliente no existe';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM Barrio WHERE idBarrio = p_idBarrio) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El barrio no existe';
    END IF;

    SELECT IFNULL(MAX(idDireccion), 0) + 1 INTO p_idDireccion
      FROM Direccion;

    INSERT INTO Direccion (idDireccion, ubicacion, referencia, idBarrio, idCliente)
    VALUES (p_idDireccion, p_ubicacion, p_referencia, p_idBarrio, p_idCliente);
END $$
DELIMITER ;


-- ---------------------------------------------------------------------
-- C4 -- Registrar una solicitud (queda en estado Creada; devuelve el número)
-- Las validaciones las hace el trigger trg_validar_solicitud_insert (Entrega 3).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_registrar_solicitud;

DELIMITER $$
CREATE PROCEDURE sp_registrar_solicitud (
    IN  p_idCliente                INT,
    IN  p_idDireccion              INT,
    IN  p_idEstablecimiento        INT,
    IN  p_direccionRecogidaExterna VARCHAR(255),
    IN  p_descripcion              VARCHAR(200),
    IN  p_montoTotal               DECIMAL(10,2),
    IN  p_idMetodoPago             INT,
    OUT p_numeroSolicitud          INT
)
BEGIN
    DECLARE v_idCreada INT;

    SELECT idEstadoSolicitud INTO v_idCreada
      FROM EstadoSolicitud
     WHERE nombreEstadoSolicitud = 'Creada';

    SELECT IFNULL(MAX(numeroSolicitud), 1000) + 1 INTO p_numeroSolicitud
      FROM Solicitud;

    INSERT INTO Solicitud (numeroSolicitud, fechaCreacion, horaCreacion,
                           fechaAsignacion, horaAsignacion, descripcion, montoTotal,
                           direccionRecogidaExterna, idDireccion, idEstablecimiento, idCliente,
                           idDomiciliario, idMetodoPago, idEstadoSolicitud)
    VALUES (p_numeroSolicitud, CURDATE(), CURTIME(),
            NULL, NULL, p_descripcion, p_montoTotal,
            p_direccionRecogidaExterna, p_idDireccion, p_idEstablecimiento, p_idCliente,
            NULL, p_idMetodoPago, v_idCreada);
END $$
DELIMITER ;


-- ---------------------------------------------------------------------
-- C5 -- Asignar (o reasignar) un domiciliario a una solicitud
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_asignar_domiciliario;

DELIMITER $$
CREATE PROCEDURE sp_asignar_domiciliario (
    IN p_numeroSolicitud INT,
    IN p_idDomiciliario  INT
)
BEGIN
    DECLARE v_estado VARCHAR(50);
    DECLARE v_idAsignada INT;

    SELECT es.nombreEstadoSolicitud INTO v_estado
      FROM Solicitud s
     INNER JOIN EstadoSolicitud es
        ON s.idEstadoSolicitud = es.idEstadoSolicitud
     WHERE s.numeroSolicitud = p_numeroSolicitud;

    IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La solicitud no existe';
    END IF;

    IF v_estado NOT IN ('Creada', 'Asignada') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Solo se asignan solicitudes en estado Creada o Asignada';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM Domiciliario WHERE idDomiciliario = p_idDomiciliario) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El domiciliario no existe';
    END IF;

    SELECT idEstadoSolicitud INTO v_idAsignada
      FROM EstadoSolicitud
     WHERE nombreEstadoSolicitud = 'Asignada';

    -- trg_validar_domiciliario valida al domiciliario y
    -- trg_flujo_estado_solicitud guarda la fecha y hora de asignación
    UPDATE Solicitud
       SET idDomiciliario    = p_idDomiciliario,
           idEstadoSolicitud = v_idAsignada
     WHERE numeroSolicitud = p_numeroSolicitud;
END $$
DELIMITER ;


-- ---------------------------------------------------------------------
-- C6 -- Cambiar el estado de una solicitud por nombre
-- Ej: CALL sp_cambiar_estado_solicitud(1022, 'En curso');
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_cambiar_estado_solicitud;

DELIMITER $$
CREATE PROCEDURE sp_cambiar_estado_solicitud (
    IN p_numeroSolicitud INT,
    IN p_estado          VARCHAR(50)
)
BEGIN
    DECLARE v_idEstado INT;

    SELECT idEstadoSolicitud INTO v_idEstado
      FROM EstadoSolicitud
     WHERE nombreEstadoSolicitud = p_estado;

    IF v_idEstado IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El estado indicado no existe';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM Solicitud WHERE numeroSolicitud = p_numeroSolicitud) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La solicitud no existe';
    END IF;

    -- trg_flujo_estado_solicitud valida que el cambio sea permitido
    UPDATE Solicitud
       SET idEstadoSolicitud = v_idEstado
     WHERE numeroSolicitud = p_numeroSolicitud;
END $$
DELIMITER ;


-- ---------------------------------------------------------------------
-- C7 -- Registrar un incidente con la fecha y hora actual
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_registrar_incidente;

DELIMITER $$
CREATE PROCEDURE sp_registrar_incidente (
    IN  p_numeroSolicitud INT,
    IN  p_idTipoIncidente INT,
    IN  p_descripcion     VARCHAR(300),
    OUT p_codigoIncidente INT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM TipoIncidente WHERE idTipoIncidente = p_idTipoIncidente) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El tipo de incidente no existe';
    END IF;

    SELECT IFNULL(MAX(codigoIncidente), 0) + 1 INTO p_codigoIncidente
      FROM Incidente;

    -- trg_validar_incidente valida la solicitud y la fecha
    INSERT INTO Incidente (codigoIncidente, descripcion, fechaIncidente,
                           horaIncidente, idTipoIncidente, numeroSolicitud)
    VALUES (p_codigoIncidente, p_descripcion, CURDATE(),
            CURTIME(), p_idTipoIncidente, p_numeroSolicitud);
END $$
DELIMITER ;


-- ---------------------------------------------------------------------
-- C8 -- Activar o inactivar un domiciliario usando su código único
-- Ej: CALL sp_cambiar_estado_domiciliario(1004, 'Activo');
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_cambiar_estado_domiciliario;

DELIMITER $$
CREATE PROCEDURE sp_cambiar_estado_domiciliario (
    IN p_codigoUnico INT,
    IN p_estado      VARCHAR(50)
)
BEGIN
    DECLARE v_idEstado INT;

    SELECT idEstadoDomiciliario INTO v_idEstado
      FROM EstadoDomiciliario
     WHERE nombreEstadoDomiciliario = p_estado;

    IF v_idEstado IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El estado indicado no existe';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM Domiciliario WHERE codigoUnico = p_codigoUnico) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No existe un domiciliario con ese codigo unico';
    END IF;

    -- trg_validar_inactivar_domiciliario impide inactivarlo con solicitudes activas
    UPDATE Domiciliario
       SET idEstadoDomiciliario = v_idEstado
     WHERE codigoUnico = p_codigoUnico;
END $$
DELIMITER ;


-- =====================================================================
-- PARTE D. CONSULTAS (vistas y reportes)
-- El backend en Spring Boot las expone en /api/reportes
-- =====================================================================

-- ---------------------------------------------------------------------
-- D1 -- Vista con el detalle completo de cada solicitud
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS vw_solicitudes_detalle;

CREATE VIEW vw_solicitudes_detalle AS
SELECT
    s.numeroSolicitud,
    s.fechaCreacion,
    s.horaCreacion,
    fn_nombre_completo(s.idCliente) AS cliente,
    IFNULL(e.nombreComercial, CONCAT('Recogida: ', s.direccionRecogidaExterna)) AS origen,
    d.ubicacion AS direccion_entrega,
    b.nombreBarrio AS barrio,
    c.nombreComuna AS comuna,
    IF(s.idDomiciliario IS NULL, 'Sin asignar', fn_nombre_completo(s.idDomiciliario)) AS domiciliario,
    es.nombreEstadoSolicitud AS estado,
    mp.nombreMetodo AS metodo_pago,
    s.montoTotal,
    fn_minutos_asignacion(s.fechaCreacion, s.horaCreacion,
                          s.fechaAsignacion, s.horaAsignacion) AS minutos_asignacion,
    (SELECT COUNT(*)
       FROM Incidente i
      WHERE i.numeroSolicitud = s.numeroSolicitud) AS incidentes
FROM Solicitud s
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
    ON s.idEstablecimiento = e.idEstablecimiento;


-- ---------------------------------------------------------------------
-- D2 -- Vista de domiciliarios disponibles (activos y con menos de 2
-- solicitudes activas)
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS vw_domiciliarios_disponibles;

CREATE VIEW vw_domiciliarios_disponibles AS
SELECT
    d.idDomiciliario,
    d.codigoUnico,
    fn_nombre_completo(d.idDomiciliario) AS domiciliario,
    u.numeroTelefono,
    mt.nombreMedioTransporte AS medio_transporte,
    fn_solicitudes_activas(d.idDomiciliario) AS solicitudes_activas
FROM Domiciliario d
INNER JOIN Usuario u
    ON d.idDomiciliario = u.numeroIdentificacion
INNER JOIN EstadoDomiciliario ed
    ON d.idEstadoDomiciliario = ed.idEstadoDomiciliario
INNER JOIN MedioTransporte mt
    ON d.idMedioTransporte = mt.idMedioTransporte
WHERE ed.nombreEstadoDomiciliario = 'Activo'
  AND fn_solicitudes_activas(d.idDomiciliario) < 2;


-- ---------------------------------------------------------------------
-- D2b -- Vista de resumen por cliente (usa fn_solicitudes_cliente)
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS vw_resumen_clientes;

CREATE VIEW vw_resumen_clientes AS
SELECT
    c.idCliente,
    fn_nombre_completo(c.idCliente) AS cliente,
    u.numeroTelefono,
    (SELECT COUNT(*) FROM Direccion d
      WHERE d.idCliente = c.idCliente) AS direcciones,
    (SELECT COUNT(*) FROM Solicitud s
      WHERE s.idCliente = c.idCliente) AS total_solicitudes,
    fn_solicitudes_cliente(c.idCliente) AS finalizadas,
    (SELECT IFNULL(SUM(s.montoTotal), 0)
       FROM Solicitud s
      INNER JOIN EstadoSolicitud es
         ON s.idEstadoSolicitud = es.idEstadoSolicitud
      WHERE s.idCliente = c.idCliente
        AND es.nombreEstadoSolicitud = 'Finalizada') AS total_pagado
FROM Cliente c
INNER JOIN Usuario u
    ON c.idCliente = u.numeroIdentificacion;


-- ---------------------------------------------------------------------
-- D3 -- Historial (auditoría) de una solicitud
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_historial_solicitud;

DELIMITER $$
CREATE PROCEDURE sp_historial_solicitud (IN p_numeroSolicitud INT)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Solicitud WHERE numeroSolicitud = p_numeroSolicitud) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La solicitud no existe';
    END IF;

    SELECT
        a.fechaCambio,
        a.accion,
        a.estadoAnterior,
        a.estadoNuevo,
        fn_nombre_completo(a.domiciliarioAnterior) AS domiciliario_anterior,
        fn_nombre_completo(a.domiciliarioNuevo) AS domiciliario_nuevo,
        a.usuarioBD
    FROM AuditoriaSolicitud a
    WHERE a.numeroSolicitud = p_numeroSolicitud
    ORDER BY a.idAuditoria;
END $$
DELIMITER ;


-- ---------------------------------------------------------------------
-- D4 -- Reporte por establecimiento en un rango de fechas
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_reporte_establecimientos;

DELIMITER $$
CREATE PROCEDURE sp_reporte_establecimientos (
    IN p_fechaInicio DATE,
    IN p_fechaFin    DATE
)
BEGIN
    IF p_fechaFin < p_fechaInicio THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La fecha final no puede ser anterior a la inicial';
    END IF;

    SELECT
        e.nombreComercial,
        te.nombreTipoEstablecimiento AS tipo,
        COUNT(s.numeroSolicitud) AS solicitudes,
        SUM(CASE WHEN es.nombreEstadoSolicitud = 'Finalizada' THEN 1 ELSE 0 END) AS finalizadas,
        SUM(CASE WHEN es.nombreEstadoSolicitud = 'Cancelada'  THEN 1 ELSE 0 END) AS canceladas,
        IFNULL(SUM(CASE WHEN es.nombreEstadoSolicitud = 'Finalizada'
                        THEN s.montoTotal ELSE 0 END), 0) AS monto_finalizado
    FROM Establecimiento e
    INNER JOIN TipoEstablecimiento te
        ON e.idTipoEstablecimiento = te.idTipoEstablecimiento
    LEFT JOIN Solicitud s
        ON e.idEstablecimiento = s.idEstablecimiento
       AND s.fechaCreacion BETWEEN p_fechaInicio AND p_fechaFin
    LEFT JOIN EstadoSolicitud es
        ON s.idEstadoSolicitud = es.idEstadoSolicitud
    GROUP BY e.idEstablecimiento, e.nombreComercial, te.nombreTipoEstablecimiento
    ORDER BY monto_finalizado DESC;
END $$
DELIMITER ;


-- ---------------------------------------------------------------------
-- VERIFICACIÓN: objetos creados en la base de datos
-- ---------------------------------------------------------------------
SHOW TRIGGERS FROM ProyectoIntegrador;
SHOW PROCEDURE STATUS WHERE Db = 'ProyectoIntegrador';
SHOW FULL TABLES IN ProyectoIntegrador WHERE Table_type = 'VIEW';
