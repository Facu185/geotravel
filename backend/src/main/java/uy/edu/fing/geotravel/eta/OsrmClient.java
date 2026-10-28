
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
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

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

    /** El criterio pedido requiere un servicio OSRM que no esta configurado. */
    public static class NoConfiguradoException extends IOException {

        public NoConfiguradoException(String mensaje) {
            super(mensaje);
        }
    }

    /** Se agoto el tiempo disponible para esta consulta al motor. */
    public static class PlazoAgotadoException extends IOException {

        public PlazoAgotadoException(String mensaje) {
            super(mensaje);
        }
    }

    public static final long TIMEOUT_POR_DEFECTO_MS = 10_000;

    /** Direccion del motor del criterio: OSRM_FAST_URL (o OSRM_URL, o el OSRM publico) / OSRM_SHORTEST_URL (o OSRM_URL_CORTA). */
    static String servidorDe(Criterio criterio) {
        if (criterio == Criterio.MAS_CORTA) {
            String url = primero("OSRM_SHORTEST_URL", "OSRM_URL_CORTA");
            return url == null ? null : url.replaceAll("/+$", "");
        }
        String url = primero("OSRM_FAST_URL", "OSRM_URL");
        return (url == null ? "https://router.project-osrm.org" : url).replaceAll("/+$", "");
    }

    private static String primero(String... nombres) {
        for (String nombre : nombres) {
            String valor = System.getenv(nombre);
            if (valor != null && !valor.isBlank()) {
                return valor;
            }
        }
        return null;
    }

    /** Vigencia de una comprobacion de salud: una caida se refleja en /eta/criterios en a lo sumo este tiempo. */
    public static final long SALUD_VIGENCIA_MS = 5_000;
    static final long SALUD_TIMEOUT_MS = 2_000;
    private static final java.util.Map<String, long[]> SALUD = new java.util.concurrent.ConcurrentHashMap<>();

    /** true si el motor del criterio esta configurado y responde una ruta valida (consulta con timeout de 2 s, cacheada 5 s). */
    public static boolean saludable(Criterio criterio) {
        String servidor = servidorDe(criterio);
        if (servidor == null) {
            return false;
        }
        long ahora = System.nanoTime() / 1_000_000;
        long[] previo = SALUD.get(servidor);
        if (previo != null && ahora - previo[1] < SALUD_VIGENCIA_MS) {
            return previo[0] == 1;
        }
        boolean ok = comprobar(servidor, SALUD_TIMEOUT_MS);
        SALUD.put(servidor, new long[] {ok ? 1 : 0, ahora});
        return ok;
    }

    /** Pide una ruta corta fija (Montevideo) y exige code=Ok con geometria; cualquier otra cosa es "no saludable". */
    static boolean comprobar(String servidor, long timeoutMs) {
        String url = servidor.replaceAll("/+$", "")
                + "/route/v1/driving/-56.1900,-34.9000;-56.1685,-34.9158?overview=false";
        HttpRequest solicitud = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .timeout(Duration.ofMillis(timeoutMs))
                .GET()
                .build();
        CompletableFuture<HttpResponse<String>> pedido =
                HTTP.sendAsync(solicitud, HttpResponse.BodyHandlers.ofString());
        try {
            HttpResponse<String> r = pedido.get(timeoutMs, TimeUnit.MILLISECONDS);
            return r.statusCode() == 200 && "Ok".equals(JSON.readTree(r.body()).path("code").asText());
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            pedido.cancel(true);
            return false;
        } catch (Exception e) {
            pedido.cancel(true);
            return false;
        }
    }

    public static boolean cortaConfigurada() {
        return servidorDe(Criterio.MAS_CORTA) != null;
    }

    public static Ruta consultar(
            double origenLon,
            double origenLat,
            double destinoLon,
            double destinoLat
    ) throws IOException, InterruptedException {
        return consultar(origenLon, origenLat, destinoLon, destinoLat, Criterio.MAS_RAPIDA);
    }

    public static Ruta consultarCorta(
            double origenLon,
            double origenLat,
            double destinoLon,
            double destinoLat
    ) throws IOException, InterruptedException {
        return consultar(origenLon, origenLat, destinoLon, destinoLat, Criterio.MAS_CORTA);
    }

    public static Ruta consultar(
            double origenLon,
            double origenLat,
            double destinoLon,
            double destinoLat,
            Criterio criterio
    ) throws IOException, InterruptedException {
        return consultar(origenLon, origenLat, destinoLon, destinoLat, criterio, TIMEOUT_POR_DEFECTO_MS);
    }

    /** timeoutMs es un limite estricto para toda la respuesta; al vencer se cancela el pedido. */
    public static Ruta consultar(
            double origenLon,
            double origenLat,
            double destinoLon,
            double destinoLat,
            Criterio criterio,
            long timeoutMs
    ) throws IOException, InterruptedException {

        String servidor = servidorDe(criterio);
        if (servidor == null) {
            throw new NoConfiguradoException(
                    "El servicio de ruta mas corta (OSRM_SHORTEST_URL) no esta configurado");
        }
        if (timeoutMs <= 0) {
            throw new PlazoAgotadoException("Se agoto el tiempo maximo para calcular rutas");
        }

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
                .timeout(Duration.ofMillis(timeoutMs))
                .header("Accept", "application/json")
                .GET()
                .build();

        CompletableFuture<HttpResponse<String>> pedido =
                HTTP.sendAsync(solicitud, HttpResponse.BodyHandlers.ofString());
        HttpResponse<String> respuesta;
        try {
            respuesta = pedido.get(timeoutMs, TimeUnit.MILLISECONDS);
        } catch (TimeoutException e) {
            pedido.cancel(true);
            throw new PlazoAgotadoException("El servicio de rutas no respondio a tiempo");
        } catch (InterruptedException e) {
            pedido.cancel(true);
            throw e;
        } catch (ExecutionException e) {
            pedido.cancel(true);
            Throwable causa = e.getCause();
            if (causa instanceof java.net.http.HttpConnectTimeoutException) {
                throw new IOException("No se pudo conectar con el servicio de rutas", causa);
            }
            if (causa instanceof java.net.http.HttpTimeoutException) {
                throw new PlazoAgotadoException("El servicio de rutas no respondio a tiempo");
            }
            throw new IOException("No se pudo conectar con el servicio de rutas", causa);
        }

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
