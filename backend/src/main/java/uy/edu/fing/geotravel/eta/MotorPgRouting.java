package uy.edu.fing.geotravel.eta;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import uy.edu.fing.geotravel.db.DataSourceProvider;

import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

/**
 * Motor de rutas: llama a la funcion SQL p2_calcular_ruta (db/sql/p2_rutas_pgrouting.sql), que corre pgRouting
 * sobre la red vial de OpenStreetMap (tablas red_vial_arco y red_vial_vertice) dentro de PostgreSQL.
 * Hay un unico camino: el de menor duracion.
 */
public final class MotorPgRouting implements RutaService.MotorRutas {
    private static final ObjectMapper JSON = new ObjectMapper();
    private static final String SQL_RUTA =
            "SELECT distancia_m, duracion_s, geometria_geojson, ajuste_origen_m, ajuste_destino_m, calles_json " +
            "FROM public.p2_calcular_ruta(?, ?, ?, ?)";
    private static final String SQL_SALUD =
            "SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgrouting') " +
            "AND to_regprocedure('public.p2_calcular_ruta(double precision,double precision,double precision,double precision)') IS NOT NULL " +
            "AND EXISTS (SELECT 1 FROM public.red_vial_arco WHERE componente_grande LIMIT 1)";

    /** Una comprobacion de salud vale unos segundos: una red vial que se carga se refleja enseguida. */
    private static final long SALUD_VIGENCIA_MS = 5_000;
    private static volatile long saludHasta = 0;
    private static volatile boolean saludUltima = false;

    /** true solo cuando la extension, la funcion y la red vial ya existen en la base (cacheado 5 s). */
    public boolean saludable() {
        long ahora = System.currentTimeMillis();
        if (ahora < saludHasta) {
            return saludUltima;
        }
        boolean ok = false;
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(SQL_SALUD)) {
            ps.setQueryTimeout(2);
            try (ResultSet rs = ps.executeQuery()) {
                ok = rs.next() && rs.getBoolean(1);
            }
        } catch (SQLException ex) {
            ok = false;
        }
        saludUltima = ok;
        saludHasta = ahora + SALUD_VIGENCIA_MS;
        return ok;
    }

    @Override
    public Ruta calcular(double origenLon, double origenLat, double destinoLon, double destinoLat)
            throws IOException, InterruptedException {
        return calcular(origenLon, origenLat, destinoLon, destinoLat, RutaService.TIMEOUT_POR_DEFECTO_MS);
    }

    @Override
    public Ruta calcular(double origenLon, double origenLat, double destinoLon, double destinoLat,
                         long timeoutMs) throws IOException, InterruptedException {
        if (Thread.currentThread().isInterrupted()) throw new InterruptedException("Ruta interrumpida");
        if (timeoutMs <= 0) throw new PlazoAgotadoException("Se agoto el tiempo disponible");
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(SQL_RUTA)) {
            ps.setQueryTimeout((int) Math.min(Integer.MAX_VALUE, Math.max(1, (timeoutMs + 999) / 1000)));
            ps.setDouble(1, origenLon);
            ps.setDouble(2, origenLat);
            ps.setDouble(3, destinoLon);
            ps.setDouble(4, destinoLat);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) {
                    throw new SinRutaException("No hay camino por calles entre los dos puntos (alguno queda fuera de la red vial)");
                }
                double metros = rs.getDouble("distancia_m");
                double segundos = rs.getDouble("duracion_s");
                String geojson = rs.getString("geometria_geojson");
                if (geojson == null || !Double.isFinite(metros) || !Double.isFinite(segundos)
                        || metros < 0 || segundos < 0) {
                    throw new IOException("Respuesta invalida de pgRouting");
                }
                JsonNode geometria = JSON.readTree(geojson);
                if (!"LineString".equals(geometria.path("type").asText())) {
                    throw new IOException("pgRouting no devolvio un GeoJSON LineString");
                }
                double ajusteOrigen = rs.getDouble("ajuste_origen_m");
                Double ajusteO = rs.wasNull() ? null : ajusteOrigen;
                double ajusteDestino = rs.getDouble("ajuste_destino_m");
                Double ajusteD = rs.wasNull() ? null : ajusteDestino;
                String callesJson = rs.getString("calles_json");
                JsonNode calles = callesJson == null ? null : JSON.readTree(callesJson);
                return new Ruta(metros, segundos, geometria, ajusteO, ajusteD, calles);
            }
        } catch (SQLException ex) {
            if ("57014".equals(ex.getSQLState())) {
                throw new PlazoAgotadoException("pgRouting supero el tiempo disponible");
            }
            throw new IOException("No se pudo consultar pgRouting", ex);
        }
    }
}
