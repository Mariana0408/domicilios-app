package co.edu.uao.domicilios.soporte;

import org.springframework.jdbc.core.JdbcTemplate;

/**
 * Las llaves primarias del script no son AUTO_INCREMENT, así que el siguiente
 * código se calcula como MAX + 1 (por ejemplo, la siguiente solicitud después de 1020 es 1021).
 */
public final class Ids {

    private Ids() { }

    /** tabla y columna siempre son constantes escritas en el código, nunca datos del usuario. */
    public static long siguiente(JdbcTemplate jdbc, String tabla, String columna) {
        Long siguiente = jdbc.queryForObject(
                "SELECT COALESCE(MAX(" + columna + "), 0) + 1 FROM " + tabla, Long.class);
        return siguiente == null ? 1 : siguiente;
    }
}
