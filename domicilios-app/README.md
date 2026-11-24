# Sistema de gestión de domicilios · Cali

Proyecto Integrador · Bases de Datos 1 · Universidad Autónoma de Occidente

Base de datos **MySQL** (`ProyectoIntegrador`), objetos procedimentales (triggers, funciones, procedimientos, cursor y vistas), backend en **Spring Boot**, **interfaz gráfica web** y pruebas en **Postman**.

Todo lo que se hace en la interfaz (crear, editar, asignar, cambiar estado o eliminar) se ejecuta como `INSERT`, `UPDATE` o `DELETE` en MySQL, y se puede comprobar con un `SELECT` en MySQL Workbench.

```
Navegador (interfaz)  →  API REST Spring Boot  →  MySQL (ProyectoIntegrador)
   index.html / app.js      /api/...                 15 tablas + AuditoriaSolicitud
                                                      triggers, funciones, procedimientos, vistas
```

---

## 1. Requisitos

- **Java JDK 17** o superior
- **MySQL 8** y **MySQL Workbench**
- **Visual Studio Code** con *Extension Pack for Java* y *Spring Boot Extension Pack* (o IntelliJ IDEA)
- **Postman** (aplicación de escritorio)

## 2. Crear la base de datos

En MySQL Workbench, abrir y ejecutar **completos** (rayo ⚡), en este orden, los archivos de la carpeta `base-de-datos`:

| # | Archivo | Contenido |
|---|---|---|
| 1 | `01_ProyectoIntegrador.sql` | Base de datos, 15 tablas, datos de prueba y consultas (Entrega 2) |
| 2 | `02_Entrega3_LenguajeProcedimental.sql` | Procedimientos, funciones, triggers y cursor (Entrega 3) |
| 3 | `03_Entrega4_Backend.sql` | Tabla de auditoría, triggers de reglas de negocio, procedimientos de operación y vistas (Entrega 4) |
| 4 | `04_Pruebas_Entrega3_y_4.sql` | Pruebas de los objetos. **Ejecutar una por una** (Ctrl + Enter); varias deben fallar a propósito |

Para empezar de cero: `DROP DATABASE ProyectoIntegrador;` y volver a ejecutar 1, 2 y 3.

## 3. Configurar la conexión

En `src/main/resources/application.properties`, poner el usuario y la contraseña de MySQL:

```properties
spring.datasource.username=root
spring.datasource.password=SU_CONTRASEÑA
```

> No suba su contraseña real a GitHub.

## 4. Ejecutar

- **VS Code:** abrir la carpeta `domicilios-app` (la que tiene `pom.xml`), esperar a que diga *Java: Ready*, abrir `DomiciliosApplication.java` y dar clic en **Run**.
- **IntelliJ:** *File → Open* → `domicilios-app` → ejecutar `DomiciliosApplication`.

Cuando la consola muestre `Started DomiciliosApplication`, abrir **http://localhost:8080**.

## 5. Interfaz

| Pestaña | Qué permite |
|---|---|
| Solicitudes | Crear, editar, eliminar; **Asignar** domiciliario; cambiar **Estado**; ver **Incidentes** e **Historial** (auditoría) |
| Clientes, Direcciones, Domiciliarios, Establecimientos, Incidentes | Crear, consultar, editar y eliminar |
| Reportes | 8 reportes hechos con los procedimientos, el cursor y las vistas de las Entregas 3 y 4 |

## 6. Reglas de negocio

Se validan en dos niveles: el **backend** (mensaje claro antes de tocar la base) y **MySQL** (triggers de las Entregas 3 y 4, que protegen los datos aunque se modifiquen desde Workbench).

| Regla | Backend | MySQL |
|---|---|---|
| Un único lugar de recogida (establecimiento **o** dirección externa) | `SolicitudController` | `trg_validar_solicitud_insert` |
| La dirección de entrega pertenece al cliente | `SolicitudController` | `trg_validar_solicitud_insert` |
| Monto mayor que 0 | `SolicitudController` | `trg_validar_solicitud_insert` |
| Toda solicitud nueva queda Creada y sin domiciliario | `SolicitudController` | `trg_validar_solicitud_insert` |
| Solo domiciliarios activos, que no sean el cliente y con menos de 2 solicitudes activas | `/asignar` | `trg_validar_domiciliario` |
| Flujo de estados Creada → Asignada → En curso → Finalizada (o Cancelada) | `/estado` | `trg_flujo_estado_solicitud` |
| Fecha y hora de asignación automáticas | `/asignar` | `trg_flujo_estado_solicitud` |
| Incidentes solo en solicitudes con domiciliario y no anteriores a la solicitud | `IncidenteController` | `trg_validar_incidente` |
| No inactivar un domiciliario con solicitudes activas | `DomiciliarioController` | `trg_validar_inactivar_domiciliario` |
| Historial de cada solicitud | — | `trg_auditar_creacion_solicitud`, `trg_auditar_cambio_solicitud` |

