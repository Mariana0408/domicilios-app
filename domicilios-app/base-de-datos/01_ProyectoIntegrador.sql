CREATE DATABASE ProyectoIntegrador;
USE ProyectoIntegrador;
CREATE TABLE Comuna (
    idComuna INT PRIMARY KEY,
    nombreComuna VARCHAR(100) NOT NULL
);
CREATE TABLE Barrio (
    idBarrio INT PRIMARY KEY,
    nombreBarrio VARCHAR(100) NOT NULL,
    idComuna INT NOT NULL,
    FOREIGN KEY (idComuna) REFERENCES Comuna(idComuna)
);
 
CREATE TABLE TipoEstablecimiento (
    idTipoEstablecimiento INT PRIMARY KEY,
    nombreTipoEstablecimiento VARCHAR(50) NOT NULL
);
 
CREATE TABLE MetodoPago (
    idMetodoPago INT PRIMARY KEY,
    nombreMetodo VARCHAR(50) NOT NULL
);
 
CREATE TABLE EstadoSolicitud (
    idEstadoSolicitud INT PRIMARY KEY,
    nombreEstadoSolicitud VARCHAR(50) NOT NULL
);
 
CREATE TABLE EstadoDomiciliario (
    idEstadoDomiciliario INT PRIMARY KEY,
    nombreEstadoDomiciliario VARCHAR(50) NOT NULL
);
 
CREATE TABLE MedioTransporte (
    idMedioTransporte INT PRIMARY KEY,
    nombreMedioTransporte VARCHAR(50) NOT NULL
);
 
CREATE TABLE TipoIncidente (
    idTipoIncidente INT PRIMARY KEY,
    nombreTipoIncidente VARCHAR(100) NOT NULL
);
 
CREATE TABLE Usuario (
    numeroIdentificacion INT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido_Paterno VARCHAR(100) NOT NULL,
    apellido_Materno VARCHAR(100) NOT NULL,
    numeroTelefono VARCHAR(20) NOT NULL,
    correoElectronico VARCHAR(100)
);
 
CREATE TABLE Cliente (
    idCliente INT PRIMARY KEY,
    FOREIGN KEY (idCliente) REFERENCES Usuario(numeroIdentificacion)
);
 
CREATE TABLE Domiciliario (
    idDomiciliario INT PRIMARY KEY,
    codigoUnico INT UNIQUE NOT NULL,
    idEstadoDomiciliario INT NOT NULL,
    idMedioTransporte INT NOT NULL,
    FOREIGN KEY (idDomiciliario) REFERENCES Usuario(numeroIdentificacion),
    FOREIGN KEY (idEstadoDomiciliario) REFERENCES EstadoDomiciliario(idEstadoDomiciliario),
    FOREIGN KEY (idMedioTransporte) REFERENCES MedioTransporte(idMedioTransporte)
);
 
CREATE TABLE Direccion (
    idDireccion INT PRIMARY KEY,
    ubicacion VARCHAR(255) NOT NULL,
    referencia VARCHAR(255),
    idBarrio INT NOT NULL,
    idCliente INT NOT NULL,
    FOREIGN KEY (idBarrio) REFERENCES Barrio(idBarrio),
    FOREIGN KEY (idCliente) REFERENCES Cliente(idCliente)
);
 
CREATE TABLE Establecimiento (
    idEstablecimiento INT PRIMARY KEY,
    nombreComercial VARCHAR(100) NOT NULL,
    ubicacion VARCHAR(255) NOT NULL,
    telefono VARCHAR(20) NOT NULL,
    email VARCHAR(100),
    idTipoEstablecimiento INT NOT NULL,
    idBarrio INT NOT NULL,
    FOREIGN KEY (idTipoEstablecimiento) REFERENCES TipoEstablecimiento(idTipoEstablecimiento),
    FOREIGN KEY (idBarrio) REFERENCES Barrio(idBarrio)
);
 
