package uy.edu.fing.geotravel.eta;

import java.io.IOException;

/** No hay camino entre los dos puntos (o alguno queda fuera de la red vial). */
public class SinRutaException extends IOException {

    public SinRutaException(String mensaje) {
        super(mensaje);
    }
}
