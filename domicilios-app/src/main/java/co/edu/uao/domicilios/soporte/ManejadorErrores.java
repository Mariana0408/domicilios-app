package co.edu.uao.domicilios.soporte;

import java.sql.SQLException;
import java.util.Map;
import java.util.Objects;

import org.springframework.dao.DataAccessException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * Convierte los errores en respuestas JSON del tipo {"error": "mensaje"}.
 * La interfaz gráfica y Postman muestran ese mensaje.
 */
@RestControllerAdvice
public class ManejadorErrores {

    /** Código SQLSTATE que usan los triggers y procedimientos (SIGNAL SQLSTATE '45000'). */
    private static final String SQLSTATE_REGLA_NEGOCIO = "45000";
    /** Errores de MySQL cuando falta un procedimiento (1305) o una tabla/vista (1146). */
    private static final int MYSQL_NO_EXISTE_RUTINA = 1305;
    private static final int MYSQL_NO_EXISTE_TABLA = 1146;

    /** Datos inválidos o reglas de negocio incumplidas → 400 Bad Request. */
    @ExceptionHandler(IllegalArgumentException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public Map<String, String> datosInvalidos(IllegalArgumentException e) {
        return Map.of("error", e.getMessage());
    }

    /** JSON mal escrito → 400. */
    @ExceptionHandler(HttpMessageNotReadableException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public Map<String, String> jsonInvalido(HttpMessageNotReadableException e) {
        return Map.of("error", "El cuerpo de la petición no es un JSON válido.");
    }

    /** Registro inexistente → 404 Not Found. */
    @ExceptionHandler(NoEncontradoException.class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    public Map<String, String> noEncontrado(NoEncontradoException e) {
        return Map.of("error", e.getMessage());
    }

    /**
     * Errores que vienen de MySQL:
     *  - SIGNAL '45000' de un trigger o procedimiento (Entregas 3 y 4) → 400 con el mensaje del trigger.
     *  - Falta un procedimiento o una vista → 500 indicando qué script ejecutar.
     *  - Restricción PK, FK, UNIQUE o NOT NULL → 409 Conflict.
     *  - Cualquier otro (por ejemplo MySQL apagado) → 500.
     */
    @ExceptionHandler(DataAccessException.class)
    public ResponseEntity<Map<String, String>> baseDeDatos(DataAccessException e) {
        Throwable causa = e.getMostSpecificCause();
        String mensajeMysql = Objects.toString(causa.getMessage(), "");

        if (causa instanceof SQLException sql) {
            if (SQLSTATE_REGLA_NEGOCIO.equals(sql.getSQLState())) {
                return respuesta(HttpStatus.BAD_REQUEST, mensajeMysql);
            }
            if (sql.getErrorCode() == MYSQL_NO_EXISTE_RUTINA || sql.getErrorCode() == MYSQL_NO_EXISTE_TABLA) {
                return respuesta(HttpStatus.INTERNAL_SERVER_ERROR,
                        "Faltan objetos en MySQL: ejecute 02_Entrega3_LenguajeProcedimental.sql y "
                        + "03_Entrega4_Backend.sql. Detalle: " + mensajeMysql);
            }
        }
        if (e instanceof DataIntegrityViolationException) {
            return respuesta(HttpStatus.CONFLICT, traducir(mensajeMysql));
        }
        return respuesta(HttpStatus.INTERNAL_SERVER_ERROR, "Error de base de datos: " + mensajeMysql);
    }

    private static ResponseEntity<Map<String, String>> respuesta(HttpStatus estado, String mensaje) {
        return ResponseEntity.status(estado).body(Map.of("error", mensaje));
    }

    private static String traducir(String mensajeMysql) {
        if (mensajeMysql.contains("Cannot delete or update a parent row")) {
            return "No se puede eliminar porque tiene registros asociados (por ejemplo direcciones, solicitudes o incidentes).";
        }
        if (mensajeMysql.contains("Cannot add or update a child row")) {
            return "Uno de los valores seleccionados no existe en la base de datos (llave foránea inválida).";
        }
        if (mensajeMysql.contains("Duplicate entry")) {
            return "Ya existe un registro con ese identificador o código.";
        }
        if (mensajeMysql.contains("Data too long")) {
            return "Uno de los textos supera la longitud permitida.";
        }
        if (mensajeMysql.contains("Out of range")) {
            return "Un número está fuera del rango permitido.";
        }
        return "La base de datos rechazó la operación: " + mensajeMysql;
    }
}
