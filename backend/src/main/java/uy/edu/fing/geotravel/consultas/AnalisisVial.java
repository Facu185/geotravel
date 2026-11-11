package uy.edu.fing.geotravel.consultas;

import com.fasterxml.jackson.databind.ObjectMapper;
import uy.edu.fing.geotravel.eta.Criterio;
import uy.edu.fing.geotravel.eta.Ruta;
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
 * Consulta 3: los recursos operativos mas cercanos a un incidente, con su distancia directa y, a pedido, la ruta
 * por calles mas corta (pgRouting, criterio distancia). Endpoint: GET /consultas/recursos-cercanos/{id}/analisis-vial.
 *
 * Los N recursos mas cercanos se eligen con PostGIS, ordenando por el operador de vecino mas cercano (<->, usa el
 * indice GiST), medido hasta la geometria del incidente (Point, LineString o Polygon). No hay radio ni buffer: la
 * cantidad la elige quien consulta. Distancia directa: ST_Distance en EPSG:32721 (metros).
 * Primero se filtra con PostGIS y recien despues se consulta el motor vial, solo para los
 * RUTAS_MAXIMAS recursos mas cercanos.
 */
public class AnalisisVial {

    public static final int LIMITE_DEFECTO = 5;
    public static final int LIMITE_MAXIMO = 10;
    /** Tope de recursos para los que se piden rutas al motor: protege a la base de ráfagas de pedidos. */
    public static final int RUTAS_MAXIMAS = 5;
    private static final long PLAZO_RUTAS_NANOS = TimeUnit.SECONDS.toNanos(25);

    private static final ObjectMapper JSON = new ObjectMapper();

    private static final String SQL_INCIDENTE =
            "SELECT i.id, i.titulo, i.tipo_incidente, i.estado, " +
            "       ST_AsGeoJSON(ST_Transform(i.geom, 4326), 6) AS geom " +
            "FROM incidente i WHERE i.id = ?";

    private static final String SQL_RECURSOS =
            "SELECT r.id, r.identificacion, r.tipo, r.estado_operativo, " +
            "       ST_AsGeoJSON(ST_Transform(r.geom, 4326), 6) AS geom, " +
            "       ST_Distance(r.geom, i.geom) AS distancia_directa_m, " +
            "       ST_X(ST_Transform(r.geom, 4326)) AS origen_lon, " +
            "       ST_Y(ST_Transform(r.geom, 4326)) AS origen_lat, " +
            "       ST_X(ST_Transform(ST_ClosestPoint(i.geom, r.geom), 4326)) AS destino_lon, " +
            "       ST_Y(ST_Transform(ST_ClosestPoint(i.geom, r.geom), 4326)) AS destino_lat " +
            "FROM incidente i CROSS JOIN recurso r " +
            "WHERE i.id = ? ";

    private final RutaService rutas;

    public AnalisisVial(RutaService rutas) {
        this.rutas = rutas;
    }

    /** Parametros ya validados. */
    public static final class Parametros {
        public final int limite;

        Parametros(int limite) {
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

    /** @throws IllegalArgumentException si el limite esta fuera de rango */
    public static Parametros validar(Integer limite) {
        int cantidad = limite == null ? LIMITE_DEFECTO : limite;
        if (cantidad < 1 || cantidad > LIMITE_MAXIMO) {
            throw new IllegalArgumentException("limite tiene que estar entre 1 y " + LIMITE_MAXIMO);
        }
        return new Parametros(cantidad);
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
        respuesta.put("soloDisponibles", soloDisponibles);
        respuesta.put("conRutas", conRutas);

        try (PreparedStatement ps = conexion.prepareStatement(SQL_INCIDENTE)) {
            ps.setInt(1, incidenteId);
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
            }
        }

        List<Candidato> candidatos = new ArrayList<>();
        String sql = SQL_RECURSOS
                + (soloDisponibles ? "AND r.estado_operativo = 'Disponible' " : "")
                + "ORDER BY r.geom <-> i.geom, r.id LIMIT ?";
        try (PreparedStatement ps = conexion.prepareStatement(sql)) {
            ps.setInt(1, incidenteId);
            ps.setInt(2, p.limite);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    candidatos.add(candidatoDe(rs));
                }
            }
        }