CREATE TABLE Solicitud (
    numeroSolicitud INT PRIMARY KEY,
    fechaCreacion DATE NOT NULL,
    horaCreacion TIME NOT NULL,
    fechaAsignacion DATE,
    horaAsignacion TIME,
    descripcion VARCHAR(200) NOT NULL,
    montoTotal DECIMAL(10,2) NOT NULL,
    direccionRecogidaExterna VARCHAR(255),
    idDireccion INT NOT NULL,
    idEstablecimiento INT,
    idCliente INT NOT NULL,
    idDomiciliario INT,
    idMetodoPago INT NOT NULL,
    idEstadoSolicitud INT NOT NULL,
    FOREIGN KEY (idDireccion) REFERENCES Direccion(idDireccion),
    FOREIGN KEY (idEstablecimiento) REFERENCES Establecimiento(idEstablecimiento),
    FOREIGN KEY (idCliente) REFERENCES Cliente(idCliente),
    FOREIGN KEY (idDomiciliario) REFERENCES Domiciliario(idDomiciliario),
    FOREIGN KEY (idMetodoPago) REFERENCES MetodoPago(idMetodoPago),
    FOREIGN KEY (idEstadoSolicitud) REFERENCES EstadoSolicitud(idEstadoSolicitud)
);
 
CREATE TABLE Incidente (
    codigoIncidente INT PRIMARY KEY,
    descripcion VARCHAR(300) NOT NULL,
    fechaIncidente DATE NOT NULL,
    horaIncidente TIME NOT NULL,
    idTipoIncidente INT NOT NULL,
    numeroSolicitud INT NOT NULL,
    FOREIGN KEY (idTipoIncidente) REFERENCES TipoIncidente(idTipoIncidente),
    FOREIGN KEY (numeroSolicitud) REFERENCES Solicitud(numeroSolicitud)
);
INSERT INTO Comuna (idComuna, nombreComuna) VALUES
    (2, 'Comuna 2'),
    (3, 'Comuna 3'),
    (5, 'Comuna 5'),
    (6, 'Comuna 6'),
    (7, 'Comuna 7'),
    (13, 'Comuna 13'),
    (17, 'Comuna 17'),
    (18, 'Comuna 18'),
    (19, 'Comuna 19'),
    (20, 'Comuna 20'),
    (22, 'Comuna 22'),
    (8, 'Comuna 8');
 SELECT*FROM comuna;

INSERT INTO Barrio (idBarrio, nombreBarrio, idComuna) VALUES
    (1, 'Granada', 2),
    (2, 'Versalles', 2),
    (3, 'Santa Mónica', 2),
    (4, 'Normandía', 2),
    (5, 'San Antonio', 3),
    (6, 'El Peñón', 3),
    (7, 'San Nicolás', 3),
    (8, 'Chiminangos Primera Etapa', 5),
    (9, 'Floralia', 6),
    (10, 'Alfonso López', 7),
    (11, 'El Poblado II', 13),
    (12, 'Ciudad Jardín', 17),
    (13, 'Valle del Lili', 17),
    (14, 'El Ingenio', 17),
    (15, 'Limonar', 17),
    (16, 'Meléndez', 18),
    (17, 'San Fernando', 19),
    (18, 'Tequendama', 19),
    (19, 'Siloé', 20),
    (20, 'Pance', 22),
    (21, 'Bochalema', 22),
    (22, 'Villacolombia', 8);
 SELECT*FROM barrio;

INSERT INTO TipoEstablecimiento (idTipoEstablecimiento, nombreTipoEstablecimiento) VALUES
    (1, 'Restaurante'),
    (2, 'Farmacia'),
    (3, 'Supermercado'),
    (4, 'Tienda especializada');
 SELECT*FROM TipoEstablecimiento;

INSERT INTO MetodoPago (idMetodoPago, nombreMetodo) VALUES
    (1, 'Efectivo'),
    (2, 'Electronico');
  SELECT*FROM MetodoPago;

INSERT INTO EstadoSolicitud (idEstadoSolicitud, nombreEstadoSolicitud) VALUES
    (1, 'Creada'),
    (2, 'Asignada'),
    (3, 'En curso'),
    (4, 'Finalizada'),
    (5, 'Cancelada');
SELECT*FROM EstadoSolicitud;

INSERT INTO EstadoDomiciliario (idEstadoDomiciliario, nombreEstadoDomiciliario) VALUES
    (1, 'Activo'),
    (2, 'Inactivo');
 
SELECT * FROM EstadoDomiciliario;
INSERT INTO MedioTransporte (idMedioTransporte, nombreMedioTransporte) VALUES
    (1, 'Bicicleta'),
    (2, 'Motocicleta'),
    (3, 'Automóvil');
SELECT * FROM MedioTransporte;
INSERT INTO TipoIncidente (idTipoIncidente, nombreTipoIncidente) VALUES
    (1, 'retraso'),
    (2, 'direccion incorrecta'),
    (3, 'Cliente no responde'),
    (4, 'Establecimiento no entrega');
 SELECT * FROM TipoIncidente;

