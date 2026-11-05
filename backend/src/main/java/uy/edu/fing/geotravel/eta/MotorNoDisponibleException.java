package uy.edu.fing.geotravel.eta;

import java.io.IOException;

/** El motor de rutas no puede calcular rutas (falta la red vial o la función en la base). */
public class MotorNoDisponibleException extends IOException {

    public MotorNoDisponibleException(String mensaje) {
        super(mensaje);
    }
}
