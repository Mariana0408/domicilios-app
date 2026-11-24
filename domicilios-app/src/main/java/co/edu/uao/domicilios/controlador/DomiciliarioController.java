package co.edu.uao.domicilios.controlador;

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
import co.edu.uao.domicilios.soporte.Ids;
import co.edu.uao.domicilios.soporte.NoEncontradoException;
import co.edu.uao.domicilios.soporte.Usuarios;

/** CRUD de domiciliarios: tablas Usuario + Domiciliario (con su estado y medio de transporte). */
@RestController
@RequestMapping("/api/domiciliarios")
public class DomiciliarioController {

    private static final String CONSULTA = """
            SELECT d.idDomiciliario AS numeroIdentificacion, d.codigoUnico,
                   u.nombre, u.apellido_Paterno, u.apellido_Materno, u.numeroTelefono, u.correoElectronico,
                   d.idEstadoDomiciliario, ed.nombreEstadoDomiciliario,
                   d.idMedioTransporte, mt.nombreMedioTransporte
            FROM Domiciliario d
            INNER JOIN Usuario u ON u.numeroIdentificacion = d.idDomiciliario
            INNER JOIN EstadoDomiciliario ed ON ed.idEstadoDomiciliario = d.idEstadoDomiciliario
            INNER JOIN MedioTransporte mt ON mt.idMedioTransporte = d.idMedioTransporte
            """;

    private final JdbcTemplate jdbc;
    private final Usuarios usuarios;

    public DomiciliarioController(JdbcTemplate jdbc, Usuarios usuarios) {
        this.jdbc = jdbc;
        this.usuarios = usuarios;
    }

    @GetMapping
    public List<Map<String, Object>> listar() {
        return jdbc.queryForList(CONSULTA + " ORDER BY d.codigoUnico");
    }

    @GetMapping("/{id}")
    public Map<String, Object> buscar(@PathVariable("id") long id) {
        return Campos.unico(jdbc.queryForList(CONSULTA + " WHERE d.idDomiciliario = ?", id),
                "No existe el domiciliario " + id + ".");
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public Map<String, Object> crear(@RequestBody Map<String, Object> datos) {
        long id = Campos.enteroRequerido(datos, "numeroIdentificacion");
        Long codigo = Campos.entero(datos, "codigoUnico");
        if (codigo == null) {
            codigo = Ids.siguiente(jdbc, "Domiciliario", "codigoUnico");
        }
        long idEstado = Campos.enteroRequerido(datos, "idEstadoDomiciliario");
        long idMedio = Campos.enteroRequerido(datos, "idMedioTransporte");

        usuarios.guardar(id, datos);
        jdbc.update("""
                INSERT INTO Domiciliario (idDomiciliario, codigoUnico, idEstadoDomiciliario, idMedioTransporte)
                VALUES (?, ?, ?, ?)""", id, codigo, idEstado, idMedio);
        return buscar(id);
    }

    @PutMapping("/{id}")
    @Transactional
    public Map<String, Object> editar(@PathVariable("id") long id, @RequestBody Map<String, Object> datos) {
        buscar(id);
        Long codigo = Campos.entero(datos, "codigoUnico");
        long idEstado = Campos.enteroRequerido(datos, "idEstadoDomiciliario");
        long idMedio = Campos.enteroRequerido(datos, "idMedioTransporte");

        usuarios.guardar(id, datos);
        jdbc.update("""
                UPDATE Domiciliario
                SET codigoUnico = COALESCE(?, codigoUnico), idEstadoDomiciliario = ?, idMedioTransporte = ?
                WHERE idDomiciliario = ?""", codigo, idEstado, idMedio, id);
        return buscar(id);
    }

    /** Si el domiciliario ya atendió solicitudes, MySQL bloquea el borrado (409). Mejor marcarlo Inactivo. */
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Transactional
    public void eliminar(@PathVariable("id") long id) {
        if (jdbc.update("DELETE FROM Domiciliario WHERE idDomiciliario = ?", id) == 0) {
            throw new NoEncontradoException("No existe el domiciliario " + id + ".");
        }
        usuarios.eliminarSiNoTieneRol(id);
    }
}
