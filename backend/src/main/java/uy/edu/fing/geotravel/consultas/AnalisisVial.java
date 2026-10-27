package uy.edu.fing.geotravel.consultas;

import com.fasterxml.jackson.databind.ObjectMapper;
import uy.edu.fing.geotravel.eta.OsrmClient;
import uy.edu.fing.geotravel.eta.RutaService;

import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;

/**
 * Consulta 3 ampliada: recursos dentro de un buffer alrededor del incidente, con distancia directa y,
 * a pedido, ruta por calles. Endpoint: GET /consultas/recursos-cercanos/{id}/analisis-vial.
 *
 * Buffer: ST_Buffer(incidente.geom, radio) en EPSG:32721 (metros). Sirve para Point (circulo),
 * LineString (corredor) y Polygon (area extendida). Los recursos se seleccionan con ST_DWithin (usa el
 * indice GiST), que equivale a "el recurso toca el buffer".
 * Distancia directa: ST_Distance entre el recurso y la geometria del incidente, en metros.
 * Primero se filtra con PostGIS y recien despues se consulta el motor vial, solo para los
 * RUTAS_MAXIMAS recursos mas cercanos.
 */
public class AnalisisVial {

    public static final int RADIO_DEFECTO_M = 2000;
    public static final int RADIO_MAXIMO_M = 10000;
    public static final int LIMITE_DEFECTO = 5;
    public static final int LIMITE_MAXIMO = 10;
    /** Tope de recursos para los que se piden rutas al motor: protege a OSRM de ráfagas de pedidos. */
    public static final int RUTAS_MAXIMAS = 5;
    private static final long PLAZO_RUTAS_NANOS = TimeUnit.SECONDS.toNanos(25);

    private static final ObjectMapper JSON = new ObjectMapper();

    private static final String SQL_INCIDENTE =
            "SELECT i.id, i.titulo, i.tipo_incidente, i.estado, " +
            "       ST_AsGeoJSON(ST_Transform(i.geom, 4326), 6) AS geom, " +
            "       ST_AsGeoJSON(ST_Transform(ST_Buffer(i.geom, ?), 4326), 6) AS buffer_geom " +
            "FROM incidente i WHERE i.id = ?";

    private static final String SQL_RECURSOS =
            "SELECT r.id, r.identificacion, r.tipo, r.estado_operativo, " +
            "       ST_AsGeoJSON(ST_Transform(r.geom, 4326), 6) AS geom, " +
            "       ST_Distance(r.geom, i.geom) AS distancia_directa_m, " +
            "       ST_AsGeoJSON(ST_Transform(ST_ShortestLine(r.geom, i.geom), 4326), 6) AS linea_directa, " +
            "       ST_X(ST_Transform(r.geom, 4326)) AS origen_lon, " +
            "       ST_Y(ST_Transform(r.geom, 4326)) AS origen_lat, " +
            "       ST_X(ST_Transform(ST_ClosestPoint(i.geom, r.geom), 4326)) AS destino_lon, " +
            "       ST_Y(ST_Transform(ST_ClosestPoint(i.geom, r.geom), 4326)) AS destino_lat, " +
            "       count(*) OVER () AS total " +
            "FROM incidente i JOIN recurso r ON ST_DWithin(r.geom, i.geom, ?) " +
            "WHERE i.id = ? ";

    private final RutaService rutas;

    public AnalisisVial(RutaService rutas) {
        this.rutas = rutas;
    }

    /** Parametros ya validados. */
    public static final class Parametros {
        public final int radioMetros;
        public final int limite;

        Parametros(int radioMetros, int limite) {
            this.radioMetros = radioMetros;
            this.limite = limite;
        }
    }

    /** Convierte un parametro de consulta a entero; null si no vino. @throws IllegalArgumentException si no es entero */
    public static Integer entero(String nombre, String valor) {
        if (valor == null || valor.trim().isEmpty()) {
            return null;
        }
        try {
            return Integer.valueOf(valor.trim());
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException(nombre + " tiene que ser un numero entero");
        }
    }

