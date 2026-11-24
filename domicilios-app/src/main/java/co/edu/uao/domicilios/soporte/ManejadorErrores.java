package co.edu.uao.domicilios.soporte;

import java.util.Map;
import java.util.Objects;

import org.springframework.dao.DataAccessException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
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

    /** MySQL rechazó la operación por una restricción (PK, FK, UNIQUE, NOT NULL) → 409 Conflict. */
    @ExceptionHandler(DataIntegrityViolationException.class)
    @ResponseStatus(HttpStatus.CONFLICT)
    public Map<String, String> integridad(DataIntegrityViolationException e) {
        String mensajeMysql = Objects.toString(e.getMostSpecificCause().getMessage(), "");
        return Map.of("error", traducir(mensajeMysql));
    }

    /** Cualquier otro problema con la base de datos (por ejemplo MySQL apagado) → 500. */
    @ExceptionHandler(DataAccessException.class)
    @ResponseStatus(HttpStatus.INTERNAL_SERVER_ERROR)
    public Map<String, String> baseDeDatos(DataAccessException e) {
        return Map.of("error", "Error de base de datos: " + e.getMostSpecificCause().getMessage());
    }

    private String traducir(String mensajeMysql) {
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
