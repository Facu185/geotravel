package uy.edu.fing.geotravel.eta;

import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Servicio compartido de rutas por calles entre un recurso y un incidente. Lo usan /eta y el analisis vial de
 * la consulta 3, para que ambos calculen igual.
 *
 * Origen: la ubicacion del recurso. Destino: el punto del incidente mas cercano al recurso (ST_ClosestPoint),
 * que para un Point es el propio punto y para una linea o un poligono es el punto de su geometria mas proximo.
 * El motor (OSRM) mueve cada extremo a la calle mas cercana; ese desplazamiento se informa y, si es grande,
 * se advierte que la distancia vial es aproximada.
 *
 * Criterio: OSRM con perfil driving minimiza la DURACION (ruta mas rapida). No garantiza la menor distancia.
 */
public class RutaService {

    public static final String CRITERIO = "mas_rapida";
    public static final String CRITERIO_TEXTO = "Ruta mas rapida (OSRM driving, optimiza duracion, no distancia)";
    public static final String MOTOR = "OSRM driving";
    /** Desde cuantos metros de desplazamiento a la calle se advierte que el extremo no es exacto. */
    public static final double AJUSTE_ADVERTENCIA_METROS = 100;

    private static final long CACHE_VIGENCIA_NANOS = 5L * 60 * 1_000_000_000L;
    private static final int CACHE_MAXIMO = 500;

    private static final String SQL_EXTREMOS =
            "SELECT " +
            "ST_X(ST_Transform(r.geom, 4326)) AS origen_lon, " +
            "ST_Y(ST_Transform(r.geom, 4326)) AS origen_lat, " +
            "ST_X(ST_Transform(ST_ClosestPoint(i.geom, r.geom), 4326)) AS destino_lon, " +
            "ST_Y(ST_Transform(ST_ClosestPoint(i.geom, r.geom), 4326)) AS destino_lat, " +
            "ST_Distance(r.geom, i.geom) AS distancia_directa_m " +
            "FROM recurso r CROSS JOIN incidente i " +
            "WHERE r.id = ? AND i.id = ?";

    /** Motor de enrutamiento; permite reemplazar OSRM en las pruebas. */
    public interface MotorRutas {
        OsrmClient.Ruta calcular(double origenLon, double origenLat, double destinoLon, double destinoLat)
                throws IOException, InterruptedException;
    }

    public static final class Extremos {
        public final double origenLon;
        public final double origenLat;
        public final double destinoLon;
        public final double destinoLat;
        public final double distanciaDirectaM;

        public Extremos(double origenLon, double origenLat, double destinoLon, double destinoLat,
                        double distanciaDirectaM) {
            this.origenLon = origenLon;
            this.origenLat = origenLat;
            this.destinoLon = destinoLon;
            this.destinoLat = destinoLat;
            this.distanciaDirectaM = distanciaDirectaM;
        }
    }

    public enum Estado {
        DISPONIBLE("disponible"),
        SIN_RUTA("sin_ruta"),
        ERROR("error");

        public final String codigo;

        Estado(String codigo) {
            this.codigo = codigo;
        }
    }

    /** Resultado de intentar una ruta sin lanzar excepciones: la consulta puede seguir con los demas recursos. */
    public static final class Resultado {
        public final Estado estado;
        public final OsrmClient.Ruta ruta;
        public final String mensaje;
        /** true si el motor no respondio (conexion, HTTP o formato): conviene no insistir con otros recursos. */
        public final boolean motorCaido;

        private Resultado(Estado estado, OsrmClient.Ruta ruta, String mensaje, boolean motorCaido) {
            this.estado = estado;
            this.ruta = ruta;
            this.mensaje = mensaje;
            this.motorCaido = motorCaido;
        }

        public static Resultado ok(OsrmClient.Ruta ruta) {
            return new Resultado(Estado.DISPONIBLE, ruta, null, false);
        }

