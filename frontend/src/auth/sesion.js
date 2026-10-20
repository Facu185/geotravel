/**
 * Token de la sesión del administrador. Se guarda en sessionStorage: dura mientras la pestaña
 * esté abierta y no pasa a otras pestañas. El acceso va con try/catch porque el navegador puede
 * bloquear el almacenamiento (modo privado); en ese caso la sesión queda solo en memoria.
 */
const CLAVE = "urbansafe.token";
const EVENTO_VENCIDA = "urbansafe:sesion-vencida";

let enMemoria = null;

export function obtenerToken() {
  try {
    return sessionStorage.getItem(CLAVE) ?? enMemoria;
  } catch {
    return enMemoria;
  }
}

export function guardarToken(token) {
  enMemoria = token;
  try {
    sessionStorage.setItem(CLAVE, token);
  } catch {
    // sin almacenamiento: queda en memoria
  }
}

/** Borra el token (al salir, o cuando el backend lo rechazó). */
export function borrarToken() {
  enMemoria = null;
  try {
    sessionStorage.removeItem(CLAVE);
  } catch {
    // nada que borrar
  }
}

/** El backend rechazó el token (venció o se reinició): se borra y se avisa a la aplicación. */
export function sesionVencida() {
  borrarToken();
  window.dispatchEvent(new Event(EVENTO_VENCIDA));
}

export { EVENTO_VENCIDA };
