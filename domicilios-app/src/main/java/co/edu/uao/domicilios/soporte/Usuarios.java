package co.edu.uao.domicilios.soporte;

import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Cliente y Domiciliario son subtipos de Usuario (su PK también es FK a Usuario).
 * Esta clase maneja la parte común: guardar los datos personales en la tabla Usuario.
 * La especialización es solapada: una persona puede ser cliente y domiciliario a la vez
 * (como Santiago 1000000007 y Mariana 1000000008 en los datos de prueba).
 */
@Component
public class Usuarios {

    private final JdbcTemplate jdbc;

    public Usuarios(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** Inserta el usuario; si ya existe (por ejemplo ya era cliente y ahora será domiciliario) actualiza sus datos. */
    public void guardar(long numeroIdentificacion, Map<String, Object> datos) {
        String nombre = Campos.textoRequerido(datos, "nombre");
        String apellidoPaterno = Campos.textoRequerido(datos, "apellido_Paterno");
        String apellidoMaterno = Campos.textoRequerido(datos, "apellido_Materno");
        String telefono = Campos.textoRequerido(datos, "numeroTelefono");
        String correo = Campos.texto(datos, "correoElectronico");

        if (existe(numeroIdentificacion)) {
            jdbc.update("""
                    UPDATE Usuario
                    SET nombre = ?, apellido_Paterno = ?, apellido_Materno = ?,
                        numeroTelefono = ?, correoElectronico = ?
                    WHERE numeroIdentificacion = ?""",
                    nombre, apellidoPaterno, apellidoMaterno, telefono, correo, numeroIdentificacion);
        } else {
            jdbc.update("""
                    INSERT INTO Usuario (numeroIdentificacion, nombre, apellido_Paterno, apellido_Materno,
                                         numeroTelefono, correoElectronico)
                    VALUES (?, ?, ?, ?, ?, ?)""",
                    numeroIdentificacion, nombre, apellidoPaterno, apellidoMaterno, telefono, correo);
        }
    }

    /** Borra el usuario solo si ya no es ni cliente ni domiciliario. */
    public void eliminarSiNoTieneRol(long numeroIdentificacion) {
        Integer roles = jdbc.queryForObject("""
                SELECT (SELECT COUNT(*) FROM Cliente WHERE idCliente = ?)
                     + (SELECT COUNT(*) FROM Domiciliario WHERE idDomiciliario = ?)""",
                Integer.class, numeroIdentificacion, numeroIdentificacion);
        if (roles != null && roles == 0) {
            jdbc.update("DELETE FROM Usuario WHERE numeroIdentificacion = ?", numeroIdentificacion);
        }
    }

    private boolean existe(long numeroIdentificacion) {
        Integer n = jdbc.queryForObject(
                "SELECT COUNT(*) FROM Usuario WHERE numeroIdentificacion = ?", Integer.class, numeroIdentificacion);
        return n != null && n > 0;
    }
}