    /** @throws IllegalArgumentException si el radio o el limite estan fuera de rango */
    public static Parametros validar(Integer radioMetros, Integer limite) {
        int radio = radioMetros == null ? RADIO_DEFECTO_M : radioMetros;
        if (radio < 1 || radio > RADIO_MAXIMO_M) {
            throw new IllegalArgumentException(
                    "radioMetros tiene que estar entre 1 y " + RADIO_MAXIMO_M + " metros");
        }
        int cantidad = limite == null ? LIMITE_DEFECTO : limite;
        if (cantidad < 1 || cantidad > LIMITE_MAXIMO) {
            throw new IllegalArgumentException("limite tiene que estar entre 1 y " + LIMITE_MAXIMO);
        }
        return new Parametros(radio, cantidad);
    }

    /** Recurso encontrado en el buffer, con lo necesario para pedirle su ruta al motor. */
    static final class Candidato {
        final Map<String, Object> item;
        final RutaService.Extremos extremos;

        Candidato(Map<String, Object> item, RutaService.Extremos extremos) {
            this.item = item;
            this.extremos = extremos;
        }
    }

    /** @return la respuesta, o null si el incidente no existe */
    public Map<String, Object> analizar(Connection conexion, int incidenteId, Parametros p,
                                        boolean soloDisponibles, boolean conRutas)
            throws SQLException, IOException {

        Map<String, Object> respuesta = new LinkedHashMap<>();
        respuesta.put("incidenteId", incidenteId);
        respuesta.put("radioMetros", p.radioMetros);
        respuesta.put("soloDisponibles", soloDisponibles);
        respuesta.put("conRutas", conRutas);

        try (PreparedStatement ps = conexion.prepareStatement(SQL_INCIDENTE)) {
            ps.setInt(1, p.radioMetros);
            ps.setInt(2, incidenteId);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) {
                    return null;
                }
                Map<String, Object> incidente = new LinkedHashMap<>();
                incidente.put("id", rs.getInt("id"));
                incidente.put("titulo", rs.getString("titulo"));
                incidente.put("tipoIncidente", rs.getString("tipo_incidente"));
                incidente.put("estado", rs.getString("estado"));
                incidente.put("geom", rs.getString("geom"));
                respuesta.put("incidente", incidente);
                respuesta.put("bufferGeom", JSON.readTree(rs.getString("buffer_geom")));
            }
        }

        List<Candidato> candidatos = new ArrayList<>();
        int total = 0;
        String sql = SQL_RECURSOS
                + (soloDisponibles ? "AND r.estado_operativo = 'Disponible' " : "")
                + "ORDER BY ST_Distance(r.geom, i.geom), r.id LIMIT ?";
        try (PreparedStatement ps = conexion.prepareStatement(sql)) {
            ps.setInt(1, p.radioMetros);
            ps.setInt(2, incidenteId);
            ps.setInt(3, p.limite);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    total = rs.getInt("total");
                    candidatos.add(candidatoDe(rs));
                }
            }
        }

        respuesta.put("totalEnRadio", total);
        respuesta.put("truncado", total > candidatos.size());
        respuesta.put("criterioRuta", RutaService.CRITERIO);
        respuesta.put("criterioRutaTexto", RutaService.CRITERIO_TEXTO);
        respuesta.put("rutasMaximas", RUTAS_MAXIMAS);

        int calculadas = 0;
        if (conRutas) {
            calculadas = calcularRutas(candidatos, System.nanoTime() + PLAZO_RUTAS_NANOS);
        }
        respuesta.put("rutasDisponibles", calculadas);
        respuesta.put("recursoMasRapidoId", recursoMasRapido(candidatos));

        List<Map<String, Object>> items = new ArrayList<>();
        for (Candidato c : candidatos) {
            items.add(c.item);
        }
        respuesta.put("items", items);
        return respuesta;
    }

    private static Candidato candidatoDe(ResultSet rs) throws SQLException, IOException {
        Map<String, Object> item = new LinkedHashMap<>();
        item.put("recursoId", rs.getInt("id"));
        item.put("identificacion", rs.getString("identificacion"));
        item.put("tipo", rs.getString("tipo"));
        item.put("estadoOperativo", rs.getString("estado_operativo"));
        item.put("geom", rs.getString("geom"));
        double directa = rs.getDouble("distancia_directa_m");
        item.put("distanciaDirectaM", Math.round(directa * 10) / 10.0);
        item.put("lineaDirecta", JSON.readTree(rs.getString("linea_directa")));
        item.put("estadoRuta", "no_calculada");
        item.put("criterioRuta", RutaService.CRITERIO);

        RutaService.Extremos extremos = new RutaService.Extremos(
                rs.getDouble("origen_lon"), rs.getDouble("origen_lat"),
                rs.getDouble("destino_lon"), rs.getDouble("destino_lat"), directa);
        return new Candidato(item, extremos);
    }

    /**
     * Pide la ruta de los primeros RUTAS_MAXIMAS candidatos, de a uno (el OSRM publico limita la frecuencia).
     * Un fallo en un recurso no detiene a los demas; si el motor no responde, no se insiste con el resto.
     *
     * @return cuantas rutas se obtuvieron
     */
    int calcularRutas(List<Candidato> candidatos, long limiteNanos) {
        int obtenidas = 0;
        boolean motorCaido = false;
        int pedidas = 0;

        for (Candidato c : candidatos) {
            if (pedidas >= RUTAS_MAXIMAS) {
                c.item.put("mensajeRuta", "Se calculan las rutas de los " + RUTAS_MAXIMAS + " recursos mas cercanos");
                continue;
            }
            pedidas++;

            if (motorCaido) {
                marcarError(c, "El servicio de rutas no respondio");
                continue;
            }
            if (System.nanoTime() - limiteNanos > 0) {
                marcarError(c, "Se agoto el tiempo maximo para calcular rutas");
                continue;
            }

            RutaService.Resultado r = rutas.intentar(c.extremos);
            switch (r.estado) {
                case DISPONIBLE:
                    completar(c, r.ruta);
                    obtenidas++;
                    break;
                case SIN_RUTA:
                    c.item.put("estadoRuta", r.estado.codigo);
                    c.item.put("mensajeRuta", "Ruta no disponible: " + r.mensaje);
                    break;
                default:
                    motorCaido = r.motorCaido;
                    marcarError(c, r.mensaje);
                    break;
            }
        }
        return obtenidas;
    }

    private static void marcarError(Candidato c, String mensaje) {
        c.item.put("estadoRuta", RutaService.Estado.ERROR.codigo);
        c.item.put("mensajeRuta", "Ruta no disponible: " + mensaje);
    }

    private static void completar(Candidato c, OsrmClient.Ruta ruta) {
        Map<String, Object> item = c.item;
        item.put("estadoRuta", RutaService.Estado.DISPONIBLE.codigo);
        item.put("distanciaViaM", Math.round(ruta.distanciaMetros));
        item.put("duracionS", Math.round(ruta.duracionSegundos));
        item.put("tiempoEstimadoMinutos", ruta.minutosRedondeados());
        item.put("geometriaRuta", ruta.geometriaRuta);
        item.put("ajusteOrigenM", ruta.ajusteOrigenMetros == null ? null : Math.round(ruta.ajusteOrigenMetros));
        item.put("ajusteDestinoM", ruta.ajusteDestinoMetros == null ? null : Math.round(ruta.ajusteDestinoMetros));
        item.put("advertencia", RutaService.advertencia(ruta));
    }

    /** Id del recurso con menor duracion entre los que tienen ruta; null si ninguno la tiene. */
    static Integer recursoMasRapido(List<Candidato> candidatos) {
        Integer mejor = null;
        long menor = Long.MAX_VALUE;
        for (Candidato c : candidatos) {
            Object duracion = c.item.get("duracionS");
            if (duracion instanceof Long && (Long) duracion < menor) {
                menor = (Long) duracion;
                mejor = (Integer) c.item.get("recursoId");
            }
        }
        return mejor;
    }
}
