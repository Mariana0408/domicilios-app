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
import co.edu.uao.domicilios.soporte.NoEncontradoException;
import co.edu.uao.domicilios.soporte.Usuarios;

/** CRUD de clientes: tablas Usuario + Cliente. */
@RestController
@RequestMapping("/api/clientes")
public class ClienteController {

    private static final String CONSULTA = """
            SELECT u.numeroIdentificacion, u.nombre, u.apellido_Paterno, u.apellido_Materno,
                   u.numeroTelefono, u.correoElectronico
            FROM Cliente c
            INNER JOIN Usuario u ON u.numeroIdentificacion = c.idCliente
            """;

    private final JdbcTemplate jdbc;
    private final Usuarios usuarios;

    public ClienteController(JdbcTemplate jdbc, Usuarios usuarios) {
        this.jdbc = jdbc;
        this.usuarios = usuarios;
    }

    @GetMapping
    public List<Map<String, Object>> listar() {
        return jdbc.queryForList(CONSULTA + " ORDER BY u.nombre, u.apellido_Paterno");
    }

    @GetMapping("/{id}")
    public Map<String, Object> buscar(@PathVariable("id") long id) {
        return Campos.unico(jdbc.queryForList(CONSULTA + " WHERE c.idCliente = ?", id),
                "No existe el cliente " + id + ".");
    }

    /** Inserta en Usuario y luego en Cliente, dentro de una transacción (o se guardan ambos o ninguno). */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public Map<String, Object> crear(@RequestBody Map<String, Object> datos) {
        long id = Campos.enteroRequerido(datos, "numeroIdentificacion");
        usuarios.guardar(id, datos);
        jdbc.update("INSERT INTO Cliente (idCliente) VALUES (?)", id);
        return buscar(id);
    }

    @PutMapping("/{id}")
    @Transactional
    public Map<String, Object> editar(@PathVariable("id") long id, @RequestBody Map<String, Object> datos) {
        buscar(id); // 404 si no existe
        usuarios.guardar(id, datos);
        return buscar(id);
    }

    /** Si el cliente tiene direcciones o solicitudes, MySQL bloquea el borrado por la llave foránea (409). */
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Transactional
    public void eliminar(@PathVariable("id") long id) {
        if (jdbc.update("DELETE FROM Cliente WHERE idCliente = ?", id) == 0) {
            throw new NoEncontradoException("No existe el cliente " + id + ".");
        }
        usuarios.eliminarSiNoTieneRol(id);
    }
}
