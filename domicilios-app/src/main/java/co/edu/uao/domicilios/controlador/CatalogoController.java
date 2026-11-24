package co.edu.uao.domicilios.controlador;

import java.util.LinkedHashMap;
import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Devuelve todas las tablas catálogo (barrios, tipos, estados, métodos de pago...)
 * en una sola llamada. La interfaz las usa para llenar las listas desplegables.
 * Cada elemento tiene la forma {"id": ..., "nombre": ...}.
 */
@RestController
@RequestMapping("/api/catalogos")
public class CatalogoController {

    private final JdbcTemplate jdbc;

    public CatalogoController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping
    public Map<String, Object> todos() {
        Map<String, Object> r = new LinkedHashMap<>();
        r.put("barrios", jdbc.queryForList("""
                SELECT b.idBarrio AS id, CONCAT(b.nombreBarrio, ' (', c.nombreComuna, ')') AS nombre
                FROM Barrio b
                INNER JOIN Comuna c ON c.idComuna = b.idComuna
                ORDER BY b.nombreBarrio"""));
        r.put("tiposEstablecimiento", jdbc.queryForList(
                "SELECT idTipoEstablecimiento AS id, nombreTipoEstablecimiento AS nombre FROM TipoEstablecimiento ORDER BY id"));
        r.put("metodosPago", jdbc.queryForList(
                "SELECT idMetodoPago AS id, nombreMetodo AS nombre FROM MetodoPago ORDER BY id"));
        r.put("estadosSolicitud", jdbc.queryForList(
                "SELECT idEstadoSolicitud AS id, nombreEstadoSolicitud AS nombre FROM EstadoSolicitud ORDER BY id"));
        r.put("estadosDomiciliario", jdbc.queryForList(
                "SELECT idEstadoDomiciliario AS id, nombreEstadoDomiciliario AS nombre FROM EstadoDomiciliario ORDER BY id"));
        r.put("mediosTransporte", jdbc.queryForList(
                "SELECT idMedioTransporte AS id, nombreMedioTransporte AS nombre FROM MedioTransporte ORDER BY id"));
        r.put("tiposIncidente", jdbc.queryForList(
                "SELECT idTipoIncidente AS id, nombreTipoIncidente AS nombre FROM TipoIncidente ORDER BY id"));
        return r;
    }
}
