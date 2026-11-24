# Sistema de gestión de domicilios · Cali

Proyecto Integrador · Bases de Datos 1 · UAO
Backend en **Spring Boot** conectado a **MySQL** (base `ProyectoIntegrador`) con una **interfaz gráfica web** y pruebas en **Postman**.

Todo lo que se hace en la interfaz (crear, editar, asignar, cambiar estado o eliminar) se ejecuta como `INSERT`, `UPDATE` o `DELETE` sobre MySQL. Se puede comprobar en MySQL Workbench con un `SELECT`.

```
Navegador (interfaz)  →  API REST Spring Boot  →  MySQL (ProyectoIntegrador)
   index.html / app.js      /api/solicitudes ...      tablas del script
```

---

## 1. Requisitos

- **Java JDK 17** o superior
- **MySQL 8** con el script `ProyectoIntegrador.sql` ya ejecutado (crea la base y los datos)
- **IntelliJ IDEA** (recomendado, ya trae Maven) o VS Code con *Extension Pack for Java*
- **Postman** para las pruebas

## 2. Configurar la conexión

Abra `src/main/resources/application.properties` y ponga su usuario y contraseña de MySQL:

```properties
spring.datasource.username=root
spring.datasource.password=SU_CONTRASEÑA
```

## 3. Ejecutar

- **IntelliJ:** *File → Open* → seleccione la carpeta `domicilios-app`. Espere a que descargue las dependencias de Maven y ejecute `DomiciliosApplication` (botón ▶).
- **Terminal:** `mvn spring-boot:run`

Cuando la consola muestre `Started DomiciliosApplication`, abra **http://localhost:8080**.

## 4. Demostración para la sustentación

1. En la interfaz, pestaña **Solicitudes → + Nueva**. Elija un cliente (solo aparecen *sus* direcciones), un establecimiento, la descripción, el monto y el método de pago, y guarde.
2. En MySQL Workbench ejecute:
   ```sql
   SELECT * FROM Solicitud ORDER BY numeroSolicitud DESC;
   ```
   La solicitud nueva aparece con estado 1 (Creada) y la fecha y hora actuales.
3. En la interfaz pulse **Asignar**, elija un domiciliario y vuelva a ejecutar el `SELECT`. Ahora tiene `idDomiciliario`, `fechaAsignacion`, `horaAsignacion` y estado 2.
4. La consola de Spring Boot muestra cada SQL ejecutado (líneas `Executing prepared SQL statement`).

Reglas del enunciado que se pueden mostrar en vivo (la interfaz muestra el error en rojo):

| Intento | Resultado |
|---|---|
| Solicitud con establecimiento **y** dirección externa | Rechazada: un único lugar de recogida |
| Solicitud sin lugar de recogida | Rechazada |
| Asignar un domiciliario inactivo | No aparece en la lista; la API lo rechaza |
| Pasar a *En curso* sin domiciliario | Rechazado |
| Finalizar sin pasar por *En curso* | Rechazado |
| Incidente con fecha anterior a la solicitud | Rechazado |
| Eliminar un cliente que tiene solicitudes | MySQL lo impide por la llave foránea |

## 5. Pruebas con Postman

1. Postman → **Import** → `postman/Domicilios.postman_collection.json`
2. Clic derecho sobre la colección → **Run collection** → **Run**.

Son 39 peticiones en orden: crean un cliente, una dirección, un domiciliario, un establecimiento y solicitudes de prueba; validan las reglas de negocio (casos válidos y de error) y al final **eliminan todo lo creado**, así que se puede correr varias veces. Cada petición tiene *tests* que verifican el código de respuesta y el contenido.

