package co.edu.uao.domicilios;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Punto de entrada. Al ejecutar esta clase se levanta:
 *  - la API REST en http://localhost:8080/api/...
 *  - la interfaz gráfica en http://localhost:8080 (archivos de src/main/resources/static)
 */
@SpringBootApplication
public class DomiciliosApplication {

    public static void main(String[] args) {
        SpringApplication.run(DomiciliosApplication.class, args);
    }
}