        public static Resultado sinRuta(String mensaje) {
            return new Resultado(Estado.SIN_RUTA, null, mensaje, false);
        }

        public static Resultado error(String mensaje, boolean motorCaido) {
            return new Resultado(Estado.ERROR, null, mensaje, motorCaido);
        }
    }

    private static final class Entrada {
        final OsrmClient.Ruta ruta;
        final long vence;

        Entrada(OsrmClient.Ruta ruta, long vence) {
            this.ruta = ruta;
            this.vence = vence;
        }
    }

    private static final RutaService PREDETERMINADO = new RutaService(OsrmClient::consultar);

    private final MotorRutas motor;
    private final Map<String, Entrada> cache = new ConcurrentHashMap<>();

    public RutaService(MotorRutas motor) {
        this.motor = motor;
    }

    public static RutaService predeterminado() {
        return PREDETERMINADO;
    }

    /** Extremos de la ruta (en lon/lat) y distancia directa; null si el recurso o el incidente no existen. */
    public Extremos extremos(Connection conexion, int recursoId, int incidenteId) throws SQLException {
        try (PreparedStatement consulta = conexion.prepareStatement(SQL_EXTREMOS)) {
            consulta.setInt(1, recursoId);
            consulta.setInt(2, incidenteId);
            try (ResultSet rs = consulta.executeQuery()) {
                if (!rs.next()) {
                    return null;
                }
                return new Extremos(
                        rs.getDouble("origen_lon"), rs.getDouble("origen_lat"),
                        rs.getDouble("destino_lon"), rs.getDouble("destino_lat"),
                        rs.getDouble("distancia_directa_m"));
            }
        }
    }

    /** Consulta la ruta (con cache de pocos minutos para no repetir pedidos iguales). */
    public OsrmClient.Ruta consultar(Extremos e) throws IOException, InterruptedException {
        String clave = String.format(Locale.ROOT, "%.5f,%.5f;%.5f,%.5f",
                e.origenLon, e.origenLat, e.destinoLon, e.destinoLat);
        long ahora = System.nanoTime();

        Entrada guardada = cache.get(clave);
        if (guardada != null && ahora - guardada.vence < 0) {
            return guardada.ruta;
        }

        OsrmClient.Ruta ruta = motor.calcular(e.origenLon, e.origenLat, e.destinoLon, e.destinoLat);

        if (cache.size() >= CACHE_MAXIMO) {
            cache.clear();
        }
        cache.put(clave, new Entrada(ruta, ahora + CACHE_VIGENCIA_NANOS));
        return ruta;
    }

    /** Igual que consultar, pero traduce los fallos a un estado para respuestas parciales. */
    public Resultado intentar(Extremos e) {
        try {
            return Resultado.ok(consultar(e));
        } catch (OsrmClient.SinRutaException ex) {
            return Resultado.sinRuta(ex.getMessage());
        } catch (InterruptedException ex) {
            Thread.currentThread().interrupt();
            return Resultado.error("Consulta de rutas interrumpida", true);
        } catch (IOException | RuntimeException ex) {
            return Resultado.error("No se pudo consultar el servicio de rutas", true);
        }
    }

    /** Aviso cuando OSRM movio el origen o el destino lejos de donde estan; null si el ajuste es chico. */
    public static String advertencia(OsrmClient.Ruta ruta) {
        double origen = ruta.ajusteOrigenMetros == null ? 0 : ruta.ajusteOrigenMetros;
        double destino = ruta.ajusteDestinoMetros == null ? 0 : ruta.ajusteDestinoMetros;
        if (origen < AJUSTE_ADVERTENCIA_METROS && destino < AJUSTE_ADVERTENCIA_METROS) {
            return null;
        }
        return String.format(Locale.ROOT,
                "El recurso o el incidente quedaron a %.0f m y %.0f m de la calle mas cercana; "
                        + "la distancia vial es aproximada",
                origen, destino);
    }
}
