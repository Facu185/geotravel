
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

public final class OsrmClient {

    private static final ObjectMapper JSON = new ObjectMapper();

    private static final HttpClient HTTP = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(4))
            .build();

    private OsrmClient() {
    }

    public static class Ruta {

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

    public static class SinRutaException extends IOException {

        public SinRutaException(String mensaje) {
            super(mensaje);
        }
    }

    public static Ruta consultar(
            double origenLon,
            double origenLat,
            double destinoLon,
            double destinoLat
    ) throws IOException, InterruptedException {

        String servidor = System.getenv("OSRM_URL");

        if (servidor == null || servidor.isBlank()) {
            servidor = "https://router.project-osrm.org";
        }

        servidor = servidor.replaceAll("/+$", "");

        String url = String.format(
                Locale.ROOT,
                "%s/route/v1/driving/%.7f,%.7f;%.7f,%.7f?overview=false&steps=false",
                servidor,
                origenLon,
                origenLat,
                destinoLon,
                destinoLat
        );

        HttpRequest solicitud = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .timeout(Duration.ofSeconds(10))
                .header("Accept", "application/json")
                .GET()
                .build();

        HttpResponse<String> respuesta = HTTP.send(
                solicitud,
                HttpResponse.BodyHandlers.ofString()
        );

        if (respuesta.statusCode() != 200) {
            throw new IOException(
                    "OSRM respondio HTTP " + respuesta.statusCode()
            );
        }

        return parsearRuta(respuesta.body());
    }

    static Ruta parsearRuta(String contenido) throws IOException {

        JsonNode raiz = JSON.readTree(contenido);

        if (raiz == null) {
            throw new IOException("Respuesta OSRM vacia");
        }

        String codigo = raiz.path("code").asText();

        if ("NoRoute".equals(codigo)) {
            throw new SinRutaException("No se encontro ruta vial");
        }

        if (!"Ok".equals(codigo)) {
            throw new IOException("Respuesta OSRM invalida");
        }

        JsonNode ruta = raiz.path("routes").path(0);

        if (!ruta.path("distance").isNumber()
                || !ruta.path("duration").isNumber()) {
            throw new IOException("Faltan datos de distancia o duracion");
        }

        double distancia = ruta.path("distance").asDouble();
        double duracion = ruta.path("duration").asDouble();

        if (!Double.isFinite(distancia) || !Double.isFinite(duracion)
                || distancia < 0 || duracion < 0) {
            throw new IOException("Datos de ruta invalidos");
        }

        return new Ruta(distancia, duracion);
    }
}
