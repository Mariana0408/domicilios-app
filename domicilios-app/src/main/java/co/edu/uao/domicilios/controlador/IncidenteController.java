package co.edu.uao.domicilios.controlador;

import java.sql.Date;
import java.sql.Time;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
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
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import co.edu.uao.domicilios.soporte.Campos;
import co.edu.uao.domicilios.soporte.Ids;
import co.edu.uao.domicilios.soporte.NoEncontradoException;

/** Incidentes asociados a una solicitud (una solicitud puede tener ninguno, uno o varios). */
@RestController
@RequestMapping("/api/incidentes")
public class IncidenteController {

    private static final ZoneId ZONA = ZoneId.of("America/Bogota");

    private static final String CONSULTA = """
            SELECT i.codigoIncidente, i.descripcion,
                   DATE_FORMAT(i.fechaIncidente, '%Y-%m-%d') AS fechaIncidente,
                   TIME_FORMAT(i.horaIncidente, '%H:%i') AS horaIncidente,
                   i.idTipoIncidente, t.nombreTipoIncidente,
                   i.numeroSolicitud, s.descripcion AS descripcionSolicitud
            FROM Incidente i
            INNER JOIN TipoIncidente t ON t.idTipoIncidente = i.idTipoIncidente
            INNER JOIN Solicitud s ON s.numeroSolicitud = i.numeroSolicitud
            """;

    private final JdbcTemplate jdbc;

    public IncidenteController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** GET /api/incidentes o GET /api/incidentes?solicitud=1005 */
    @GetMapping
    public List<Map<String, Object>> listar(@RequestParam(name = "solicitud", required = false) Long solicitud) {
        if (solicitud != null) {
            return jdbc.queryForList(CONSULTA + " WHERE i.numeroSolicitud = ? ORDER BY i.codigoIncidente", solicitud);
        }
        return jdbc.queryForList(CONSULTA + " ORDER BY i.codigoIncidente DESC");
    }

    @GetMapping("/{codigo}")
    public Map<String, Object> buscar(@PathVariable("codigo") long codigo) {
        return Campos.unico(jdbc.queryForList(CONSULTA + " WHERE i.codigoIncidente = ?", codigo),
                "No existe el incidente " + codigo + ".");
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public Map<String, Object> crear(@RequestBody Map<String, Object> datos) {
        long codigo = Ids.siguiente(jdbc, "Incidente", "codigoIncidente");
        guardar(codigo, datos, true);
        return buscar(codigo);
    }

    @PutMapping("/{codigo}")
    @Transactional
    public Map<String, Object> editar(@PathVariable("codigo") long codigo, @RequestBody Map<String, Object> datos) {
        buscar(codigo);
        guardar(codigo, datos, false);
        return buscar(codigo);
    }

    @DeleteMapping("/{codigo}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void eliminar(@PathVariable("codigo") long codigo) {
        if (jdbc.update("DELETE FROM Incidente WHERE codigoIncidente = ?", codigo) == 0) {
            throw new NoEncontradoException("No existe el incidente " + codigo + ".");
        }
    }

    /** Si no se envían fecha u hora, se usa el momento actual. */
    private void guardar(long codigo, Map<String, Object> datos, boolean nuevo) {
        long numeroSolicitud = Campos.enteroRequerido(datos, "numeroSolicitud");
        long idTipo = Campos.enteroRequerido(datos, "idTipoIncidente");
        String descripcion = Campos.textoRequerido(datos, "descripcion");

        LocalDateTime ahora = LocalDateTime.now(ZONA).withNano(0);
        LocalDate fecha = Campos.fecha(datos, "fechaIncidente");
        LocalTime hora = Campos.hora(datos, "horaIncidente");
        Date fechaSql = Date.valueOf(fecha != null ? fecha : ahora.toLocalDate());
        Time horaSql = Time.valueOf(hora != null ? hora : ahora.toLocalTime());

        Integer existe = jdbc.queryForObject(
                "SELECT COUNT(*) FROM Solicitud WHERE numeroSolicitud = ?", Integer.class, numeroSolicitud);
        if (existe == null || existe == 0) {
            throw new IllegalArgumentException("No existe la solicitud " + numeroSolicitud + ".");
        }
        // Un incidente no puede ocurrir antes de que se creara la solicitud
        Integer valido = jdbc.queryForObject("""
                SELECT COUNT(*) FROM Solicitud
                WHERE numeroSolicitud = ?
                  AND TIMESTAMP(fechaCreacion, horaCreacion) <= TIMESTAMP(?, ?)""",
                Integer.class, numeroSolicitud, fechaSql, horaSql);
        if (valido == null || valido == 0) {
            throw new IllegalArgumentException("El incidente no puede ser anterior a la creación de la solicitud.");
        }

        if (nuevo) {
            jdbc.update("""
                    INSERT INTO Incidente (codigoIncidente, descripcion, fechaIncidente, horaIncidente,
                                           idTipoIncidente, numeroSolicitud)
                    VALUES (?, ?, ?, ?, ?, ?)""",
                    codigo, descripcion, fechaSql, horaSql, idTipo, numeroSolicitud);
        } else {
            jdbc.update("""
                    UPDATE Incidente
                    SET descripcion = ?, fechaIncidente = ?, horaIncidente = ?,
                        idTipoIncidente = ?, numeroSolicitud = ?
                    WHERE codigoIncidente = ?""",
                    descripcion, fechaSql, horaSql, idTipo, numeroSolicitud, codigo);
        }
    }
}
