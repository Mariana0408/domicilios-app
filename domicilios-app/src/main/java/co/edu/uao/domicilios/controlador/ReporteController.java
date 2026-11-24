package co.edu.uao.domicilios.controlador;

import java.sql.Date;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import co.edu.uao.domicilios.soporte.Filas;

/**
 * Reportes del sistema. Usan los objetos procedimentales creados en MySQL
 * (scripts 02_Entrega3_LenguajeProcedimental.sql y 03_Entrega4_Backend.sql):
 * procedimientos almacenados, el cursor, funciones y vistas.
 */
@RestController
@RequestMapping("/api/reportes")
public class ReporteController {

    private final JdbcTemplate jdbc;

    public ReporteController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** Procedimiento sp_solicitudes_por_fecha (consulta con JOIN). Ej: ?fecha=2026-10-04 */
    @GetMapping("/solicitudes-por-fecha")
    public List<Map<String, Object>> solicitudesPorFecha(@RequestParam(name = "fecha") String fecha) {
        return Filas.normalizar(jdbc.queryForList("CALL sp_solicitudes_por_fecha(?)", fecha(fecha, "fecha")));
    }

    /** Procedimiento sp_resumen_domiciliario (usa las funciones de la Entrega 3). */
    @GetMapping("/resumen-domiciliario/{id}")
    public List<Map<String, Object>> resumenDomiciliario(@PathVariable("id") long id) {
        return Filas.normalizar(jdbc.queryForList("CALL sp_resumen_domiciliario(?)", id));
    }

    /** Procedimiento con cursor sp_reporte_desempeno_domiciliarios. */
    @GetMapping("/desempeno-domiciliarios")
    public List<Map<String, Object>> desempenoDomiciliarios() {
        return Filas.normalizar(jdbc.queryForList("CALL sp_reporte_desempeno_domiciliarios()"));
    }

    /** Procedimiento sp_reporte_establecimientos. Ej: ?inicio=2026-09-01&fin=2026-12-31 */
    @GetMapping("/establecimientos")
    public List<Map<String, Object>> establecimientos(@RequestParam(name = "inicio") String inicio,
                                                      @RequestParam(name = "fin") String fin) {
        return Filas.normalizar(jdbc.queryForList("CALL sp_reporte_establecimientos(?, ?)",
                fecha(inicio, "inicio"), fecha(fin, "fin")));
    }

    /** Vista vw_solicitudes_detalle. */
    @GetMapping("/solicitudes-detalle")
    public List<Map<String, Object>> solicitudesDetalle() {
        return Filas.normalizar(jdbc.queryForList(
                "SELECT * FROM vw_solicitudes_detalle ORDER BY numeroSolicitud DESC"));
    }

    /** Vista vw_domiciliarios_disponibles (activos y con menos de 2 solicitudes activas). */
    @GetMapping("/domiciliarios-disponibles")
    public List<Map<String, Object>> domiciliariosDisponibles() {
        return Filas.normalizar(jdbc.queryForList(
                "SELECT * FROM vw_domiciliarios_disponibles ORDER BY codigoUnico"));
    }

    /** Vista vw_resumen_clientes. */
    @GetMapping("/clientes")
    public List<Map<String, Object>> resumenClientes() {
        return Filas.normalizar(jdbc.queryForList(
                "SELECT * FROM vw_resumen_clientes ORDER BY total_pagado DESC"));
    }

    /** Tabla AuditoriaSolicitud (historial de todas las solicitudes, la más reciente primero). */
    @GetMapping("/auditoria")
    public List<Map<String, Object>> auditoria() {
        return Filas.normalizar(jdbc.queryForList("""
                SELECT a.idAuditoria, a.numeroSolicitud, a.accion, a.estadoAnterior, a.estadoNuevo,
                       fn_nombre_completo(a.domiciliarioAnterior) AS domiciliario_anterior,
                       fn_nombre_completo(a.domiciliarioNuevo) AS domiciliario_nuevo,
                       a.usuarioBD, a.fechaCambio
                FROM AuditoriaSolicitud a
                ORDER BY a.idAuditoria DESC"""));
    }

    private static Date fecha(String valor, String nombre) {
        try {
            return Date.valueOf(LocalDate.parse(valor.trim()));
        } catch (DateTimeParseException | NullPointerException e) {
            throw new IllegalArgumentException("El parámetro '" + nombre + "' debe tener formato AAAA-MM-DD.");
        }
    }
}