INSERT INTO Usuario (numeroIdentificacion, nombre, apellido_Paterno, apellido_Materno, numeroTelefono, correoElectronico) VALUES
    (1000000001, 'Laura', 'Correa', 'Martinez', '3104567890', 'laura.martinez@gmail.com'),
    (1000000002, 'Carlos', 'Vivero', 'Rodriguez', '3115678901', 'carlor.rodriguez@gmail.com'),
    (1000000003, 'Andres', 'Bernal', 'Gomez', '3126789012', 'andres.gomez@gmail.com'),
    (1000000004, 'Valentina', 'Cabrera', 'Lopez', '3137890123', 'valentina.lopez@gmail.com'),
    (1000000005, 'Mateo', 'Caicedo', 'Sanchez', '3148901237', 'mateosanchez@gmail.com'),
    (1000000006, 'Daniela', 'Quetama', 'Torres', '3159012345', 'daniela.torres@gmail.com'),
    (1000000007, 'Santiago', 'Alavarado', 'Ramirez', '3160123456', 'santiago.rami@gmail.com'),
    (1000000008, 'Mariana', 'Quintana', 'Castro', '3171234567', 'marianacastro@gmail.com'),
    (1000000009, 'Juan', 'Olivares', 'Perez', '3182345678', 'juan.perez@gmail.com'),
    (1000000010, 'Sofia', 'Mendoza', 'Herrera', '3193456789', 'sofia.herrera@gmail.com'),
    (1000000011, 'Valentina', 'Rios', 'Cardona', '3104418827', 'valentina.rios@gmail.com'),
    (1000000012, 'Camila', 'Chavez', 'Zapata', '3203356841', NULL),
    (1000000013, 'Brayan', 'Caicedo', 'Angulo', '3206691534', 'brayan.caicedo@gmail.com'),
    (1000000014, 'Kevin', 'Barrera', 'Núñez', '3157783021', 'kevin.barrera@hotmail.com'),
    (1000000015, 'Yeison', 'Mosquera', 'Cuero', '3023349875', 'yeison.mosquera@gmail.com'),
    (1000000016, 'Luis', 'Arboleda', 'Sinisterra', '3189920763', 'luis.arboleda@gmail.com'),
    (1000000017, 'Diana', 'Rentería', 'Palacios', '3128806429', 'diana.renteria@gmail.com'),
    (1000000018, 'Hernán', 'Sandoval', 'Vidal', '3216674058', 'hernan.sandoval@hotmail.com'),
    (1000000019, 'Victoria', 'Yacup', 'Alcazar', '3024505387', 'victoria.yacup@hotmail.com'),
    (1000000020, 'Juan', 'Lemos', 'Rojas', '3006008798', NULL);
 SELECT * FROM usuario;

INSERT INTO Cliente (idCliente) VALUES
    (1000000001),
    (1000000002),
    (1000000003),
    (1000000004),
    (1000000005),
    (1000000006),
    (1000000007),
    (1000000008),
    (1000000009),
    (1000000010),
    (1000000011),
    (1000000012);
 
SELECT * FROM Cliente ;
INSERT INTO Domiciliario (idDomiciliario, codigoUnico, idEstadoDomiciliario, idMedioTransporte) VALUES
    (1000000013, 1001, 1, 1),
    (1000000014, 1002, 1, 1),
    (1000000015, 1003, 1, 2),
    (1000000016, 1004, 2, 2),
    (1000000017, 1005, 1, 3),
    (1000000018, 1006, 1, 2),
    (1000000019, 1007, 2, 2),
    (1000000020, 1008, 1, 1),
    (1000000007, 1009, 1, 1),
    (1000000008, 1010, 1, 1);
 SELECT * FROM Domiciliario; 
