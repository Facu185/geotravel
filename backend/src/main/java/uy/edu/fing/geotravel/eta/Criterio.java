package uy.edu.fing.geotravel.eta;

/**
 * Qué se minimiza al buscar el camino por calles: el tiempo (el recorrido más rápido) o la distancia (el más corto en metros).
 * Los dos caminos pueden ser distintos: una avenida más larga puede tardar menos, y una mano única obliga a dar vueltas.
 */
public enum Criterio {
    TIEMPO("tiempo"),
    DISTANCIA("distancia");

    /** El valor que entiende la función SQL p2_calcular_ruta y el parámetro "criterio" de la API. */
    public final String codigo;

    Criterio(String codigo) {
        this.codigo = codigo;
    }

    /** @throws IllegalArgumentException si no es "tiempo" ni "distancia"; null o vacío = el valor por defecto */
    public static Criterio de(String valor, Criterio porDefecto) {
        if (valor == null || valor.trim().isEmpty()) {
            return porDefecto;
        }
        for (Criterio c : values()) {
            if (c.codigo.equalsIgnoreCase(valor.trim())) {
                return c;
            }
        }
        throw new IllegalArgumentException("criterio tiene que ser \"tiempo\" o \"distancia\"");
    }
}
