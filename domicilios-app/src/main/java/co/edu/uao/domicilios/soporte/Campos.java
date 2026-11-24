package co.edu.uao.domicilios.soporte;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.format.DateTimeParseException;
import java.util.List;
import java.util.Map;

/**
 * Utilidades para leer los datos que llegan en el JSON de cada petición
 * y convertirlos al tipo que espera cada columna de MySQL.
 * Si un dato falta o tiene mal formato se lanza IllegalArgumentException,
 * que ManejadorErrores convierte en una respuesta 400 con un mensaje claro.
 */
public final class Campos {

    private Campos() { }

    /** Texto opcional: devuelve null si no viene o viene vacío. */
    public static String texto(Map<String, Object> datos, String campo) {
        Object valor = datos.get(campo);
        if (valor == null) {
            return null;
        }
        String s = valor.toString().trim();
        return s.isEmpty() ? null : s;
    }

    /** Texto obligatorio (columnas NOT NULL). */
    public static String textoRequerido(Map<String, Object> datos, String campo) {
        String s = texto(datos, campo);
        if (s == null) {
            throw new IllegalArgumentException("El campo '" + campo + "' es obligatorio.");
        }
        return s;
    }

    /** Número entero opcional (por ejemplo una llave foránea que admite NULL). */
    public static Long entero(Map<String, Object> datos, String campo) {
        Object valor = datos.get(campo);
        if (valor instanceof Number n) {
            return n.longValue();
        }
        String s = texto(datos, campo);
        if (s == null) {
            return null;
        }
        try {
            return Long.valueOf(s);
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException("El campo '" + campo + "' debe ser un número entero.");
        }
    }

    /** Número entero obligatorio. */
    public static long enteroRequerido(Map<String, Object> datos, String campo) {
        Long n = entero(datos, campo);
        if (n == null) {
            throw new IllegalArgumentException("El campo '" + campo + "' es obligatorio.");
        }
        return n;
    }

    /** Número decimal obligatorio (por ejemplo montoTotal DECIMAL(10,2)). */
    public static BigDecimal decimalRequerido(Map<String, Object> datos, String campo) {
        String s = textoRequerido(datos, campo);
        try {
            return new BigDecimal(s);
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException("El campo '" + campo + "' debe ser un número.");
        }
    }

    /** Fecha opcional con formato AAAA-MM-DD. */
    public static LocalDate fecha(Map<String, Object> datos, String campo) {
        String s = texto(datos, campo);
        if (s == null) {
            return null;
        }
        try {
            return LocalDate.parse(s);
        } catch (DateTimeParseException e) {
            throw new IllegalArgumentException("El campo '" + campo + "' debe tener formato AAAA-MM-DD.");
        }
    }

    /** Hora opcional con formato HH:MM o HH:MM:SS. */
    public static LocalTime hora(Map<String, Object> datos, String campo) {
        String s = texto(datos, campo);
        if (s == null) {
            return null;
        }
        try {
            return LocalTime.parse(s);
        } catch (DateTimeParseException e) {
            throw new IllegalArgumentException("El campo '" + campo + "' debe tener formato HH:MM.");
        }
    }

    /** Devuelve el único registro de una consulta o responde 404 si no hay ninguno. */
    public static Map<String, Object> unico(List<Map<String, Object>> filas, String mensajeSiNoExiste) {
        if (filas.isEmpty()) {
            throw new NoEncontradoException(mensajeSiNoExiste);
        }
        return filas.get(0);
    }
}
