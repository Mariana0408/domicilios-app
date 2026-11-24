package co.edu.uao.domicilios.soporte;

/** Se lanza cuando se busca un registro que no existe; se responde con 404. */
public class NoEncontradoException extends RuntimeException {

    public NoEncontradoException(String mensaje) {
        super(mensaje);
    }
}
