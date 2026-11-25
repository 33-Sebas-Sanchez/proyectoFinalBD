package co.udistrital.proyectofinalbd.reportes;

import java.util.LinkedHashMap;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestClient;

/**
 * Reportes corporativos por composición de APIs.
 *
 * <p>Con una base de datos por microservicio, el servicio de reportes no puede
 * leer las tablas de los demás. En su lugar consulta el endpoint
 * {@code /api/resumen} de cada servicio y consolida la respuesta. Si un
 * servicio no responde, se informa el error sin tumbar el reporte completo.</p>
 */
@RestController
@RequestMapping("/api/reportes")
public class ReportesController {

    private final Map<String, String> servicios = new LinkedHashMap<>();
    private final SimpleClientHttpRequestFactory requestFactory;

    public ReportesController(
            @Value("${app.servicios.catalogo}") String catalogo,
            @Value("${app.servicios.compras}") String compras,
            @Value("${app.servicios.inventarios}") String inventarios,
            @Value("${app.servicios.ventas}") String ventas,
            @Value("${app.servicios.identidad}") String identidad) {
        servicios.put("catalogo", catalogo);
        servicios.put("compras", compras);
        servicios.put("inventarios", inventarios);
        servicios.put("ventas", ventas);
        servicios.put("identidad", identidad);

        this.requestFactory = new SimpleClientHttpRequestFactory();
        this.requestFactory.setConnectTimeout(4000);
        this.requestFactory.setReadTimeout(20000);
    }

    @GetMapping("/resumen")
    public Map<String, Object> resumen() {
        Map<String, Object> respuesta = new LinkedHashMap<>();
        servicios.forEach((nombre, url) -> respuesta.put(nombre, consultar(nombre, url)));
        return respuesta;
    }

    private Object consultar(String nombre, String url) {
        try {
            return RestClient.builder()
                    .requestFactory(requestFactory)
                    .baseUrl(normalizar(url))
                    .build()
                    .get()
                    .uri("/api/resumen")
                    .retrieve()
                    .body(Map.class);
        } catch (Exception ex) {
            Map<String, Object> error = new LinkedHashMap<>();
            error.put("servicio", nombre);
            error.put("error", ex.getMessage());
            return error;
        }
    }

    /**
     * Render entrega el host sin esquema (por ejemplo
     * {@code catalogo-service.onrender.com}); en local se usa una URL completa.
     */
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
