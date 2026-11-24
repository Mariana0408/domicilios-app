package co.edu.uao.domicilios.controlador;

import java.math.BigDecimal;
import java.sql.Date;
import java.sql.Time;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import co.edu.uao.domicilios.soporte.Campos;
import co.edu.uao.domicilios.soporte.Filas;
import co.edu.uao.domicilios.soporte.Ids;
import co.edu.uao.domicilios.soporte.NoEncontradoException;

/**
 * Solicitudes de domicilio. Aquí están las reglas de negocio del enunciado:
 *  1. Un único lugar de recogida: establecimiento aliado O dirección externa, nunca ambos ni ninguno.
 *  2. La dirección de entrega debe ser una de las registradas por el cliente que hace la solicitud.
 *  3. Al asignar un domiciliario se guardan la fecha y hora de asignación. Solo se asignan domiciliarios
 *     activos, que no sean el mismo cliente y que tengan menos de 2 solicitudes activas.
 *  4. El estado avanza Creada → Asignada → En curso → Finalizada (o Cancelada en cualquier momento antes de terminar).
 *
 * Estas reglas también están en MySQL como triggers (Entregas 3 y 4): trg_validar_solicitud_insert,
 * trg_validar_domiciliario y trg_flujo_estado_solicitud. El backend las valida primero para dar un
 * mensaje claro; si algo llegara a MySQL sin cumplirlas, el trigger lo rechaza (doble protección).
 */
@RestController
@RequestMapping("/api/solicitudes")
public class SolicitudController {

    // Ids de la tabla EstadoSolicitud (según el script de inserción)
    private static final int CREADA = 1;
    private static final int ASIGNADA = 2;
    private static final int EN_CURSO = 3;
    private static final int FINALIZADA = 4;
    private static final int CANCELADA = 5;
    // Id de 'Activo' en la tabla EstadoDomiciliario
    private static final int DOMICILIARIO_ACTIVO = 1;
    // Máximo de solicitudes activas (Asignada o En curso) por domiciliario, igual que trg_validar_domiciliario
    private static final int MAX_SOLICITUDES_ACTIVAS = 2;

    private static final ZoneId ZONA = ZoneId.of("America/Bogota");

    private static final String CONSULTA = """
            SELECT s.numeroSolicitud,
                   DATE_FORMAT(s.fechaCreacion, '%Y-%m-%d') AS fechaCreacion,
                   TIME_FORMAT(s.horaCreacion, '%H:%i') AS horaCreacion,
                   DATE_FORMAT(s.fechaAsignacion, '%Y-%m-%d') AS fechaAsignacion,
                   TIME_FORMAT(s.horaAsignacion, '%H:%i') AS horaAsignacion,
                   s.descripcion, s.montoTotal, s.direccionRecogidaExterna,
                   s.idCliente, CONCAT(uc.nombre, ' ', uc.apellido_Paterno) AS nombreCliente,
                   s.idDireccion, d.ubicacion AS direccionEntrega,
                   s.idEstablecimiento, e.nombreComercial,
                   COALESCE(e.nombreComercial, s.direccionRecogidaExterna) AS lugarRecogida,
                   s.idDomiciliario, CONCAT(ud.nombre, ' ', ud.apellido_Paterno) AS nombreDomiciliario,
                   s.idMetodoPago, mp.nombreMetodo,
                   s.idEstadoSolicitud, es.nombreEstadoSolicitud,
                   (SELECT COUNT(*) FROM Incidente i WHERE i.numeroSolicitud = s.numeroSolicitud) AS cantidadIncidentes
            FROM Solicitud s
            INNER JOIN Usuario uc ON uc.numeroIdentificacion = s.idCliente
            INNER JOIN Direccion d ON d.idDireccion = s.idDireccion
            LEFT JOIN Establecimiento e ON e.idEstablecimiento = s.idEstablecimiento
            LEFT JOIN Usuario ud ON ud.numeroIdentificacion = s.idDomiciliario
            INNER JOIN MetodoPago mp ON mp.idMetodoPago = s.idMetodoPago
            INNER JOIN EstadoSolicitud es ON es.idEstadoSolicitud = s.idEstadoSolicitud
            """;

    private final JdbcTemplate jdbc;

    public SolicitudController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping
    public List<Map<String, Object>> listar() {
        return jdbc.queryForList(CONSULTA + " ORDER BY s.numeroSolicitud DESC");
    }

    @GetMapping("/{numero}")
    public Map<String, Object> buscar(@PathVariable("numero") long numero) {
        return Campos.unico(jdbc.queryForList(CONSULTA + " WHERE s.numeroSolicitud = ?", numero),
                "No existe la solicitud " + numero + ".");
    }

