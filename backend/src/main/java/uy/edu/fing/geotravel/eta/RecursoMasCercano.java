package uy.edu.fing.geotravel.eta;

import com.fasterxml.jackson.databind.ObjectMapper;

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
 * El recurso más cercano a un incidente POR LAS CALLES, con su ruta. Endpoint:
 * GET /eta/incidentes/{id}/recurso-mas-cercano.
 *
 * "Más cercano" no es lo mismo en línea recta que por las calles: un recurso a 300 m al otro lado de un río, de una
 * avenida sin cruce o contra una mano única puede tardar más que otro a 800 m. Por eso se hace en dos pasos:
 *   1. PostGIS elige los N recursos más cercanos en línea recta (operador <->, que usa el índice espacial; por defecto
 *      solo los que están disponibles). El incidente puede ser un punto, una línea o un polígono: la distancia es a su
 *      geometría y el destino de la ruta es el punto del incidente más próximo a cada recurso (ST_ClosestPoint).
 *   2. pgRouting calcula la ruta de cada uno (el mismo RutaService que el tiempo de llegada y la consulta 3) y gana el
 *      de menor tiempo; si empatan, el de menor distancia. Se informan también los otros, con su tiempo.
 *
 * Los N recursos se evalúan de a uno y con un plazo total: si el motor no responde no se insiste con el resto.
 */
public class RecursoMasCercano {

    public static final int CANDIDATOS_DEFECTO = 5;
    public static final int CANDIDATOS_MAXIMO = 10;
    private static final long PLAZO_TOTAL_NANOS = TimeUnit.SECONDS.toNanos(25);

    private static final ObjectMapper JSON = new ObjectMapper();

    private static final String SQL_INCIDENTE =
            "SELECT id, titulo, tipo_incidente, estado, ST_AsGeoJSON(ST_Transform(geom, 4326), 6) AS geom " +
            "FROM incidente WHERE id = ?";

    private static final String SQL_CANDIDATOS =
            "SELECT r.id, r.identificacion, r.nombre, r.tipo, r.estado_operativo, " +
            "       ST_AsGeoJSON(ST_Transform(r.geom, 4326), 6) AS geom, " +
            "       ST_Distance(r.geom, i.geom) AS distancia_directa_m, " +
            "       ST_X(ST_Transform(r.geom, 4326)) AS origen_lon, ST_Y(ST_Transform(r.geom, 4326)) AS origen_lat, " +
            "       ST_X(ST_Transform(ST_ClosestPoint(i.geom, r.geom), 4326)) AS destino_lon, " +
            "       ST_Y(ST_Transform(ST_ClosestPoint(i.geom, r.geom), 4326)) AS destino_lat " +
            "FROM incidente i, recurso r " +
            "WHERE i.id = ? ";

    private final RutaService rutas;

    public RecursoMasCercano(RutaService rutas) {
        this.rutas = rutas;
    }

    /** Respuesta lista para enviar: el código HTTP y el cuerpo JSON. */
    public static final class Respuesta {
        public final int estado;
        public final Map<String, Object> cuerpo;

        Respuesta(int estado, Map<String, Object> cuerpo) {
            this.estado = estado;
            this.cuerpo = cuerpo;
        }

        static Respuesta error(int estado, String mensaje) {
            Map<String, Object> cuerpo = new LinkedHashMap<>();
            cuerpo.put("error", mensaje);
            return new Respuesta(estado, cuerpo);
        }
    }

    /** Un recurso candidato: lo que se informa de él y los extremos para pedirle la ruta. */
    static final class Candidato {
        final int id;
        final Map<String, Object> datos;
        final RutaService.Extremos extremos;

        Candidato(int id, Map<String, Object> datos, RutaService.Extremos extremos) {
            this.id = id;
            this.datos = datos;
            this.extremos = extremos;
        }
    }

    /** Lo que salió de evaluar a los candidatos. */
    static final class Evaluacion {
        /** Uno por candidato, en el orden de cercanía en línea recta, con el estado de su ruta. */
        final List<Map<String, Object>> evaluados = new ArrayList<>();
        Candidato elegido;
        Ruta ruta;
        boolean motorCaido;
        boolean plazoAgotado;
    }