INSERT INTO Direccion (idDireccion, ubicacion, referencia, idBarrio, idCliente) VALUES
    (1, 'Carrera 98 # 16-40, Apto 502', 'Conjunto Altos de Lili, torre B', 13, 1000000001),
    (2, 'Avenida 6 Norte # 24N-50', 'Casa esquina con portón negro', 2, 1000000002),
    (3, 'Calle 5 # 38-12, Apto 301', 'Edificio Tequendama Real, entrar por portería', 18, 1000000003),
    (4, 'Carrera 100 # 13-85, Casa 14', 'Conjunto cerrado Ciudad Jardín, casa 14', 12, 1000000004),
    (5, 'Calle 2 Oeste # 4-20', 'Casa con balcón azul, cerca de la iglesia del barrio', 5, 1000000005),
    (6, 'Carrera 85 # 14-30, Apto 204', 'Edificio frente al parque', 14, 1000000006),
    (7, 'Carrera 94 # 4B-55', 'Casa de dos pisos con reja blanca', 16, 1000000007),
    (8, 'Calle 3 Oeste # 6-15', 'Portón verde, al lado de la tienda', 6, 1000000008),
    (9, 'Carrera 70 # 8-40, Apto 601', 'Edificio Limonar Plaza, torre única', 15, 1000000009),
    (10, 'Calle 2 # 34-70', 'Casa esquina, timbre del segundo piso', 17, 1000000010),
    (11, 'Calle 52 # 5-30', 'Casa de rejas rojas', 9, 1000000011),
    (12, 'Calle 72 # 1A-45', 'Frente a la cancha del barrio', 10, 1000000012),
    (13, 'Avenida 9 Norte # 15N-20, Apto 1002', 'Edificio Granada Norte, piso 10', 1, 1000000001),
    (14, 'Carrera 122 # 14-200, Casa 7', 'Condominio campestre, vía a Pance', 20, 1000000002),
    (15, 'Avenida 4 Norte # 47N-20, Casa 3', 'Conjunto cerrado, portería sobre la avenida', 3, 1000000003),
    (16, 'Carrera 99 # 17-20, Apto 301', 'Torre 2, portería principal', 13, 1000000004);
 SELECT * FROM Direccion;
