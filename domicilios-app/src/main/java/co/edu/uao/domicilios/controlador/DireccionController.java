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
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import co.edu.uao.domicilios.soporte.Campos;
import co.edu.uao.domicilios.soporte.Ids;
import co.edu.uao.domicilios.soporte.NoEncontradoException;

/** CRUD de direcciones de entrega. Cada cliente puede tener una o varias. */
@RestController
@RequestMapping("/api/direcciones")
public class DireccionController {

    private static final String CONSULTA = """
            SELECT d.idDireccion, d.ubicacion, d.referencia,
                   d.idBarrio, b.nombreBarrio, c.nombreComuna,
                   d.idCliente, CONCAT(u.nombre, ' ', u.apellido_Paterno) AS nombreCliente
            FROM Direccion d
            INNER JOIN Barrio b ON b.idBarrio = d.idBarrio
            INNER JOIN Comuna c ON c.idComuna = b.idComuna
            INNER JOIN Usuario u ON u.numeroIdentificacion = d.idCliente
            """;

    private final JdbcTemplate jdbc;

    public DireccionController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** GET /api/direcciones o GET /api/direcciones?cliente=1000000001 (solo las de ese cliente). */
    @GetMapping
    public List<Map<String, Object>> listar(@RequestParam(name = "cliente", required = false) Long cliente) {
        if (cliente != null) {
            return jdbc.queryForList(CONSULTA + " WHERE d.idCliente = ? ORDER BY d.idDireccion", cliente);
        }
        return jdbc.queryForList(CONSULTA + " ORDER BY d.idDireccion");
    }

    @GetMapping("/{id}")
    public Map<String, Object> buscar(@PathVariable("id") long id) {
        return Campos.unico(jdbc.queryForList(CONSULTA + " WHERE d.idDireccion = ?", id),
                "No existe la dirección " + id + ".");
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public Map<String, Object> crear(@RequestBody Map<String, Object> datos) {
        long id = Ids.siguiente(jdbc, "Direccion", "idDireccion");
        jdbc.update("""
                INSERT INTO Direccion (idDireccion, ubicacion, referencia, idBarrio, idCliente)
                VALUES (?, ?, ?, ?, ?)""",
                id,
                Campos.textoRequerido(datos, "ubicacion"),
                Campos.texto(datos, "referencia"),
                Campos.enteroRequerido(datos, "idBarrio"),
                Campos.enteroRequerido(datos, "idCliente"));
        return buscar(id);
    }

    @PutMapping("/{id}")
    @Transactional
    public Map<String, Object> editar(@PathVariable("id") long id, @RequestBody Map<String, Object> datos) {
        buscar(id);
        jdbc.update("""
                UPDATE Direccion
                SET ubicacion = ?, referencia = ?, idBarrio = ?, idCliente = ?
                WHERE idDireccion = ?""",
                Campos.textoRequerido(datos, "ubicacion"),
                Campos.texto(datos, "referencia"),
                Campos.enteroRequerido(datos, "idBarrio"),
                Campos.enteroRequerido(datos, "idCliente"),
                id);
        return buscar(id);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void eliminar(@PathVariable("id") long id) {
        if (jdbc.update("DELETE FROM Direccion WHERE idDireccion = ?", id) == 0) {
            throw new NoEncontradoException("No existe la dirección " + id + ".");
        }
    }
}
