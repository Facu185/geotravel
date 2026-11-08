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
 * La ruta la calcula pgRouting dentro de PostgreSQL (MotorPgRouting) sobre la red vial de OpenStreetMap de todo el
 * pais: cada extremo se engancha al punto exacto de la calle mas cercana, se respetan los sentidos de circulacion y
 * se informa por que calles pasa. El desplazamiento hasta la calle se informa y, si es grande, se advierte que la
 * distancia vial es aproximada.
 *
 * Hay un unico camino: el de menor duracion (con los sentidos de circulacion y la velocidad de cada calle).
 */
public class RutaService {

    public static final String MOTOR = "pgRouting (PostgreSQL)";
    /** Desde cuantos metros de desplazamiento a la calle se advierte que el extremo no es exacto. */
    public static final double AJUSTE_ADVERTENCIA_METROS = 100;
    /** Tiempo maximo por defecto para calcular una ruta. */
    public static final long TIMEOUT_POR_DEFECTO_MS = 10_000;

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

    /** Motor de enrutamiento; permite reemplazarlo en las pruebas. */
    public interface MotorRutas {
        Ruta calcular(double origenLon, double origenLat, double destinoLon, double destinoLat)
                throws IOException, InterruptedException;

        /** Igual, con un limite estricto de tiempo; los motores que no lo soportan lo ignoran. */
        default Ruta calcular(double origenLon, double origenLat, double destinoLon, double destinoLat,
                              long timeoutMs) throws IOException, InterruptedException {
            return calcular(origenLon, origenLat, destinoLon, destinoLat);
        }
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
        ERROR("error"),
        PLAZO_AGOTADO("plazo_agotado");

        public final String codigo;

        Estado(String codigo) {
            this.codigo = codigo;
        }
    }

    /** Resultado de intentar una ruta sin lanzar excepciones: la consulta puede seguir con los demas recursos. */
    public static final class Resultado {
        public final Estado estado;
        public final Ruta ruta;
        public final String mensaje;
        /** true si el motor no respondio (conexion, HTTP o formato): conviene no insistir con otros recursos. */
        public final boolean motorCaido;

        private Resultado(Estado estado, Ruta ruta, String mensaje, boolean motorCaido) {
            this.estado = estado;
            this.ruta = ruta;
            this.mensaje = mensaje;
            this.motorCaido = motorCaido;
        }

        public static Resultado ok(Ruta ruta) {
            return new Resultado(Estado.DISPONIBLE, ruta, null, false);
        }

        public static Resultado sinRuta(String mensaje) {
            return new Resultado(Estado.SIN_RUTA, null, mensaje, false);
        }

        public static Resultado plazo(String mensaje) {
            return new Resultado(Estado.PLAZO_AGOTADO, null, mensaje, false);
        }

        public static Resultado error(String mensaje, boolean motorCaido) {
            return new Resultado(Estado.ERROR, null, mensaje, motorCaido);
        }
    }

    private static final class Entrada {
        final Ruta ruta;
        final long vence;

        Entrada(Ruta ruta, long vence) {
            this.ruta = ruta;
            this.vence = vence;
        }
    }

    private static final RutaService PREDETERMINADO = new RutaService(new MotorPgRouting());

    private final MotorRutas motor;
    private final Map<String, Entrada> cache = new ConcurrentHashMap<>();

    public RutaService(MotorRutas motor) {
        this.motor = motor;
    }

    public static RutaService predeterminado() {
        return PREDETERMINADO;
    }

    /** Si se puede calcular una ruta: la base tiene pgRouting, la red vial y la funcion de rutas. */
    public boolean disponible() {
        if (motor instanceof MotorPgRouting) {
            return ((MotorPgRouting) motor).saludable();
        }
        return motor != null;
    }

    /** Nombre del motor, para informar en la respuesta. */
    public String nombreMotor() {
        return motor instanceof MotorPgRouting ? MOTOR : "motor de rutas";
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
    public Ruta consultar(Extremos e) throws IOException, InterruptedException {
        return consultar(e, TIMEOUT_POR_DEFECTO_MS);
    }

    /** timeoutMs limita el calculo (no aplica si la ruta sale de la cache). */
    public Ruta consultar(Extremos e, long timeoutMs) throws IOException, InterruptedException {
        String clave = String.format(Locale.ROOT, "%.5f,%.5f;%.5f,%.5f",
                e.origenLon, e.origenLat, e.destinoLon, e.destinoLat);
        long ahora = System.nanoTime();

        Entrada guardada = cache.get(clave);
        if (guardada != null && ahora - guardada.vence < 0) {
            return guardada.ruta;
        }

        Ruta ruta = motor.calcular(e.origenLon, e.origenLat, e.destinoLon, e.destinoLat, timeoutMs);

        if (cache.size() >= CACHE_MAXIMO) {
            cache.clear();
        }
        cache.put(clave, new Entrada(ruta, ahora + CACHE_VIGENCIA_NANOS));
        return ruta;
    }

    /** Igual que consultar, pero traduce los fallos a un estado para respuestas parciales. */
    public Resultado intentar(Extremos e) {
        return intentar(e, TIMEOUT_POR_DEFECTO_MS);
    }

    public Resultado intentar(Extremos e, long timeoutMs) {
        try {
            return Resultado.ok(consultar(e, timeoutMs));
        } catch (SinRutaException ex) {
            return Resultado.sinRuta(ex.getMessage());
        } catch (PlazoAgotadoException ex) {
            return Resultado.plazo(ex.getMessage());
        } catch (MotorNoDisponibleException ex) {
            return Resultado.error(ex.getMessage(), true);
        } catch (InterruptedException ex) {
            Thread.currentThread().interrupt();
            return Resultado.error("Consulta de rutas interrumpida", true);
        } catch (IOException | RuntimeException ex) {
            return Resultado.error("No se pudo calcular la ruta", true);
        }
    }

    /** Aviso cuando la red vial movio el origen o el destino lejos de donde estan; null si el ajuste es chico. */
    public static String advertencia(Ruta ruta) {
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