INSERT INTO Establecimiento (idEstablecimiento, nombreComercial, ubicacion, telefono, email, idTipoEstablecimiento, idBarrio) VALUES
    (1, 'El Fogón del Valle', 'Avenida 9 Norte #14N-35', '6025231187', 'fogondelvalle@gmail.com', 1, 1),
    (2, 'Pizzería Don Marco', 'Carrera 98#16-42', '6023326540', 'pizzeriadonmarco@gmail.com', 1, 13),
    (3, 'Sushi Zen Cali', 'Calle 5#39-20', '3128840215', 'sushizencali@gmail.com', 1, 18),
    (4, 'Restaurante La Sazón de San Antonio', 'Calle 2 Oeste#5-18', '6028934471', 'lasazonsanantonio@gmail.com', 1, 5),
    (5, 'Farmacia Salud Vital', 'Calle 2#34-18', '6025580932', 'farmaciasaludvital@gmail.com', 2, 17),
    (6, 'Droguería La Esperanza', 'Carrera 6#14-25', '6028812256', 'droguerialaesperanza@gmail.com', 2, 7),
    (7, 'Farmacia Bienestar 24H', 'Carrera 100#14-30', '3156672089', 'bienestar24h@gmail.com', 2, 12),
    (8, 'Mercar', 'Carrera 112 #28-71', '6026643310', 'mercar@gmail.com', 3, 21),
    (9, 'Mercados del Sur', 'Carrera 94#4B-20', '6023390871', 'info@mercadosdelsur.com', 3, 16),
    (10, 'Tienda Don Pedro', 'Calle 52#15-30', '6023317745', 'donpedro@gmail.com', 4, 22),
    (11, 'Restaurante El Parque', 'Calle 10#66a-09', '3207751468', 'elparque@gmail.com', 1, 15),
    (12, 'Farmacia Central', 'Calle 18#122126', '3174402963', 'drogueriacentral@gmail.com', 2, 20);
    SELECT *FROM establecimiento;
    INSERT INTO Solicitud (numeroSolicitud, fechaCreacion, horaCreacion, fechaAsignacion, horaAsignacion, descripcion, montoTotal, direccionRecogidaExterna, idDireccion, idEstablecimiento, idCliente, idDomiciliario, idMetodoPago, idEstadoSolicitud) VALUES
    (1001, '2026-09-14', '12:10:00', '2026-09-14', '12:14:00', 'Pedido #4571 - 2 pizzas medianas y gaseosa', 68000.00, NULL, 1, 2, 1000000001, 1000000015, 2, 4),
    (1002, '2026-09-15', '19:30:00', '2026-09-15', '19:33:00', 'Pedido #4572 - Menú de sushi para 2 personas', 92000.00, NULL, 3, 3, 1000000003, 1000000020, 1, 4),
    (1003, '2026-09-17', '09:05:00', '2026-09-17', '09:09:00', 'Pedido #4573 - Medicamentos con fórmula médica', 45500.00, NULL, 5, 6, 1000000005, 1000000007, 1, 4),
    (1004, '2026-09-18', '16:40:00', NULL, NULL, 'Pedido #4574 - Mercado semanal (frutas, verduras y lácteos)', 134500.00, NULL, 8, 8, 1000000008, NULL, 1, 5),
    (1005, '2026-09-20', '13:20:00', '2026-09-20', '13:26:00', 'Pedido #4575 - 3 almuerzos ejecutivos', 57000.00, NULL, 7, 4, 1000000007, 1000000018, 1, 4),
    (1006, '2026-09-22', '10:15:00', '2026-09-22', '10:20:00', 'Paquete - Documentos para autenticar en notaría', 9000.00, 'Calle 10 # 4-47, Oficina 702, Centro', 9, NULL, 1000000009, 1000000013, 1, 4),
    (1007, '2026-09-24', '18:50:00', '2026-09-24', '18:54:00', 'Pedido #4577 - 2 bandejas valluna y jugos naturales', 74000.00, NULL, 13, 1, 1000000001, 1000000014, 2, 4),
    (1008, '2026-09-26', '11:30:00', '2026-09-26', '11:36:00', 'Pedido #4578 - 15 kg de alimento para perro y accesorios', 189900.00, NULL, 10, 10, 1000000010, 1000000017, 2, 4),
    (1009, '2026-09-28', '20:05:00', '2026-09-28', '20:09:00', 'Pedido #4579 - Medicamentos de venta libre', 28700.00, NULL, 4, 7, 1000000004, 1000000008, 1, 4),
    (1010, '2026-09-30', '14:00:00', '2026-09-30', '14:05:00', 'Paquete - Obsequio de cumpleaños', 10000.00, 'Carrera 4 # 11-55, Local 2, Centro', 15, NULL, 1000000003, 1000000015, 1, 5),
    (1011, '2026-10-04', '10:20:00', '2026-10-04', '10:24:00', 'Pedido #4581 - Combo familiar de pollo asado', 81000.00, NULL, 8, 4, 1000000008, 1000000018, 1, 3),
    (1012, '2026-10-04', '10:45:00', '2026-10-04', '10:49:00', 'Pedido #4582 - Antibiótico y vitaminas', 52300.00, NULL, 12, 6, 1000000012, 1000000015, 2, 3),
    (1013, '2026-10-04', '11:05:00', '2026-10-04', '11:08:00', 'Descripcion', 156800.00, NULL, 11, 9, 1000000011, 1000000017, 2, 2),
    (1014, '2026-10-04', '11:30:00', NULL, NULL, 'Paquete - Documentos de matrícula universitaria', 12000.00, 'Calle 25 Norte # 6A-15, Oficina 204', 16, NULL, 1000000004, NULL, 2, 1),
    (1015, '2026-10-04', '11:42:00', NULL, NULL, 'Pedido #4585 - Medicamentos y artículos de aseo personal', 64500.00, NULL, 14, 12, 1000000002, NULL, 2, 1),
    (1016, '2026-10-04', '11:50:00', '2026-10-04', '11:54:00', 'Pedido #4586 - 2 menús del día y limonadas', 46000.00, NULL, 6, 11, 1000000006, 1000000020, 1, 2),
    (1017, '2026-10-04', '11:55:00', NULL, NULL, 'Pedido #4587 - Analgésicos y crema hidratante', 31200.00, NULL, 10, 5, 1000000010, NULL, 1, 5),
    (1018, '2026-10-04', '12:00:00', '2026-10-04', '12:03:00', 'Pedido #4588 - Almuerzo corriente y jugo natural', 29500.00, NULL, 2, 1, 1000000002, 1000000014, 1, 3),
    (1019, '2026-10-04', '12:05:00', NULL, NULL, 'Pedido #4589 - Frutas y verduras para la semana', 87400.00, NULL, 7, 9, 1000000007, NULL, 2, 1),
    (1020, '2026-10-04', '12:10:00', NULL, NULL, 'Pedido #4590 - 16 rollos de sushi', 118000.00, NULL, 12, 3, 1000000012, NULL, 2, 1);
    SELECT * FROM solicitud; 
   INSERT INTO Incidente (codigoIncidente, descripcion, fechaIncidente, horaIncidente, idTipoIncidente, numeroSolicitud) VALUES
    (1, 'La pizzería demoró 25 minutos en preparar el pedido.', '2026-09-14', '12:55:00', 1, 1001),
    (2, 'El cliente no contestó el timbre; se logró contacto por llamada tras 10 minutos.', '2026-09-15', '20:10:00', 3, 1002),
    (3, 'Trancón por accidente en la vía; la entrega se hizo con 20 minutos de retraso.', '2026-09-17', '09:40:00', 1, 1003),
    (4, 'El restaurante entregó el pedido incompleto; faltaba un almuerzo.', '2026-09-20', '13:50:00', 4, 1005),
    (5, 'Retraso adicional en el trayecto por tráfico en hora pico.', '2026-09-20', '14:20:00', 1, 1005),
    (6, 'La dirección de entrega no coincidía con la nomenclatura del edificio.', '2026-09-22', '10:50:00', 2, 1006),
    (7, 'Retraso por alta demanda en el establecimiento en hora pico.', '2026-09-24', '19:35:00', 1, 1007),
    (8, 'El cliente indicó otra torre; el domiciliario debió confirmar la dirección.', '2026-09-26', '12:10:00', 2, 1008),
    (9, 'El cliente no atendió las llamadas al llegar el domiciliario.', '2026-09-28', '20:30:00', 3, 1009),
    (10, 'El cliente no contestó llamadas; la solicitud fue cancelada.', '2026-09-30', '14:40:00', 3, 1010),
    (11, 'Retraso en la preparación del pedido por alta demanda.', '2026-10-04', '10:55:00', 1, 1011),
    (12, 'La droguería no tenía disponible uno de los medicamentos; se espera confirmación.', '2026-10-04', '11:10:00', 4, 1012),
    (13, 'El domiciliario aún no llega al supermercado por tráfico en la vía.', '2026-10-04', '11:25:00', 1, 1013),
    (14, 'El restaurante tardó en preparar el pedido por alta demanda.', '2026-10-04', '12:00:00', 1, 1016),
    (15, 'El restaurante no entregó el jugo natural; se espera reposición.', '2026-10-04', '12:08:00', 4, 1018);
