-- =====================================================================
-- PROYECTO INTEGRADOR - SISTEMA DE DOMICILIOS
-- PRUEBAS DE LOS OBJETOS PROCEDIMENTALES (Entregas 3 y 4)
--
-- Requisitos: haber ejecutado, en orden,
--   01_ProyectoIntegrador.sql
--   02_Entrega3_LenguajeProcedimental.sql
--   03_Entrega4_Backend.sql
--
-- IMPORTANTE: ejecutar UNA POR UNA, en orden (cursor sobre la sentencia
-- y Ctrl + Enter en MySQL Workbench). Varias pruebas DEBEN fallar: el
-- error esperado demuestra que la regla funciona. Si se ejecuta todo el
-- archivo con el rayo, Workbench se detiene en el primer error.
--
-- Estas pruebas modifican datos (crean las solicitudes 1021 a 1023, la
-- clienta Paula, el domiciliario Andres, etc.). Para volver a los datos
-- originales:  DROP DATABASE ProyectoIntegrador;  y ejecutar de nuevo
-- los scripts 01, 02 y 03.
-- =====================================================================
USE ProyectoIntegrador;


-- #####################################################################
-- PARTE 1. PRUEBAS DE LA ENTREGA 3
-- #####################################################################

-- ---------------------------------------------------------------------
-- E3-01 a E3-02: sp_solicitudes_por_fecha (consulta con JOIN)
-- ---------------------------------------------------------------------
CALL sp_solicitudes_por_fecha('2026-10-04');
-- Resultado esperado: 10 solicitudes (1011 a 1020), ordenadas por hora

CALL sp_solicitudes_por_fecha('2026-09-22');
-- Resultado esperado: 1 solicitud (1006, recogida externa, 1 incidente)


-- ---------------------------------------------------------------------
-- E3-03 a E3-08: funciones
-- ---------------------------------------------------------------------
SELECT fn_nombre_completo(1000000001) AS nombre_cliente;
-- Resultado esperado: Laura Correa Martinez

SELECT fn_nombre_completo(123) AS nombre;
-- Resultado esperado: No registrado

SELECT fn_solicitudes_cliente(1000000001) AS solicitudes_finalizadas;
-- Resultado esperado: 2 (solicitudes 1001 y 1007)

SELECT fn_total_movilizado_domiciliario(1000000015) AS total_movilizado;
-- Resultado esperado: 68000.00 (solicitud 1001; la 1010 fue cancelada y la 1012 está en curso)

SELECT fn_solicitudes_activas(1000000015) AS solicitudes_activas;
-- Resultado esperado: 1 (solicitud 1012 en curso)

-- Las funciones también se usan dentro de un SELECT, fila por fila
SELECT
    d.codigoUnico,
    fn_nombre_completo(d.idDomiciliario) AS domiciliario,
    fn_solicitudes_activas(d.idDomiciliario) AS activas,
    fn_total_movilizado_domiciliario(d.idDomiciliario) AS total_movilizado
FROM Domiciliario d
ORDER BY d.codigoUnico;

SELECT
    numeroSolicitud,
    descripcion,
    fn_minutos_asignacion(fechaCreacion, horaCreacion, fechaAsignacion, horaAsignacion) AS minutos_asignacion
FROM Solicitud;
-- Resultado esperado: entre 3 y 6 minutos; NULL en las que no tienen domiciliario


-- ---------------------------------------------------------------------
-- E3-09 a E3-11: sp_resumen_domiciliario
-- ---------------------------------------------------------------------
CALL sp_resumen_domiciliario(1000000015);
-- Resultado esperado: Yeison Mosquera Cuero | 3 solicitudes | 1 finalizada |
--                     1 cancelada | 1 activa | 68000.00 | 3 incidentes

CALL sp_resumen_domiciliario(1000000018);
-- Resultado esperado: Hernán Sandoval Vidal | 2 solicitudes | 1 finalizada |
--                     1 activa | 57000.00 | 3 incidentes

CALL sp_resumen_domiciliario(999);
-- Resultado esperado: Error 1644 (45000): El domiciliario no existe


-- ---------------------------------------------------------------------
-- E3-12 a E3-15: trigger trg_validar_domiciliario
-- ---------------------------------------------------------------------
-- E3-12: domiciliario inactivo (1000000019)
UPDATE Solicitud
   SET idDomiciliario = 1000000019, idEstadoSolicitud = 2,
       fechaAsignacion = CURDATE(), horaAsignacion = CURTIME()
 WHERE numeroSolicitud = 1015;
-- Resultado esperado: Error 1644 (45000): No se puede asignar un domiciliario inactivo

