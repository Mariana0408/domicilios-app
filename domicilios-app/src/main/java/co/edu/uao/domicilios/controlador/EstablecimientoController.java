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

/** CRUD de establecimientos aliados. */
@RestController
@RequestMapping("/api/establecimientos")
public class EstablecimientoController {

    private static final String CONSULTA = """
            SELECT e.idEstablecimiento, e.nombreComercial, e.ubicacion, e.telefono, e.email,
                   e.idTipoEstablecimiento, t.nombreTipoEstablecimiento,
                   e.idBarrio, b.nombreBarrio, c.nombreComuna
            FROM Establecimiento e
            INNER JOIN TipoEstablecimiento t ON t.idTipoEstablecimiento = e.idTipoEstablecimiento
            INNER JOIN Barrio b ON b.idBarrio = e.idBarrio
            INNER JOIN Comuna c ON c.idComuna = b.idComuna
            """;

    private final JdbcTemplate jdbc;

    public EstablecimientoController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping
    public List<Map<String, Object>> listar() {
        return jdbc.queryForList(CONSULTA + " ORDER BY e.idEstablecimiento");
    }

    @GetMapping("/{id}")
    public Map<String, Object> buscar(@PathVariable("id") long id) {
        return Campos.unico(jdbc.queryForList(CONSULTA + " WHERE e.idEstablecimiento = ?", id),
                "No existe el establecimiento " + id + ".");
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public Map<String, Object> crear(@RequestBody Map<String, Object> datos) {
        long id = Ids.siguiente(jdbc, "Establecimiento", "idEstablecimiento");
        jdbc.update("""
                INSERT INTO Establecimiento (idEstablecimiento, nombreComercial, ubicacion, telefono, email,
                                             idTipoEstablecimiento, idBarrio)
                VALUES (?, ?, ?, ?, ?, ?, ?)""",
                id,
                Campos.textoRequerido(datos, "nombreComercial"),
                Campos.textoRequerido(datos, "ubicacion"),
                Campos.textoRequerido(datos, "telefono"),
                Campos.texto(datos, "email"),
                Campos.enteroRequerido(datos, "idTipoEstablecimiento"),
                Campos.enteroRequerido(datos, "idBarrio"));
        return buscar(id);
    }

    @PutMapping("/{id}")
    @Transactional
    public Map<String, Object> editar(@PathVariable("id") long id, @RequestBody Map<String, Object> datos) {
        buscar(id);
        jdbc.update("""
                UPDATE Establecimiento
                SET nombreComercial = ?, ubicacion = ?, telefono = ?, email = ?,
                    idTipoEstablecimiento = ?, idBarrio = ?
                WHERE idEstablecimiento = ?""",
                Campos.textoRequerido(datos, "nombreComercial"),
                Campos.textoRequerido(datos, "ubicacion"),
                Campos.textoRequerido(datos, "telefono"),
                Campos.texto(datos, "email"),
                Campos.enteroRequerido(datos, "idTipoEstablecimiento"),
                Campos.enteroRequerido(datos, "idBarrio"),
                id);
        return buscar(id);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void eliminar(@PathVariable("id") long id) {
        if (jdbc.update("DELETE FROM Establecimiento WHERE idEstablecimiento = ?", id) == 0) {
            throw new NoEncontradoException("No existe el establecimiento " + id + ".");
        }
    }
}
