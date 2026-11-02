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
 * Adaptador JDBC para la funcion SQL de P2, una vez que P1 entregue el grafo.
 * No modifica el contrato de ETA ni el de la consulta 3.
 */
public final class MotorPgRouting implements RutaService.MotorRutas {
    private static final ObjectMapper JSON = new ObjectMapper();
    private static final String SQL_RUTA =
            "SELECT distancia_m, duracion_s, geometria_geojson, ajuste_origen_m, ajuste_destino_m " +
            "FROM public.p2_calcular_ruta(?, ?, ?, ?, ?)";
    private static final String SQL_SALUD =
            "SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgrouting') " +
            "AND to_regclass('public.red_vial_arco') IS NOT NULL " +
            "AND to_regclass('public.red_vial_vertice') IS NOT NULL " +
            "AND to_regprocedure('public.p2_calcular_ruta(double precision,double precision,double precision,double precision,text)') IS NOT NULL";

    private final Criterio criterio;

    public MotorPgRouting(Criterio criterio) {
        this.criterio = criterio;
    }

    /** Solo declara disponible pgRouting cuando extension, funcion y grafo ya existen. */
    public boolean saludable() {
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(SQL_SALUD)) {
            ps.setQueryTimeout(2);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next() || !rs.getBoolean(1)) return false;
            }
            try (PreparedStatement arcos = conn.prepareStatement(
                    "SELECT EXISTS (SELECT 1 FROM public.red_vial_arco LIMIT 1) " +
                    "AND EXISTS (SELECT 1 FROM public.red_vial_vertice LIMIT 1)")) {
                arcos.setQueryTimeout(2);
                try (ResultSet rs = arcos.executeQuery()) {
                    return rs.next() && rs.getBoolean(1);
                }
            }
        } catch (SQLException ex) {
            return false;
        }
    }

    @Override
    public OsrmClient.Ruta calcular(double origenLon, double origenLat, double destinoLon, double destinoLat)
            throws IOException, InterruptedException {
        return calcular(origenLon, origenLat, destinoLon, destinoLat, OsrmClient.TIMEOUT_POR_DEFECTO_MS);
    }

    @Override
    public OsrmClient.Ruta calcular(double origenLon, double origenLat, double destinoLon, double destinoLat,
                                     long timeoutMs) throws IOException, InterruptedException {
        if (Thread.currentThread().isInterrupted()) throw new InterruptedException("Ruta interrumpida");
        if (timeoutMs <= 0) throw new OsrmClient.PlazoAgotadoException("Se agoto el tiempo disponible");
        try (Connection conn = DataSourceProvider.get().getConnection();
             PreparedStatement ps = conn.prepareStatement(SQL_RUTA)) {
            ps.setQueryTimeout((int) Math.min(Integer.MAX_VALUE, Math.max(1, (timeoutMs + 999) / 1000)));
            ps.setDouble(1, origenLon);
            ps.setDouble(2, origenLat);
            ps.setDouble(3, destinoLon);
            ps.setDouble(4, destinoLat);
            ps.setString(5, criterio.codigo);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) throw new OsrmClient.SinRutaException("No hay camino transitable en el grafo");
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
                return new OsrmClient.Ruta(metros, segundos, geometria, ajusteO, ajusteD);
            }
        } catch (SQLException ex) {
            if ("57014".equals(ex.getSQLState())) {
                throw new OsrmClient.PlazoAgotadoException("pgRouting supero el tiempo disponible");
            }
            throw new IOException("No se pudo consultar pgRouting", ex);
        }
    }
}
