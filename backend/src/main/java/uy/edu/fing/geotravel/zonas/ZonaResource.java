package uy.edu.fing.geotravel.zonas;

import uy.edu.fing.geotravel.db.DataSourceProvider;

import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Módulo Zonas (dueño: P3).
 * GET /api/zonas -> lista de zonas con la geometría como GeoJSON (ST_AsGeoJSON),
 * lista para consumir directo desde Leaflet/OpenLayers.
 *
 * Punto de partida: agregar acá POST/PUT/DELETE para el ABM completo, y la
 * validación de no-solapamiento (ST_Overlaps) antes de insertar/actualizar
 * -- ver el trigger comentado en db/migrations/V1__init.sql como alternativa
 * a validarlo acá.
 */
@Path("/zonas")
public class ZonaResource {

    private static final String SELECT_ALL =
            "SELECT id, nombre, descripcion, nivel_atractivo, observaciones, "
          + "       ST_AsGeoJSON(geom) AS geom_json "
          + "FROM zona_turistica ORDER BY id";

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public List<Map<String, Object>> listar() throws SQLException {
        List<Map<String, Object>> zonas = new ArrayList<>();
        try (Connection conn = DataSourceProvider.get().getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(SELECT_ALL)) {

            while (rs.next()) {
                Map<String, Object> zona = new LinkedHashMap<>();
                zona.put("id", rs.getInt("id"));
                zona.put("nombre", rs.getString("nombre"));
                zona.put("descripcion", rs.getString("descripcion"));
                zona.put("nivelAtractivo", rs.getInt("nivel_atractivo"));
                zona.put("observaciones", rs.getString("observaciones"));
                zona.put("geom", rs.getString("geom_json")); // GeoJSON como string
                zonas.add(zona);
            }
        }
        return zonas;
    }
}