    /** @throws IllegalArgumentException si no es un entero entre 1 y CANDIDATOS_MAXIMO; null/vacío = el valor por defecto */
    public static int candidatos(String valor) {
        if (valor == null || valor.trim().isEmpty()) {
            return CANDIDATOS_DEFECTO;
        }
        int n;
        try {
            n = Integer.parseInt(valor.trim());
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException("candidatos tiene que ser un numero entero");
        }
        if (n < 1 || n > CANDIDATOS_MAXIMO) {
            throw new IllegalArgumentException("candidatos tiene que estar entre 1 y " + CANDIDATOS_MAXIMO);
        }
        return n;
    }

    public Respuesta buscar(Connection conexion, int incidenteId, boolean soloDisponibles, int cantidad)
            throws SQLException, IOException {

        Map<String, Object> incidente = new LinkedHashMap<>();
        try (PreparedStatement ps = conexion.prepareStatement(SQL_INCIDENTE)) {
            ps.setInt(1, incidenteId);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) {
                    return Respuesta.error(404, "El incidente no existe");
                }
                incidente.put("id", rs.getInt("id"));
                incidente.put("titulo", rs.getString("titulo"));
                incidente.put("tipoIncidente", rs.getString("tipo_incidente"));
                incidente.put("estado", rs.getString("estado"));
                incidente.put("geom", JSON.readTree(rs.getString("geom")));
            }
        }

        List<Candidato> candidatos = new ArrayList<>();
        String sql = SQL_CANDIDATOS + (soloDisponibles ? "AND r.estado_operativo = 'Disponible' " : "")
                + "ORDER BY r.geom <-> i.geom LIMIT ?";
        try (PreparedStatement ps = conexion.prepareStatement(sql)) {
            ps.setInt(1, incidenteId);
            ps.setInt(2, cantidad);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> datos = new LinkedHashMap<>();
                    datos.put("id", rs.getInt("id"));
                    datos.put("identificacion", rs.getString("identificacion"));
                    datos.put("nombre", rs.getString("nombre"));
                    datos.put("tipo", rs.getString("tipo"));
                    datos.put("estadoOperativo", rs.getString("estado_operativo"));
                    datos.put("geom", JSON.readTree(rs.getString("geom")));
                    double directa = rs.getDouble("distancia_directa_m");
                    candidatos.add(new Candidato(rs.getInt("id"), datos, new RutaService.Extremos(
                            rs.getDouble("origen_lon"), rs.getDouble("origen_lat"),
                            rs.getDouble("destino_lon"), rs.getDouble("destino_lat"), directa)));
                }
            }
        }
        if (candidatos.isEmpty()) {
            return Respuesta.error(422, soloDisponibles
                    ? "No hay recursos disponibles para atender este incidente"
                    : "No hay recursos cargados");
        }

        Evaluacion ev = evaluar(candidatos, rutas, PLAZO_TOTAL_NANOS);
        if (ev.elegido == null) {
            Respuesta r;
            if (ev.motorCaido) {
                r = Respuesta.error(503, "No se pudo consultar el motor de rutas");
            } else if (ev.plazoAgotado) {
                r = Respuesta.error(503, "El calculo de rutas supero el tiempo disponible: intente de nuevo");
            } else {
                r = Respuesta.error(422, "Ninguno de los " + candidatos.size() + " recursos mas cercanos tiene ruta por calles hasta el "
                        + "incidente (estan a mas de 500 m de una calle o fuera de la red vial)");
            }
            r.cuerpo.put("alternativas", ev.evaluados);
            return r;
        }

        Ruta ruta = ev.ruta;
        Map<String, Object> rutaJson = new LinkedHashMap<>();
        rutaJson.put("distanciaMetros", Math.round(ruta.distanciaMetros));
        rutaJson.put("duracionSegundos", Math.round(ruta.duracionSegundos));
        rutaJson.put("tiempoEstimadoMinutos", ruta.minutosRedondeados());
        rutaJson.put("distanciaDirectaMetros", Math.round(ev.elegido.extremos.distanciaDirectaM));
        rutaJson.put("geometriaRuta", ruta.geometriaRuta);
        rutaJson.put("calles", ruta.calles);
        rutaJson.put("ajusteOrigenMetros", ruta.ajusteOrigenMetros == null ? null : Math.round(ruta.ajusteOrigenMetros));
        rutaJson.put("ajusteDestinoMetros", ruta.ajusteDestinoMetros == null ? null : Math.round(ruta.ajusteDestinoMetros));
        rutaJson.put("advertencia", RutaService.advertencia(ruta));

        Map<String, Object> cuerpo = new LinkedHashMap<>();
        cuerpo.put("incidente", incidente);
        cuerpo.put("recurso", ev.elegido.datos);
        cuerpo.put("ruta", rutaJson);
        cuerpo.put("criterio", "Menor tiempo por calles entre los " + candidatos.size() + " recursos"
                + (soloDisponibles ? " disponibles" : "") + " mas cercanos en linea recta");
        cuerpo.put("soloDisponibles", soloDisponibles);
        cuerpo.put("candidatosEvaluados", candidatos.size());
        cuerpo.put("alternativas", ev.evaluados);
        cuerpo.put("motor", rutas.nombreMotor());
        cuerpo.put("aclaracion", "Estimacion sin trafico en tiempo real");
        return new Respuesta(200, cuerpo);
    }

    /**
     * Pide la ruta de cada candidato, de a uno y dentro de un plazo total, y elige la de menor tiempo (a igual tiempo, la de
     * menor distancia; a igual distancia, el más cercano en línea recta). No toca la base: sirve para probar con un motor falso.
     */
    static Evaluacion evaluar(List<Candidato> candidatos, RutaService servicio, long plazoNanos) {
        Evaluacion ev = new Evaluacion();
        long inicio = System.nanoTime();
        Ruta mejor = null;

        for (Candidato c : candidatos) {
            Map<String, Object> fila = new LinkedHashMap<>();
            fila.put("recursoId", c.id);
            fila.put("identificacion", c.datos.get("identificacion"));
            fila.put("tipo", c.datos.get("tipo"));
            fila.put("estadoOperativo", c.datos.get("estadoOperativo"));
            fila.put("distanciaDirectaMetros", Math.round(c.extremos.distanciaDirectaM));
            ev.evaluados.add(fila);

            if (ev.motorCaido) {
                fila.put("estadoRuta", "no_consultado");
                continue;
            }
            long restanteMs = TimeUnit.NANOSECONDS.toMillis(plazoNanos - (System.nanoTime() - inicio));
            if (restanteMs <= 0) {
                ev.plazoAgotado = true;
                fila.put("estadoRuta", RutaService.Estado.PLAZO_AGOTADO.codigo);
                continue;
            }

            RutaService.Resultado r = servicio.intentar(c.extremos, Math.min(RutaService.TIMEOUT_POR_DEFECTO_MS, restanteMs));
            fila.put("estadoRuta", r.estado.codigo);
            if (r.estado == RutaService.Estado.DISPONIBLE) {
                fila.put("distanciaMetros", Math.round(r.ruta.distanciaMetros));
                fila.put("duracionSegundos", Math.round(r.ruta.duracionSegundos));
                fila.put("tiempoEstimadoMinutos", r.ruta.minutosRedondeados());
                if (mejor == null || gana(r.ruta, mejor)) {
                    mejor = r.ruta;
                    ev.elegido = c;
                    ev.ruta = r.ruta;
                }
            } else {
                fila.put("mensaje", r.mensaje);
                if (r.estado == RutaService.Estado.PLAZO_AGOTADO) {
                    ev.plazoAgotado = true;
                }
                if (r.motorCaido) {
                    ev.motorCaido = true;
                }
            }
        }

        for (Map<String, Object> fila : ev.evaluados) {
            fila.put("elegido", ev.elegido != null && fila.get("recursoId").equals(ev.elegido.id));
        }
        return ev;
    }

    /** Menor duración; a igual duración, menor distancia. Con empate total gana el que ya estaba (el más cercano en línea recta). */
    private static boolean gana(Ruta nueva, Ruta actual) {
        if (nueva.duracionSegundos != actual.duracionSegundos) {
            return nueva.duracionSegundos < actual.duracionSegundos;
        }
        return nueva.distanciaMetros < actual.distanciaMetros;
    }
}
