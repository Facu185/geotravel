package uy.edu.fing.geotravel.eta;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Locale;

/**
 * Consulta una ruta vial OSRM (perfil driving) entre dos puntos EPSG:4326.
 * El servidor se configura con OSRM_URL. El servicio publico predeterminado
 * es exclusivamente para desarrollo; no ofrece disponibilidad garantizada.
 */
public final class OsrmClient {

    private static final ObjectMapper JSON = new ObjectMapper();
    private static final HttpClient HTTP = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(4))
            .build();

    private OsrmClient() {
    }

    public static final class Ruta {
        public final double distanciaMetros;
        public final double duracionSegundos;

        public Ruta(double distanciaMetros, double duracionSegundos) {
            this.distanciaMetros = distanciaMetros;
            this.duracionSegundos = duracionSegundos;
        }

        public long minutosRedondeados() {
            return (long) Math.ceil(duracionSegundos / 60.0);
        }
    }

    public static final class SinRutaException extends IOException {
        public SinRutaException(String mensaje) {
            super(mensaje);
        }
    }

    public static Ruta consultar(double origenLon, double origenLat,
                                 double destinoLon, double destinoLat)
            throws IOException, InterruptedException {
        String base = System.getenv("OSRM_URL");
        if (base == null || base.isBlank()) {
            base = "https://router.project-osrm.org";
        }
        base = base.replaceAll("/+$", "");

        // OSRM utiliza lon,lat (en ese orden) en coordenadas geograficas.
        String url = String.format(Locale.ROOT,
                "%s/route/v1/driving/%.7f,%.7f;%.7f,%.7f?overview=false&steps=false",
                base, origenLon, origenLat, destinoLon, destinoLat);

        HttpRequest request = HttpRequest.newBuilder(URI.create(url))
                .timeout(Duration.ofSeconds(10))
                .header("Accept", "application/json")
                .GET()
                .build();
        HttpResponse<String> response = HTTP.send(request, HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() != 200) {
            throw new IOException("Servicio OSRM no disponible (HTTP " + response.statusCode() + ")");
        }
        return parsearRuta(response.body());
    }

    /** Metodo puro para poder probar el calculo sin hacer solicitudes externas. */
    static Ruta parsearRuta(String cuerpo) throws IOException {
        JsonNode raiz = JSON.readTree(cuerpo);
        if (raiz == null || !"Ok".equals(raiz.path("code").asText())) {
            if (raiz != null && "NoRoute".equals(raiz.path("code").asText())) {
                throw new SinRutaException("No existe ruta vial entre el recurso y el incidente");
            }
            throw new IOException("Respuesta invalida del servicio OSRM");
        }
        JsonNode ruta = raiz.path("routes").path(0);
        if (!ruta.path("distance").isNumber() || !ruta.path("duration").isNumber()) {
            throw new IOException("OSRM no devolvio distancia y duracion");
        }
        double metros = ruta.path("distance").asDouble();
        double segundos = ruta.path("duration").asDouble();
        if (!Double.isFinite(metros) || !Double.isFinite(segundos)
                || metros < 0 || segundos < 0) {
            throw new IOException("Medidas invalidas en la ruta de OSRM");
        }
        return new Ruta(metros, segundos);
    }
}