-- E3-13: 1000000007 es cliente y domiciliario; la solicitud 1019 es suya
UPDATE Solicitud
   SET idDomiciliario = 1000000007, idEstadoSolicitud = 2,
       fechaAsignacion = CURDATE(), horaAsignacion = CURTIME()
 WHERE numeroSolicitud = 1019;
-- Resultado esperado: Error 1644 (45000): El domiciliario no puede atender su propia solicitud

-- E3-14: 1000000014 está activo y solo tiene 1 solicitud activa (1018)
UPDATE Solicitud
   SET idDomiciliario = 1000000014, idEstadoSolicitud = 2,
       fechaAsignacion = CURDATE(), horaAsignacion = CURTIME()
 WHERE numeroSolicitud = 1015;
-- Resultado esperado: 1 fila actualizada (la 1015 queda Asignada)

-- E3-15: ahora 1000000014 tiene 2 solicitudes activas (1018 y 1015)
UPDATE Solicitud
   SET idDomiciliario = 1000000014, idEstadoSolicitud = 2,
       fechaAsignacion = CURDATE(), horaAsignacion = CURTIME()
 WHERE numeroSolicitud = 1019;
-- Resultado esperado: Error 1644 (45000): El domiciliario ya tiene 2 solicitudes activas


-- ---------------------------------------------------------------------
-- E3-16 a E3-20: trigger trg_validar_solicitud_insert
-- ---------------------------------------------------------------------
-- E3-16: solicitud válida
INSERT INTO Solicitud (numeroSolicitud, fechaCreacion, horaCreacion, descripcion, montoTotal,
                       direccionRecogidaExterna, idDireccion, idEstablecimiento, idCliente,
                       idDomiciliario, idMetodoPago, idEstadoSolicitud)
VALUES (1021, CURDATE(), CURTIME(), 'Pedido #4591 - Bandeja paisa', 35000.00,
        NULL, 5, 4, 1000000005, NULL, 1, 1);
-- Resultado esperado: 1 fila insertada

-- E3-17: monto negativo
INSERT INTO Solicitud (numeroSolicitud, fechaCreacion, horaCreacion, descripcion, montoTotal,
                       direccionRecogidaExterna, idDireccion, idEstablecimiento, idCliente,
                       idDomiciliario, idMetodoPago, idEstadoSolicitud)
VALUES (9991, CURDATE(), CURTIME(), 'Prueba monto negativo', -15000.00,
        NULL, 1, 2, 1000000001, NULL, 1, 1);
-- Resultado esperado: Error 1644 (45000): El monto de la solicitud debe ser mayor que 0

-- E3-18: establecimiento y dirección externa a la vez
INSERT INTO Solicitud (numeroSolicitud, fechaCreacion, horaCreacion, descripcion, montoTotal,
                       direccionRecogidaExterna, idDireccion, idEstablecimiento, idCliente,
                       idDomiciliario, idMetodoPago, idEstadoSolicitud)
VALUES (9992, CURDATE(), CURTIME(), 'Prueba doble recogida', 25000.00,
        'Calle 10 # 5-20', 1, 2, 1000000001, NULL, 1, 1);
-- Resultado esperado: Error 1644 (45000): La solicitud debe tener un establecimiento
--                     o una direccion externa, no ambos

-- E3-19: la dirección 1 es de 1000000001, no de 1000000005
INSERT INTO Solicitud (numeroSolicitud, fechaCreacion, horaCreacion, descripcion, montoTotal,
                       direccionRecogidaExterna, idDireccion, idEstablecimiento, idCliente,
                       idDomiciliario, idMetodoPago, idEstadoSolicitud)
VALUES (9993, CURDATE(), CURTIME(), 'Prueba direccion ajena', 20000.00,
        NULL, 1, 4, 1000000005, NULL, 1, 1);
-- Resultado esperado: Error 1644 (45000): La direccion de entrega no pertenece al cliente de la solicitud

-- E3-20: crear la solicitud directamente como 'Finalizada'
INSERT INTO Solicitud (numeroSolicitud, fechaCreacion, horaCreacion, descripcion, montoTotal,
                       direccionRecogidaExterna, idDireccion, idEstablecimiento, idCliente,
                       idDomiciliario, idMetodoPago, idEstadoSolicitud)
VALUES (9994, CURDATE(), CURTIME(), 'Prueba estado inicial', 20000.00,
        NULL, 5, 4, 1000000005, NULL, 1, 4);
-- Resultado esperado: Error 1644 (45000): Toda solicitud nueva debe quedar en estado Creada y sin domiciliario