SELECT * FROM Incidente; 

SELECT
    Solicitud.numeroSolicitud,
    Solicitud.descripcion,
    Solicitud.montoTotal,
    Cliente.idCliente
FROM Solicitud
INNER JOIN Cliente
ON Solicitud.idCliente = Cliente.idCliente;
SELECT 
    d.idDomiciliario,
    d.codigoUnico,
    u.nombre,
    u.apellido_Paterno,
    u.numeroTelefono
FROM Domiciliario d
INNER JOIN Usuario u ON d.idDomiciliario = u.numeroIdentificacion;

SELECT 
    d.idDomiciliario AS numeroIdentificacion,
    u.nombre,
    u.apellido_Paterno,
    u.apellido_Materno,
    d.codigoUnico
FROM Domiciliario d
INNER JOIN Cliente c ON d.idDomiciliario = c.idCliente
INNER JOIN Usuario u ON d.idDomiciliario = u.numeroIdentificacion;

SELECT
    Domiciliario.codigoUnico,
    Domiciliario.idDomiciliario,
    Solicitud.numeroSolicitud,
    Solicitud.montoTotal
FROM Domiciliario
LEFT JOIN Solicitud
ON Domiciliario.idDomiciliario = Solicitud.idDomiciliario;

SELECT
    Establecimiento.nombreComercial,
    Solicitud.numeroSolicitud,
    Solicitud.descripcion
FROM Establecimiento
LEFT JOIN Solicitud
ON Establecimiento.idEstablecimiento =
   Solicitud.idEstablecimiento;
   
SELECT
    Solicitud.numeroSolicitud,
    Solicitud.descripcion,
    EstadoSolicitud.nombreEstadoSolicitud
FROM Solicitud
RIGHT JOIN EstadoSolicitud
ON Solicitud.idEstadoSolicitud =
   EstadoSolicitud.idEstadoSolicitud;

SELECT COUNT(*) AS cantidadSolicitudes
FROM Solicitud;

SELECT COUNT(*) AS cantidadSolicitudes
FROM Solicitud
WHERE idEstadoSolicitud = 2;

