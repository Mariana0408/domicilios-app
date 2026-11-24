package co.edu.uao.domicilios.soporte;

import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;

/**
 * Utilidades para los resultados de vistas y procedimientos (reportes).
 * Convierte fechas y horas a texto legible (AAAA-MM-DD, HH:MM:SS) para que
 * el JSON muestre lo mismo que MySQL Workbench.
 */
public final class Filas {

    private Filas() { }

    public static List<Map<String, Object>> normalizar(List<Map<String, Object>> filas) {
        List<Map<String, Object>> resultado = new ArrayList<>();
        for (Map<String, Object> fila : filas) {
            Map<String, Object> nueva = new LinkedHashMap<>();
            for (Map.Entry<String, Object> campo : fila.entrySet()) {
                nueva.put(campo.getKey(), comoTexto(campo.getValue()));
            }
            resultado.add(nueva);
        }
        return resultado;
    }

    private static Object comoTexto(Object valor) {
        if (valor instanceof Timestamp t) {
            return t.toLocalDateTime().toString().replace('T', ' ');
        }
        if (valor instanceof LocalDateTime t) {
            return t.toString().replace('T', ' ');
        }
        if (valor instanceof java.sql.Date || valor instanceof java.sql.Time
                || valor instanceof java.time.LocalDate || valor instanceof java.time.LocalTime) {
            return valor.toString();
        }
        return valor;
    }

    /** Indica si existe una tabla en la base de datos actual (sin importar mayúsculas). */
    public static boolean existeTabla(JdbcTemplate jdbc, String tabla) {
        Integer n = jdbc.queryForObject("""
                SELECT COUNT(*) FROM information_schema.TABLES
                WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER(?)""",
                Integer.class, tabla);
        return n != null && n > 0;
    }
}