-- ---------------------------------------------------------------------
-- E3-21: cursor sp_reporte_desempeno_domiciliarios
-- ---------------------------------------------------------------------
CALL sp_reporte_desempeno_domiciliarios();
-- Resultado esperado: 10 domiciliarios; Hernán Sandoval 'Por mejorar' (1.50),
-- Luis Arboleda y Victoria Yacup 'Sin solicitudes'


-- #####################################################################
-- PARTE 2. PRUEBAS DE LA ENTREGA 4
-- (usan la solicitud 1021 creada en la prueba E3-16)
-- #####################################################################

-- P01: Registrar cliente nuevo
CALL sp_registrar_cliente(1000000021, 'Paula', 'Gutierrez', 'Mejia',
                          '3015558899', 'paula.gutierrez@gmail.com');
SELECT * FROM vw_resumen_clientes WHERE idCliente = 1000000021;
-- Resultado esperado: OK, Paula Gutierrez Mejia con 0 solicitudes

-- P02: Registrar el mismo cliente otra vez
CALL sp_registrar_cliente(1000000021, 'Paula', 'Gutierrez', 'Mejia',
                          '3015558899', 'paula.gutierrez@gmail.com');
-- Resultado esperado: Error 1644 (45000): El cliente ya esta registrado

-- P03: Registrar domiciliario nuevo
CALL sp_registrar_domiciliario(1000000022, 'Andres', 'Velasco', 'Rivas',
                               '3017771122', 'andres.velasco@gmail.com', 1011, 2);
SELECT * FROM vw_domiciliarios_disponibles WHERE idDomiciliario = 1000000022;
-- Resultado esperado: OK, queda Activo con 0 solicitudes activas

-- P04: Domiciliario con código único repetido (1001) -> prueba de la transacción
CALL sp_registrar_domiciliario(1000000023, 'Pedro', 'Rueda', 'Ortiz',
                               '3019990000', NULL, 1001, 1);
-- Resultado esperado: Error 1062 (23000): Duplicate entry '1001' for key 'codigoUnico'
SELECT COUNT(*) AS debe_ser_0 FROM Usuario WHERE numeroIdentificacion = 1000000023;
-- Resultado esperado: 0 (el ROLLBACK deshizo también el INSERT en Usuario)

-- P05: Registrar dirección del cliente nuevo
CALL sp_registrar_direccion(1000000021, 'Calle 16 # 100-20, Apto 402',
                            'Edificio Bosques del Lili', 13, @dir);
SELECT @dir AS idDireccion_creada;
-- Resultado esperado: OK, idDireccion 17

-- P06: Dirección para un cliente que no existe
CALL sp_registrar_direccion(123, 'Calle 1 # 1-1', NULL, 13, @dir_x);
-- Resultado esperado: Error 1644 (45000): El cliente no existe

-- P07: Registrar solicitud válida (pedido a establecimiento)
CALL sp_registrar_solicitud(1000000021, @dir, 2, NULL,
                            'Pedido #4592 - Pizza familiar hawaiana', 54000.00, 2, @sol);
SELECT * FROM vw_solicitudes_detalle WHERE numeroSolicitud = @sol;
-- Resultado esperado: OK, solicitud 1022 en estado Creada y 'Sin asignar'

-- P08: Registrar paquete con dirección de recogida externa
CALL sp_registrar_solicitud(1000000021, @dir, NULL, 'Carrera 4 # 11-55, Local 2, Centro',
                            'Paquete - Documentos para firma', 11000.00, 1, @paq);
SELECT numeroSolicitud, origen, estado FROM vw_solicitudes_detalle WHERE numeroSolicitud = @paq;
-- Resultado esperado: OK, solicitud 1023 con origen 'Recogida: Carrera 4 # 11-55...'

-- P09: Registrar solicitud con dirección de otro cliente
CALL sp_registrar_solicitud(1000000021, 1, 2, NULL,
                            'Pedido de prueba', 20000.00, 1, @sol_x);
-- Resultado esperado: Error 1644 (45000): La direccion de entrega no pertenece al cliente de la solicitud

-- P10: Asignar domiciliario inactivo (1000000019)
CALL sp_asignar_domiciliario(@sol, 1000000019);
-- Resultado esperado: Error 1644 (45000): No se puede asignar un domiciliario inactivo

-- P11: Asignar domiciliario que ya tiene 2 solicitudes activas (1000000014)
CALL sp_asignar_domiciliario(@sol, 1000000014);
-- Resultado esperado: Error 1644 (45000): El domiciliario ya tiene 2 solicitudes activas

-- P12: Asignar domiciliario disponible
CALL sp_asignar_domiciliario(@sol, 1000000022);
SELECT numeroSolicitud, idDomiciliario, idEstadoSolicitud, fechaAsignacion, horaAsignacion
  FROM Solicitud WHERE numeroSolicitud = @sol;