        respuesta.put("rutasMaximas", RUTAS_MAXIMAS);

        int calculadas = 0;
        if (conRutas) {
            calculadas = calcularRutas(candidatos, System.nanoTime() + PLAZO_RUTAS_NANOS);
        }
        respuesta.put("rutasDisponibles", calculadas);
        respuesta.put("recursoMasCercanoId", recursoMasCercanoPorCalles(candidatos));

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
        item.put("estadoRuta", "no_calculada");

        RutaService.Extremos extremos = new RutaService.Extremos(
                rs.getDouble("origen_lon"), rs.getDouble("origen_lat"),
                rs.getDouble("destino_lon"), rs.getDouble("destino_lat"), directa);
        return new Candidato(item, extremos);
    }

    /**
     * Pide la ruta de los primeros RUTAS_MAXIMAS candidatos, de a uno.
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
            long restanteMs = (limiteNanos - System.nanoTime()) / 1_000_000;
            if (restanteMs <= 0) {
                marcarPlazo(c);
                continue;
            }

            RutaService.Resultado r = rutas.intentar(c.extremos,
                    Math.min(RutaService.TIMEOUT_POR_DEFECTO_MS, restanteMs), Criterio.DISTANCIA);
            switch (r.estado) {
                case DISPONIBLE:
                    completar(c, r.ruta);
                    obtenidas++;
                    break;
                case SIN_RUTA:
                    c.item.put("estadoRuta", r.estado.codigo);
                    c.item.put("mensajeRuta", "Ruta no disponible: " + r.mensaje);
                    break;
                case PLAZO_AGOTADO:
                    marcarPlazo(c);
                    limiteNanos = System.nanoTime();
                    break;
                default:
                    motorCaido = r.motorCaido;
                    marcarError(c, r.mensaje);
                    break;
            }
        }
        return obtenidas;
    }

    private static void marcarPlazo(Candidato c) {
        c.item.put("estadoRuta", RutaService.Estado.PLAZO_AGOTADO.codigo);
        c.item.put("mensajeRuta", "Ruta no disponible: se agoto el tiempo maximo para calcular rutas");
    }

    private static void marcarError(Candidato c, String mensaje) {
        c.item.put("estadoRuta", RutaService.Estado.ERROR.codigo);
        c.item.put("mensajeRuta", "Ruta no disponible: " + mensaje);
    }

    private static void completar(Candidato c, Ruta ruta) {
        Map<String, Object> item = c.item;
        item.put("estadoRuta", RutaService.Estado.DISPONIBLE.codigo);
        item.put("distanciaViaM", Math.round(ruta.distanciaMetros));
        item.put("duracionS", Math.round(ruta.duracionSegundos));
        item.put("tiempoEstimadoMinutos", ruta.minutosRedondeados());
        item.put("geometriaRuta", ruta.geometriaRuta);
        item.put("calles", ruta.calles);
        item.put("ajusteOrigenM", ruta.ajusteOrigenMetros == null ? null : Math.round(ruta.ajusteOrigenMetros));
        item.put("ajusteDestinoM", ruta.ajusteDestinoMetros == null ? null : Math.round(ruta.ajusteDestinoMetros));
        item.put("advertencia", RutaService.advertencia(ruta));
    }

    /**
     * Id del recurso con menor distancia por calles entre los que tienen ruta (a igual distancia, el de menor duracion;
     * si tambien empatan, el primero, que es el mas cercano en linea recta); null si ninguno la tiene.
     */
    static Integer recursoMasCercanoPorCalles(List<Candidato> candidatos) {
        Integer mejor = null;
        long menorDistancia = Long.MAX_VALUE;
        long menorDuracion = Long.MAX_VALUE;
        for (Candidato c : candidatos) {
            Object distancia = c.item.get("distanciaViaM");
            Object duracion = c.item.get("duracionS");
            if (!(distancia instanceof Long) || !(duracion instanceof Long)) {
                continue;
            }
            long d = (Long) distancia;
            long t = (Long) duracion;
            if (d < menorDistancia || (d == menorDistancia && t < menorDuracion)) {
                menorDistancia = d;
                menorDuracion = t;
                mejor = (Integer) c.item.get("recursoId");
            }
        }
        return mejor;
    }
}
