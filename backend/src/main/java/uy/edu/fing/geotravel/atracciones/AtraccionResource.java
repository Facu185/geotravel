package uy.edu.fing.geotravel.atracciones;

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
 * Módulo Atracciones (dueño: P3).
 * GET /api/atracciones -> lista de atracciones con geometría en GeoJSON.
 *
 * Punto de partida: agregar ABM completo, subida de foto (opcional "Fotos") y,
 * más adelante, el endpoint de "puntos más populares" puede vivir acá o en
 * consultas/ConsultaResource.java (dueño: P5) según cómo lo repartan.
 */
@Path("/atracciones")
public class AtraccionResource {

    private static final String SELECT_ALL =
            "SELECT id, nombre, descripcion, clasificacion, foto_url, "
          + "       ST_AsGeoJSON(geom) AS geom_json "
          + "FROM atraccion ORDER BY id";

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public List<Map<String, Object>> listar() throws SQLException {
        List<Map<String, Object>> atracciones = new ArrayList<>();
        try (Connection conn = DataSourceProvider.get().getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(SELECT_ALL)) {

            while (rs.next()) {
                Map<String, Object> atraccion = new LinkedHashMap<>();
                atraccion.put("id", rs.getInt("id"));
                atraccion.put("nombre", rs.getString("nombre"));
                atraccion.put("descripcion", rs.getString("descripcion"));
                atraccion.put("clasificacion", rs.getString("clasificacion"));
                atraccion.put("fotoUrl", rs.getString("foto_url"));
                atraccion.put("geom", rs.getString("geom_json"));
                atracciones.add(atraccion);
            }
        }
        return atracciones;
    }
}
