package uy.edu.fing.geotravel.eta;

import java.io.IOException;

/** Se agotó el tiempo disponible para calcular la ruta. */
public class PlazoAgotadoException extends IOException {

    public PlazoAgotadoException(String mensaje) {
        super(mensaje);
    }
}
