package co.udistrital.proyectofinalbd.common.web;

import java.util.Map;
import java.util.Objects;

import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.HttpStatus;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.server.ResponseStatusException;

/**
 * Valida referencias lógicas inter-servicio consultando la API REST del
 * microservicio propietario antes de persistir operaciones.
 */
@Component
public class ValidadorReferencias {

    private static final ParameterizedTypeReference<Map<String, Object>> MAP_TYPE =
            new ParameterizedTypeReference<>() {
            };

    private final RestClient.Builder restClientBuilder;

    public ValidadorReferencias() {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(4000);
        factory.setReadTimeout(10000);
        this.restClientBuilder = RestClient.builder().requestFactory(factory);
    }

    public void validarExiste(String baseUrl, String ruta, String mensajeSiNoExiste) {
        obtenerRecurso(baseUrl, ruta, mensajeSiNoExiste);
    }

    public void validarAlmacenEnSede(String catalogoUrl, Integer idAlmacen, Integer idSede) {
        if (idSede == null || idAlmacen == null) {
            throw new IllegalArgumentException("Debe indicar idSede e idAlmacen");
        }
        Map<String, Object> almacen = obtenerRecurso(
                catalogoUrl,
                "/api/almacenes/" + idAlmacen,
                "El almacén " + idAlmacen + " no existe en catalogo-service");
        Object sedeAlmacen = almacen.get("id_sede");
        if (!(sedeAlmacen instanceof Number num) || !Objects.equals(num.intValue(), idSede)) {
            throw new IllegalArgumentException(
                    "El almacén " + idAlmacen + " pertenece a la sede " + sedeAlmacen + ", no a la sede " + idSede);
        }
    }

    public Map<String, Object> obtenerRecurso(String baseUrl, String ruta, String mensajeSiNoExiste) {
        try {
            Map<String, Object> cuerpo = restClientBuilder
                    .baseUrl(normalizar(baseUrl))
                    .build()
                    .get()
                    .uri(ruta)
                    .retrieve()
                    .body(MAP_TYPE);
            if (cuerpo == null) {
                throw new IllegalArgumentException(mensajeSiNoExiste);
            }
            return cuerpo;
        } catch (HttpClientErrorException.NotFound ex) {
            throw new IllegalArgumentException(mensajeSiNoExiste);
        } catch (RestClientException ex) {
            throw new ResponseStatusException(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "No se pudo validar la referencia externa en " + baseUrl + ruta,
                    ex);
        }
    }

    private String normalizar(String url) {
        if (url == null || url.isBlank()) {
            return "http://localhost";
        }
        String limpia = url.trim();
        return limpia.startsWith("http://") || limpia.startsWith("https://")
                ? limpia
                : "https://" + limpia;
    }
}
