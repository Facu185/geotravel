package uy.edu.fing.geotravel.eta;

import com.fasterxml.jackson.databind.JsonNode;

/** Una ruta por calles entre dos puntos: distancia, duración, trazado y las calles por las que pasa. */
public class Ruta {

    public final double distanciaMetros;
    public final double duracionSegundos;
    /** El trazado como GeoJSON LineString (lon/lat); null si el motor no lo informó. */
    public final JsonNode geometriaRuta;
    /** Metros entre el recurso y la calle a la que se enganchó la ruta; null si no se informó. */
    public final Double ajusteOrigenMetros;
    /** Metros entre el incidente y la calle a la que se enganchó la ruta; null si no se informó. */
    public final Double ajusteDestinoMetros;
    /** Las calles del recorrido, en orden: [{"calle": "...", "metros": n}]; null si no se informó. */
    public final JsonNode calles;

    public Ruta(double distanciaMetros, double duracionSegundos) {
        this(distanciaMetros, duracionSegundos, null);
    }

    public Ruta(double distanciaMetros, double duracionSegundos, JsonNode geometriaRuta) {
        this(distanciaMetros, duracionSegundos, geometriaRuta, null, null);
    }

    public Ruta(double distanciaMetros, double duracionSegundos, JsonNode geometriaRuta,
                Double ajusteOrigenMetros, Double ajusteDestinoMetros) {
        this(distanciaMetros, duracionSegundos, geometriaRuta, ajusteOrigenMetros, ajusteDestinoMetros, null);
    }

    public Ruta(double distanciaMetros, double duracionSegundos, JsonNode geometriaRuta,
                Double ajusteOrigenMetros, Double ajusteDestinoMetros, JsonNode calles) {
        this.distanciaMetros = distanciaMetros;
        this.duracionSegundos = duracionSegundos;
        this.geometriaRuta = geometriaRuta;
        this.ajusteOrigenMetros = ajusteOrigenMetros;
        this.ajusteDestinoMetros = ajusteDestinoMetros;
        this.calles = calles;
    }

    public long minutosRedondeados() {
        return (long) Math.ceil(duracionSegundos / 60.0);
    }
}
