package co.udistrital.proyectofinalbd.common.web;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;

import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ValidadorReferenciasTest {

    private final ValidadorReferencias validador = new ValidadorReferencias();
    private HttpServer server;

    @AfterEach
    void cerrarServidor() {
        if (server != null) {
            server.stop(0);
        }
    }

    @Test
    void aceptaRecursoExistenteYAlmacenDeLaSedeCorrecta() throws IOException {
        String baseUrl = iniciarStub();
        assertDoesNotThrow(() -> validador.validarExiste(baseUrl, "/api/clientes/1", "No existe"));
        assertDoesNotThrow(() -> validador.validarAlmacenEnSede(baseUrl, 2, 1));
    }

    @Test
    void rechazaRecursoInexistente404ComoIllegalArgumentException() throws IOException {
        String baseUrl = iniciarStub();
        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class,
                () -> validador.validarExiste(baseUrl, "/api/clientes/99999", "Cliente 99999 no existe"));
        assertTrue(ex.getMessage().contains("99999"));
    }

    @Test
    void rechazaAlmacenQueNoPerteneceALaSedeIndicada() throws IOException {
        String baseUrl = iniciarStub();
        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class,
                () -> validador.validarAlmacenEnSede(baseUrl, 2, 4));
        assertTrue(ex.getMessage().contains("sede 1"));
    }

    @Test
    void devuelve503CuandoElServicioPropietarioNoResponde() {
        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> validador.validarExiste("http://127.0.0.1:19999", "/api/clientes/1", "No existe"));
        assertEquals(503, ex.getStatusCode().value());
    }

    private String iniciarStub() throws IOException {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/api/clientes/1", exchange -> responder(exchange, 200, "{\"id_cliente\":1}"));
        server.createContext("/api/almacenes/2", exchange -> responder(exchange, 200, "{\"id_almacen\":2,\"id_sede\":1}"));
        server.createContext("/", exchange -> responder(exchange, 404, "{\"status\":404}"));
        server.start();
        return "http://127.0.0.1:" + server.getAddress().getPort();
    }

    private void responder(com.sun.net.httpserver.HttpExchange exchange, int status, String json) throws IOException {
        byte[] bytes = json.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().add("Content-Type", "application/json");
        exchange.sendResponseHeaders(status, bytes.length);
        try (OutputStream os = exchange.getResponseBody()) {
            os.write(bytes);
        }
    }
}
