package uy.edu.fing.geotravel.mapa;

import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Rectángulo visible del mapa, para los listados "a demanda" (zonas, recursos, ...): en vez de
 * devolver todos los objetos, se devuelven solo los que caen en lo que el usuario está mirando,
 * hasta un límite.
 *
 * Formato del parámetro: bbox=oeste,sur,este,norte en lon/lat (EPSG:4326), que es lo que da
 * Leaflet con map.getBounds().toBBoxString().
 *
 * La base guarda en EPSG:32721 (UTM 21S), que solo tiene sentido en Uruguay y alrededores. Por
 * eso el rectángulo se recorta a la extensión del país antes de transformarlo: un pedido con el
 * mapa muy alejado (medio continente a la vista) no rompe ST_Transform y se resuelve igual con
 * el índice GiST.
 */
public final class Bbox {

    /** Extensión aproximada de Uruguay en lon/lat, con un margen. */
    private static final double OESTE_UY = -58.6, SUR_UY = -35.1, ESTE_UY = -53.0, NORTE_UY = -30.0;

    public static final int LIMITE_POR_DEFECTO = 500;
    public static final int LIMITE_MAXIMO = 2000;

    /** Filtro SQL sobre la columna geom (usa el índice GiST). Lleva 4 parámetros: ver {@link #enlazar}. */
    public static final String FILTRO = "geom && ST_Transform(ST_MakeEnvelope(?, ?, ?, ?, 4326), 32721)";

    private final double oeste, sur, este, norte;

    private Bbox(double oeste, double sur, double este, double norte) {
        this.oeste = oeste;
        this.sur = sur;
        this.este = este;
        this.norte = norte;
    }

    /**
     * @param texto "oeste,sur,este,norte" en lon/lat
     * @throws IllegalArgumentException con un mensaje listo para el usuario si el formato no es válido
     */
    public static Bbox parse(String texto) {
        String[] partes = texto.split(",");
        if (partes.length != 4) {
            throw new IllegalArgumentException("bbox debe tener 4 valores: oeste,sur,este,norte");
        }
        double[] v = new double[4];
        for (int i = 0; i < 4; i++) {
            try {
                v[i] = Double.parseDouble(partes[i].trim());
            } catch (NumberFormatException e) {
                throw new IllegalArgumentException("bbox tiene un valor que no es un número: " + partes[i].trim());
            }
            if (!Double.isFinite(v[i])) {
                throw new IllegalArgumentException("bbox tiene un valor no válido");
            }
        }
        if (v[0] > v[2] || v[1] > v[3]) {
            throw new IllegalArgumentException("bbox: oeste debe ser menor que este y sur menor que norte");
        }
        return new Bbox(Math.max(v[0], OESTE_UY), Math.max(v[1], SUR_UY), Math.min(v[2], ESTE_UY), Math.min(v[3], NORTE_UY));
    }

    /** true si el rectángulo, recortado a Uruguay, quedó vacío (el usuario mira otro país). */
    public boolean vacio() {
        return oeste >= este || sur >= norte;
    }

    /** Enlaza los 4 parámetros de {@link #FILTRO} a partir de la posición {@code desde}; devuelve la siguiente libre. */
    public int enlazar(PreparedStatement ps, int desde) throws SQLException {
        ps.setDouble(desde, oeste);
        ps.setDouble(desde + 1, sur);
        ps.setDouble(desde + 2, este);
        ps.setDouble(desde + 3, norte);
        return desde + 4;
    }

    /**
     * Cuerpo de respuesta común de los listados a demanda:
     * {items: [...], total: cuántos hay en el rectángulo, truncado: si quedaron afuera por el límite}.
     */
    public static Map<String, Object> resultado(List<?> items, int total) {
        Map<String, Object> r = new LinkedHashMap<>();
        r.put("items", items);
        r.put("total", total);
        r.put("truncado", total > items.size());
        return r;
    }

    /** Límite pedido, acotado a [1, LIMITE_MAXIMO]; sin pedido, LIMITE_POR_DEFECTO. */
    public static int limite(Integer pedido) {
        if (pedido == null) {
            return LIMITE_POR_DEFECTO;
        }
        if (pedido < 1) {
            throw new IllegalArgumentException("limit debe ser mayor que 0");
        }
        return Math.min(pedido, LIMITE_MAXIMO);
    }

    /** Parse the optional query parameter before applying the shared limit rules. */
    public static int limiteDesdeTexto(String pedido) {
        if (pedido == null) {
            return LIMITE_POR_DEFECTO;
        }
        try {
            return limite(Integer.valueOf(pedido.trim()));
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException("limit debe ser un entero");
        }
    }
}
