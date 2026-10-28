package uy.edu.fing.geotravel.eta;

/** Criterio que minimiza el motor al calcular una ruta por calles. */
public enum Criterio {
    MAS_RAPIDA("mas_rapida", "Ruta mas rapida (minimiza la duracion estimada)", "OSRM driving (tiempo)"),
    MAS_CORTA("mas_corta", "Ruta mas corta (minimiza la distancia por calles permitidas)", "OSRM propio (distancia)");

    public final String codigo;
    public final String texto;
    public final String motor;

    Criterio(String codigo, String texto, String motor) {
        this.codigo = codigo;
        this.texto = texto;
        this.motor = motor;
    }

    /** Vacio o null equivale a mas_rapida; un valor desconocido devuelve null. */
    public static Criterio desde(String valor) {
        if (valor == null || valor.isBlank()) {
            return MAS_RAPIDA;
        }
        for (Criterio c : values()) {
            if (c.codigo.equalsIgnoreCase(valor.trim())) {
                return c;
            }
        }
        return null;
    }
}