SELECT
    EstadoSolicitud.nombreEstadoSolicitud,
    COUNT(Solicitud.numeroSolicitud) AS cantidadSolicitudes
FROM EstadoSolicitud
LEFT JOIN Solicitud
ON EstadoSolicitud.idEstadoSolicitud =
   Solicitud.idEstadoSolicitud
GROUP BY EstadoSolicitud.nombreEstadoSolicitud;

SELECT MAX(montoTotal) AS montoMayor
FROM Solicitud;

SELECT MIN(montoTotal) AS montoMenor
FROM Solicitud;

SELECT
    MAX(montoTotal) AS montoMayor,
    MIN(montoTotal) AS montoMenor
FROM Solicitud;

SELECT *
FROM Solicitud
WHERE montoTotal > 70000;

SELECT *
FROM Establecimiento
WHERE nombreComercial LIKE '%Farmacia%';

SELECT
    numeroSolicitud,
    descripcion,
    montoTotal
FROM Solicitud
ORDER BY montoTotal ASC;

SELECT
    numeroSolicitud,
    descripcion,
    montoTotal
FROM Solicitud
ORDER BY montoTotal DESC;

SELECT *
FROM Solicitud
WHERE montoTotal > 50000
AND idEstadoSolicitud = 2;

SELECT *
FROM Solicitud
WHERE montoTotal >= 100000
OR idEstadoSolicitud = 5;

SELECT *
FROM Solicitud
WHERE (montoTotal > 70000 AND idMetodoPago = 2)
OR idEstadoSolicitud = 5;

SELECT *
FROM Cliente
WHERE idCliente IN (
    SELECT idCliente
    FROM Solicitud
);

SELECT *
FROM Cliente
WHERE idCliente IN (
    SELECT idCliente
    FROM Solicitud
    WHERE montoTotal > 100000
);

SELECT *
FROM Solicitud
WHERE montoTotal = (
    SELECT MAX(montoTotal)
    FROM Solicitud
);

SELECT *
FROM Solicitud
WHERE idEstadoSolicitud = (
    SELECT idEstadoSolicitud
    FROM Solicitud
    WHERE numeroSolicitud = 1001
);

SELECT *
FROM Cliente
WHERE EXISTS (
    SELECT *
    FROM Solicitud
    WHERE Solicitud.idCliente = Cliente.idCliente
);

SELECT *
FROM Cliente
WHERE EXISTS (
    SELECT *
    FROM Solicitud
    WHERE Solicitud.idCliente = Cliente.idCliente
    AND Solicitud.montoTotal > 100000
);

SELECT
    Solicitud.numeroSolicitud,
    Solicitud.descripcion,
    Solicitud.montoTotal,
    Establecimiento.nombreComercial
FROM Solicitud
INNER JOIN Establecimiento
ON Solicitud.idEstablecimiento =
   Establecimiento.idEstablecimiento
WHERE Solicitud.montoTotal > 50000
ORDER BY Solicitud.montoTotal DESC;

SELECT
    Solicitud.numeroSolicitud,
    Solicitud.montoTotal,
    Establecimiento.nombreComercial,
    EstadoSolicitud.nombreEstadoSolicitud
FROM Solicitud
INNER JOIN Establecimiento
ON Solicitud.idEstablecimiento = Establecimiento.idEstablecimiento
INNER JOIN EstadoSolicitud
ON Solicitud.idEstadoSolicitud = EstadoSolicitud.idEstadoSolicitud
WHERE Solicitud.montoTotal > 50000
AND Solicitud.idMetodoPago = 2
ORDER BY Solicitud.montoTotal DESC;

SELECT
    Solicitud.numeroSolicitud,
    Solicitud.descripcion,
    Solicitud.montoTotal,
    Establecimiento.nombreComercial,
    EstadoSolicitud.nombreEstadoSolicitud,
    MetodoPago.nombreMetodo
FROM Solicitud
INNER JOIN Establecimiento
ON Solicitud.idEstablecimiento =
   Establecimiento.idEstablecimiento
INNER JOIN EstadoSolicitud
ON Solicitud.idEstadoSolicitud =
   EstadoSolicitud.idEstadoSolicitud
INNER JOIN MetodoPago
ON Solicitud.idMetodoPago =
   MetodoPago.idMetodoPago
WHERE Solicitud.montoTotal > 50000
AND Solicitud.idMetodoPago = 2
ORDER BY Solicitud.montoTotal DESC;