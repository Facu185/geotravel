
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
        public final JsonNode geometriaRuta;
        /** Metros que OSRM movio el origen hasta la calle mas cercana; null si no informo. */
        public final Double ajusteOrigenMetros;
        /** Metros que OSRM movio el destino hasta la calle mas cercana; null si no informo. */
        public final Double ajusteDestinoMetros;

        public Ruta(double distanciaMetros, double duracionSegundos) {
            this(distanciaMetros, duracionSegundos, null);
        }

        public Ruta(
                double distanciaMetros,
                double duracionSegundos,
                JsonNode geometriaRuta
        ) {
            this(distanciaMetros, duracionSegundos, geometriaRuta, null, null);
        }

        public Ruta(
                double distanciaMetros,
                double duracionSegundos,
                JsonNode geometriaRuta,
                Double ajusteOrigenMetros,
                Double ajusteDestinoMetros
        ) {
            this.distanciaMetros = distanciaMetros;
            this.duracionSegundos = duracionSegundos;
            this.geometriaRuta = geometriaRuta;
            this.ajusteOrigenMetros = ajusteOrigenMetros;
            this.ajusteDestinoMetros = ajusteDestinoMetros;
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
            "%s/route/v1/driving/%.7f,%.7f;%.7f,%.7f"
                + "?overview=full&geometries=geojson&steps=false",
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
            // OSRM informa "sin ruta" con HTTP 400 (NoSegment) o 404 (NoRoute): no es una caida del motor
            if (respuesta.statusCode() == 400 || respuesta.statusCode() == 404) {
                String codigo = codigoDe(respuesta.body());
                if ("NoSegment".equals(codigo) || "NoRoute".equals(codigo)) {
                    throw new SinRutaException(mensajeSinRuta(codigo));
                }
            }
            throw new IOException(
                    "OSRM respondio HTTP " + respuesta.statusCode()
            );
        }

        Ruta ruta = parsearRuta(respuesta.body());
        if (ruta.geometriaRuta == null) {
            throw new IOException("OSRM no devolvio la geometria del recorrido");
        }
        return ruta;
    }

    static Ruta parsearRuta(String contenido) throws IOException {

        JsonNode raiz = JSON.readTree(contenido);

        if (raiz == null) {
            throw new IOException("Respuesta OSRM vacia");
        }

        String codigo = raiz.path("code").asText();

        if ("NoRoute".equals(codigo) || "NoSegment".equals(codigo)) {
            throw new SinRutaException(mensajeSinRuta(codigo));
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

        JsonNode geometria = ruta.path("geometry");
        if (geometria.isMissingNode() || geometria.isNull()) {
            geometria = null;
        } else {
            if (!"LineString".equals(geometria.path("type").asText())
                    || !geometria.path("coordinates").isArray()
                    || geometria.path("coordinates").size() < 2) {
                throw new IOException("Geometria GeoJSON invalida");
            }

            for (JsonNode punto : geometria.path("coordinates")) {
                if (!punto.isArray()
                        || punto.size() < 2
                        || !punto.get(0).isNumber()
                        || !punto.get(1).isNumber()) {
                    throw new IOException("Coordenadas de ruta invalidas");
                }

                double lon = punto.get(0).asDouble();
                double lat = punto.get(1).asDouble();
                if (!Double.isFinite(lon) || !Double.isFinite(lat)
                        || lon < -180 || lon > 180
                        || lat < -90 || lat > 90) {
                    throw new IOException("Coordenadas fuera de rango");
                }
            }
        }

        JsonNode puntos = raiz.path("waypoints");
        Double ajusteOrigen = ajusteDe(puntos.path(0));
        Double ajusteDestino = ajusteDe(puntos.path(1));

        return new Ruta(distancia, duracion, geometria, ajusteOrigen, ajusteDestino);
    }

    private static String mensajeSinRuta(String codigo) {
        return "NoSegment".equals(codigo)
                ? "No hay una calle transitable cerca del recurso o del incidente"
                : "No se encontro ruta vial";
    }

    private static String codigoDe(String contenido) {
        try {
            return JSON.readTree(contenido).path("code").asText();
        } catch (IOException | RuntimeException e) {
            return "";
        }
    }

    private static Double ajusteDe(JsonNode waypoint) {
        JsonNode distancia = waypoint.path("distance");
        if (!distancia.isNumber() || !Double.isFinite(distancia.asDouble())) {
            return null;
        }
        return distancia.asDouble();
    }
}