-- Resultado esperado: OK, estado 2 (Asignada) con fecha y hora de asignación automáticas

-- P13: Saltar de Asignada a Finalizada
CALL sp_cambiar_estado_solicitud(@sol, 'Finalizada');
-- Resultado esperado: Error 1644 (45000): Cambio de estado no permitido

-- P14: Asignada -> En curso
CALL sp_cambiar_estado_solicitud(@sol, 'En curso');
-- Resultado esperado: OK

-- P15: Cambiar el domiciliario con la solicitud en curso
CALL sp_asignar_domiciliario(@sol, 1000000013);
-- Resultado esperado: Error 1644 (45000): Solo se asignan solicitudes en estado Creada o Asignada

-- P16: En curso -> Finalizada
CALL sp_cambiar_estado_solicitud(@sol, 'Finalizada');
-- Resultado esperado: OK

-- P17: Modificar una solicitud finalizada
UPDATE Solicitud SET montoTotal = 60000.00 WHERE numeroSolicitud = @sol;
-- Resultado esperado: Error 1644 (45000): No se puede modificar una solicitud finalizada o cancelada

-- P18: Estado que no existe
CALL sp_cambiar_estado_solicitud(@sol, 'Pendiente');
-- Resultado esperado: Error 1644 (45000): El estado indicado no existe

-- P19: Creada -> En curso, sin pasar por Asignada
CALL sp_cambiar_estado_solicitud(1021, 'En curso');
-- Resultado esperado: Error 1644 (45000): Cambio de estado no permitido

-- P20: Incidente en una solicitud sin domiciliario
CALL sp_registrar_incidente(1021, 1, 'Demora en el establecimiento', @inc_x);
-- Resultado esperado: Error 1644 (45000): No se registran incidentes en solicitudes sin domiciliario

-- P21: Incidente válido
CALL sp_registrar_incidente(@sol, 1, 'La pizzería demoró 15 minutos en entregar el pedido.', @inc);
SELECT * FROM Incidente WHERE codigoIncidente = @inc;
-- Resultado esperado: OK, incidente 16 con la fecha y hora actuales

-- P22: Incidente con fecha anterior a la creación de la solicitud
INSERT INTO Incidente (codigoIncidente, descripcion, fechaIncidente, horaIncidente,
                       idTipoIncidente, numeroSolicitud)
VALUES (99, 'Prueba de fecha', '2026-09-01', '08:00:00', 1, 1001);
-- Resultado esperado: Error 1644 (45000): El incidente no puede ser anterior a la creacion de la solicitud

-- P23: Inactivar domiciliario con solicitudes activas (código 1003 = Yeison, tiene la 1012)
CALL sp_cambiar_estado_domiciliario(1003, 'Inactivo');
-- Resultado esperado: Error 1644 (45000): El domiciliario tiene solicitudes activas y no se puede inactivar

-- P24: Inactivar domiciliario sin solicitudes activas (código 1010 = Mariana)
CALL sp_cambiar_estado_domiciliario(1010, 'Inactivo');
-- Resultado esperado: OK

-- P25: Activar domiciliario inactivo (código 1004 = Luis)
CALL sp_cambiar_estado_domiciliario(1004, 'Activo');
SELECT codigoUnico, idEstadoDomiciliario FROM Domiciliario WHERE codigoUnico IN (1004, 1010);
-- Resultado esperado: OK, 1004 queda en 1 (Activo) y 1010 en 2 (Inactivo)

-- P26: Cancelar una solicitud Creada
CALL sp_cambiar_estado_solicitud(1021, 'Cancelada');
-- Resultado esperado: OK

-- P27: Asignar una solicitud cancelada
CALL sp_asignar_domiciliario(1021, 1000000013);
-- Resultado esperado: Error 1644 (45000): Solo se asignan solicitudes en estado Creada o Asignada

-- P28: Consultas de verificación
CALL sp_historial_solicitud(@sol);
-- Resultado esperado: 4 filas: CREACION, Creada->Asignada, Asignada->En curso, En curso->Finalizada

CALL sp_historial_solicitud(1021);
-- Resultado esperado: 2 filas: CREACION y Creada->Cancelada

SELECT * FROM vw_domiciliarios_disponibles;
SELECT * FROM vw_resumen_clientes ORDER BY total_pagado DESC;

CALL sp_resumen_domiciliario(1000000022);
-- Resultado esperado: 1 solicitud finalizada, total movilizado 54000.00, 1 incidente

CALL sp_reporte_establecimientos('2026-09-01', '2026-12-31');
CALL sp_reporte_desempeno_domiciliarios();
SELECT * FROM AuditoriaSolicitud;