## 7. API REST

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/api/catalogos` | Barrios, tipos, estados, métodos de pago, medios de transporte, tipos de incidente |
| GET, POST | `/api/clientes` | Listar / crear (Usuario + Cliente) |
| GET, PUT, DELETE | `/api/clientes/{id}` | Ver / editar / eliminar |
| GET, POST | `/api/domiciliarios` | Listar (con solicitudes activas) / crear |
| GET, PUT, DELETE | `/api/domiciliarios/{id}` | Ver / editar / eliminar |
| GET, POST | `/api/establecimientos` | Listar / crear |
| GET, PUT, DELETE | `/api/establecimientos/{id}` | Ver / editar / eliminar |
| GET, POST | `/api/direcciones` (`?cliente=id`) | Listar / crear |
| GET, PUT, DELETE | `/api/direcciones/{id}` | Ver / editar / eliminar |
| GET, POST | `/api/solicitudes` | Listar / crear (estado Creada) |
| GET, PUT, DELETE | `/api/solicitudes/{numero}` | Ver / editar / eliminar (con incidentes e historial) |
| PUT | `/api/solicitudes/{numero}/asignar` | `{"idDomiciliario": ...}` |
| PUT | `/api/solicitudes/{numero}/estado` | `{"idEstadoSolicitud": ...}` |
| GET | `/api/solicitudes/{numero}/historial` | Auditoría (`sp_historial_solicitud`) |
| GET, POST | `/api/incidentes` (`?solicitud=n`) | Listar / registrar |
| GET, PUT, DELETE | `/api/incidentes/{codigo}` | Ver / editar / eliminar |
| GET | `/api/reportes/solicitudes-detalle` | Vista `vw_solicitudes_detalle` |
| GET | `/api/reportes/solicitudes-por-fecha?fecha=AAAA-MM-DD` | `sp_solicitudes_por_fecha` |
| GET | `/api/reportes/resumen-domiciliario/{id}` | `sp_resumen_domiciliario` |
| GET | `/api/reportes/desempeno-domiciliarios` | Cursor `sp_reporte_desempeno_domiciliarios` |
| GET | `/api/reportes/domiciliarios-disponibles` | Vista `vw_domiciliarios_disponibles` |
| GET | `/api/reportes/clientes` | Vista `vw_resumen_clientes` |
| GET | `/api/reportes/establecimientos?inicio=...&fin=...` | `sp_reporte_establecimientos` |
| GET | `/api/reportes/auditoria` | Tabla `AuditoriaSolicitud` |

Códigos: `200` OK, `201` creado, `204` eliminado, `400` dato inválido o regla incumplida (incluye los errores `SIGNAL` de los triggers), `404` no existe, `409` restricción de la base de datos. Los errores llegan como `{"error": "mensaje"}`.

## 8. Pruebas con Postman

1. Postman → **Import** → `postman/Domicilios.postman_collection.json`.
2. Con la aplicación corriendo: clic derecho en la colección → **Run** → **Start run**.

**61 peticiones y 106 verificaciones** en 9 carpetas: catálogos, clientes, direcciones, domiciliarios y establecimientos, reglas de negocio de las solicitudes, incidentes, integridad referencial, reportes y auditoría, y limpieza. La colección crea sus propios datos de prueba y al final los elimina, así que se puede ejecutar varias veces. La carpeta 8 necesita los scripts 02 y 03.

## 9. Estructura del proyecto

```
domicilios-app/
├── base-de-datos/          scripts SQL (01 a 04)
├── postman/                colección de pruebas
├── pom.xml                 dependencias (Spring Web, JDBC, driver MySQL)
└── src/main/
    ├── java/co/edu/uao/domicilios/
    │   ├── DomiciliosApplication.java
    │   ├── controlador/    un controlador REST por tabla principal + ReporteController
    │   └── soporte/        validación de datos, códigos, usuarios, errores y formato de reportes
    └── resources/
        ├── application.properties
        └── static/         interfaz gráfica (index.html, estilos.css, app.js)
```

## 10. Problemas comunes

| Mensaje | Solución |
|---|---|
| `Access denied for user 'root'` | Contraseña incorrecta en `application.properties`; corregir y reiniciar |
| `Unknown database 'ProyectoIntegrador'` | Ejecutar `01_ProyectoIntegrador.sql` |
| "Faltan objetos en MySQL…" en Reportes o Historial | Ejecutar `02_…` y `03_…` |
| `Communications link failure` | MySQL está apagado |
| `Port 8080 was already in use` | Detener la otra ejecución de la aplicación |
| "No hay conexión con el servidor" en la interfaz | La aplicación Spring Boot no está corriendo |