    /** Crea la solicitud en estado Creada, con la fecha y hora actuales y sin domiciliario. */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public Map<String, Object> crear(@RequestBody Map<String, Object> datos) {
        DatosSolicitud d = validar(datos);
        long numero = Ids.siguiente(jdbc, "Solicitud", "numeroSolicitud");
        LocalDateTime ahora = LocalDateTime.now(ZONA).withNano(0);

        jdbc.update("""
                INSERT INTO Solicitud (numeroSolicitud, fechaCreacion, horaCreacion, descripcion, montoTotal,
                                       direccionRecogidaExterna, idDireccion, idEstablecimiento, idCliente,
                                       idMetodoPago, idEstadoSolicitud)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                numero, Date.valueOf(ahora.toLocalDate()), Time.valueOf(ahora.toLocalTime()),
                d.descripcion(), d.montoTotal(), d.direccionExterna(), d.idDireccion(),
                d.idEstablecimiento(), d.idCliente(), d.idMetodoPago(), CREADA);
        return buscar(numero);
    }

    /** Edita los datos del pedido (no el estado ni el domiciliario, que tienen sus propias operaciones). */
    @PutMapping("/{numero}")
    @Transactional
    public Map<String, Object> editar(@PathVariable("numero") long numero, @RequestBody Map<String, Object> datos) {
        int estado = numeroComoInt(filaBasica(numero).get("idEstadoSolicitud"));
        if (estado == FINALIZADA || estado == CANCELADA) {
            throw new IllegalArgumentException("No se puede editar una solicitud finalizada o cancelada.");
        }
        DatosSolicitud d = validar(datos);
        jdbc.update("""
                UPDATE Solicitud
                SET descripcion = ?, montoTotal = ?, direccionRecogidaExterna = ?, idDireccion = ?,
                    idEstablecimiento = ?, idCliente = ?, idMetodoPago = ?
                WHERE numeroSolicitud = ?""",
                d.descripcion(), d.montoTotal(), d.direccionExterna(), d.idDireccion(),
                d.idEstablecimiento(), d.idCliente(), d.idMetodoPago(), numero);
        return buscar(numero);
    }

    /** PUT /api/solicitudes/{numero}/asignar  con cuerpo {"idDomiciliario": 1000000013} */
    @PutMapping("/{numero}/asignar")
    @Transactional
    public Map<String, Object> asignar(@PathVariable("numero") long numero, @RequestBody Map<String, Object> datos) {
        long idDomiciliario = Campos.enteroRequerido(datos, "idDomiciliario");
        Map<String, Object> s = filaBasica(numero);
        int estado = numeroComoInt(s.get("idEstadoSolicitud"));

        if (estado != CREADA && estado != ASIGNADA) {
            throw new IllegalArgumentException(
                    "Solo se puede asignar (o reasignar) un domiciliario a solicitudes en estado Creada o Asignada.");
        }
        Integer activo = jdbc.queryForObject(
                "SELECT COUNT(*) FROM Domiciliario WHERE idDomiciliario = ? AND idEstadoDomiciliario = ?",
                Integer.class, idDomiciliario, DOMICILIARIO_ACTIVO);
        if (activo == null || activo == 0) {
            throw new IllegalArgumentException("El domiciliario no existe o está inactivo.");
        }
        if (((Number) s.get("idCliente")).longValue() == idDomiciliario) {
            throw new IllegalArgumentException("Un domiciliario no puede atender su propia solicitud.");
        }
        Integer activas = jdbc.queryForObject("""
                SELECT COUNT(*) FROM Solicitud
                WHERE idDomiciliario = ? AND idEstadoSolicitud IN (?, ?) AND numeroSolicitud <> ?""",
                Integer.class, idDomiciliario, ASIGNADA, EN_CURSO, numero);
        if (activas != null && activas >= MAX_SOLICITUDES_ACTIVAS) {
            throw new IllegalArgumentException(
                    "El domiciliario ya tiene " + MAX_SOLICITUDES_ACTIVAS + " solicitudes activas.");
        }

        LocalDateTime ahora = LocalDateTime.now(ZONA).withNano(0);
        jdbc.update("""
                UPDATE Solicitud
                SET idDomiciliario = ?, fechaAsignacion = ?, horaAsignacion = ?, idEstadoSolicitud = ?
                WHERE numeroSolicitud = ?""",
                idDomiciliario, Date.valueOf(ahora.toLocalDate()), Time.valueOf(ahora.toLocalTime()),
                ASIGNADA, numero);
        return buscar(numero);
    }

    /** PUT /api/solicitudes/{numero}/estado  con cuerpo {"idEstadoSolicitud": 3} */
    @PutMapping("/{numero}/estado")
    @Transactional
    public Map<String, Object> cambiarEstado(@PathVariable("numero") long numero, @RequestBody Map<String, Object> datos) {
        long nuevo = Campos.enteroRequerido(datos, "idEstadoSolicitud");
        Map<String, Object> s = filaBasica(numero);
        int actual = numeroComoInt(s.get("idEstadoSolicitud"));
        boolean tieneDomiciliario = s.get("idDomiciliario") != null;

        if (nuevo < CREADA || nuevo > CANCELADA) {
            throw new IllegalArgumentException("El estado indicado no existe.");
        }
        if (actual == FINALIZADA || actual == CANCELADA) {
            throw new IllegalArgumentException("La solicitud ya está finalizada o cancelada; su estado no se puede cambiar.");
        }
        if (nuevo == actual) {
            throw new IllegalArgumentException("La solicitud ya está en ese estado.");
        }
        if (nuevo == CREADA) {
            throw new IllegalArgumentException("Una solicitud no puede volver al estado Creada.");
        }
        if (nuevo == ASIGNADA) {
            throw new IllegalArgumentException("Para pasar a Asignada use la opción 'Asignar domiciliario'.");
        }
        if ((nuevo == EN_CURSO || nuevo == FINALIZADA) && !tieneDomiciliario) {
            throw new IllegalArgumentException("Primero debe asignar un domiciliario.");
        }
        if (nuevo == FINALIZADA && actual != EN_CURSO) {
            throw new IllegalArgumentException("Solo se puede finalizar una solicitud que está En curso.");
        }

        jdbc.update("UPDATE Solicitud SET idEstadoSolicitud = ? WHERE numeroSolicitud = ?", nuevo, numero);
        return buscar(numero);
    }

    /**
     * Historial de cambios de la solicitud (tabla AuditoriaSolicitud, Entrega 4).
     * Usa el procedimiento almacenado sp_historial_solicitud.
     */
    @GetMapping("/{numero}/historial")
    public List<Map<String, Object>> historial(@PathVariable("numero") long numero) {
        return Filas.normalizar(jdbc.queryForList("CALL sp_historial_solicitud(?)", numero));
    }

    /**
     * Borra primero los incidentes y el historial de auditoría de la solicitud (por sus llaves
     * foráneas) y luego la solicitud.
     */
    @DeleteMapping("/{numero}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Transactional
    public void eliminar(@PathVariable("numero") long numero) {
        jdbc.update("DELETE FROM Incidente WHERE numeroSolicitud = ?", numero);
        if (Filas.existeTabla(jdbc, "AuditoriaSolicitud")) {
            jdbc.update("DELETE FROM AuditoriaSolicitud WHERE numeroSolicitud = ?", numero);
        }
        if (jdbc.update("DELETE FROM Solicitud WHERE numeroSolicitud = ?", numero) == 0) {
            throw new NoEncontradoException("No existe la solicitud " + numero + ".");
        }
    }

    // ----------------------------------------------------------------------------------------

    private record DatosSolicitud(long idCliente, long idDireccion, Long idEstablecimiento,
                                  String direccionExterna, String descripcion, BigDecimal montoTotal,
                                  long idMetodoPago) { }

    /** Lee los datos del pedido y verifica las reglas 1 y 2. */
    private DatosSolicitud validar(Map<String, Object> datos) {
        long idCliente = Campos.enteroRequerido(datos, "idCliente");
        long idDireccion = Campos.enteroRequerido(datos, "idDireccion");
        Long idEstablecimiento = Campos.entero(datos, "idEstablecimiento");
        String externa = Campos.texto(datos, "direccionRecogidaExterna");
        String descripcion = Campos.textoRequerido(datos, "descripcion");
        BigDecimal monto = Campos.decimalRequerido(datos, "montoTotal");
        long idMetodoPago = Campos.enteroRequerido(datos, "idMetodoPago");

        // Regla 1: un único lugar de recogida
        if (idEstablecimiento == null && externa == null) {
            throw new IllegalArgumentException(
                    "Indique el lugar de recogida: un establecimiento aliado o una dirección externa.");
        }
        if (idEstablecimiento != null && externa != null) {
            throw new IllegalArgumentException(
                    "La solicitud no puede tener a la vez un establecimiento y una dirección externa de recogida.");
        }
        if (monto.signum() <= 0) {
            throw new IllegalArgumentException("El monto total debe ser mayor que 0.");
        }

        // Regla 2: la dirección de entrega pertenece al cliente
        Integer coincide = jdbc.queryForObject(
                "SELECT COUNT(*) FROM Direccion WHERE idDireccion = ? AND idCliente = ?",
                Integer.class, idDireccion, idCliente);
        if (coincide == null || coincide == 0) {
            throw new IllegalArgumentException(
                    "La dirección de entrega debe ser una de las direcciones registradas por el cliente.");
        }

        return new DatosSolicitud(idCliente, idDireccion, idEstablecimiento, externa,
                descripcion, monto, idMetodoPago);
    }

    private Map<String, Object> filaBasica(long numero) {
        return Campos.unico(jdbc.queryForList(
                "SELECT idCliente, idDomiciliario, idEstadoSolicitud FROM Solicitud WHERE numeroSolicitud = ?", numero),
                "No existe la solicitud " + numero + ".");
    }

    private static int numeroComoInt(Object valor) {
        return ((Number) valor).intValue();
    }
}