## 6. API REST

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/api/catalogos` | Barrios, tipos, estados, métodos de pago, medios de transporte, tipos de incidente |
| GET, POST | `/api/clientes` | Listar / crear (Usuario + Cliente) |
| GET, PUT, DELETE | `/api/clientes/{id}` | Ver / editar / eliminar |
| GET, POST | `/api/domiciliarios` | Listar / crear (Usuario + Domiciliario) |
| GET, PUT, DELETE | `/api/domiciliarios/{id}` | Ver / editar / eliminar |
| GET, POST | `/api/establecimientos` | Listar / crear |
| GET, PUT, DELETE | `/api/establecimientos/{id}` | Ver / editar / eliminar |
| GET, POST | `/api/direcciones` (`?cliente=id`) | Listar (opcionalmente de un cliente) / crear |
| GET, PUT, DELETE | `/api/direcciones/{id}` | Ver / editar / eliminar |
| GET, POST | `/api/solicitudes` | Listar / crear (queda en estado Creada) |
| GET, PUT, DELETE | `/api/solicitudes/{numero}` | Ver / editar datos / eliminar (con sus incidentes) |
| PUT | `/api/solicitudes/{numero}/asignar` | `{"idDomiciliario": ...}`: asigna y guarda fecha/hora |
| PUT | `/api/solicitudes/{numero}/estado` | `{"idEstadoSolicitud": ...}`: cambia el estado |
| GET, POST | `/api/incidentes` (`?solicitud=n`) | Listar / registrar |
| GET, PUT, DELETE | `/api/incidentes/{codigo}` | Ver / editar / eliminar |

Códigos de respuesta: `200` OK, `201` creado, `204` eliminado, `400` dato inválido o regla incumplida, `404` no existe, `409` MySQL rechazó la operación (llave duplicada o foránea). Los errores llegan como `{"error": "mensaje"}`.

## 7. Estructura del proyecto

```
domicilios-app/
├── pom.xml                         dependencias (Spring Web, JDBC, driver MySQL)
├── postman/Domicilios.postman_collection.json
└── src/main/
    ├── java/co/edu/uao/domicilios/
    │   ├── DomiciliosApplication.java      arranque
    │   ├── controlador/                    un controlador REST por tabla principal
    │   │   ├── CatalogoController.java
    │   │   ├── ClienteController.java
    │   │   ├── DomiciliarioController.java
    │   │   ├── EstablecimientoController.java
    │   │   ├── DireccionController.java
    │   │   ├── SolicitudController.java    reglas de negocio de las solicitudes
    │   │   └── IncidenteController.java
    │   └── soporte/
    │       ├── Campos.java                 lectura y validación de los datos del JSON
    │       ├── Ids.java                    siguiente código (MAX + 1)
    │       ├── Usuarios.java               parte común de Cliente y Domiciliario
    │       ├── ManejadorErrores.java       errores → mensajes en español
    │       └── NoEncontradoException.java
    └── resources/
        ├── application.properties          conexión a MySQL
        └── static/                         interfaz gráfica
            ├── index.html
            ├── estilos.css
            └── app.js
```

**Decisiones de diseño**

- Se usa `JdbcTemplate` con SQL escrito a mano (no JPA), para que cada operación de la interfaz corresponda a un `INSERT`/`UPDATE`/`DELETE` visible y fácil de explicar.
- Los parámetros siempre van con `?` (consultas preparadas), lo que evita la inyección SQL.
- Las operaciones que tocan dos tablas (por ejemplo, Usuario + Cliente) son `@Transactional`: se guardan ambas o ninguna.
- Las llaves primarias del script no son `AUTO_INCREMENT`, por eso el siguiente código se calcula como `MAX + 1`.

## 8. Problemas comunes

| Mensaje | Solución |
|---|---|
| `Access denied for user 'root'` | Contraseña incorrecta en `application.properties` |
| `Unknown database 'ProyectoIntegrador'` | Ejecute primero el script SQL en MySQL |
| `Port 8080 was already in use` | Cierre la otra aplicación o cambie `server.port` |
| `Table 'proyectointegrador.solicitud' doesn't exist` (Linux) | En Linux MySQL distingue mayúsculas: cree las tablas con el script original sin cambiar nombres |
| La interfaz dice "No hay conexión con el servidor" | La aplicación Spring Boot no está corriendo |
