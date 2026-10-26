import L from "leaflet";
import { COLOR_ESTADO_RECURSO, TIPOS_RECURSO, nombreTipoRecurso } from "./colores.js";

/**
 * Íconos de los recursos de emergencia. Convención (la misma para el mapa de administración,
 * el mapa público y GeoServer, ver docs/ICONOS.md):
 *   - la FORMA dice el tipo de recurso (ambulancia, bomberos, patrulla, centro de atención, otro);
 *   - el COLOR dice el estado operativo (disponible, en servicio, fuera de servicio).
 *
 * Los dibujos son archivos SVG blancos en frontend/public/iconos/ (recurso-<tipo>.svg e
 * incidente.svg). Se dibujan sobre un círculo del color del estado. Son los mismos archivos que se
 * pueden subir a GeoServer (ExternalGraphic en el SLD) para que ambos mapas se vean igual.
 */

const BASE = import.meta.env.BASE_URL;
const COLOR_DESCONOCIDO = "#555555";

/** Un tipo fuera de la lista (datos viejos) se dibuja como "otro". */
const tipoConocido = (tipo) => (TIPOS_RECURSO.includes(tipo) ? tipo : "otro");

export const urlIconoRecurso = (tipo) => `${BASE}iconos/recurso-${tipoConocido(tipo)}.svg`;
export const urlIconoIncidente = `${BASE}iconos/incidente.svg`;
export const colorEstadoRecurso = (estado) => COLOR_ESTADO_RECURSO[estado] ?? COLOR_DESCONOCIDO;

const TAMANO_MARCADOR = 30;
const cache = new Map();

/**
 * Ícono de Leaflet (L.divIcon) de un recurso, para usar en un <Marker icon={...}>. Se guarda uno
 * por combinación tipo/estado/resaltado: con cientos de recursos en pantalla no se crean de nuevo.
 * `resaltado` marca el recurso que se está eligiendo o editando.
 */
export function iconoRecurso(tipo, estado, { resaltado = false } = {}) {
  const clave = `${tipoConocido(tipo)}|${estado}|${resaltado}`;
  if (!cache.has(clave)) {
    cache.set(
      clave,
      L.divIcon({
        className: "marcador-recurso",
        // Solo se interpolan valores propios (una URL de la lista cerrada y un color de la tabla).
        html:
          `<span class="insignia-icono${resaltado ? " insignia-icono--resaltado" : ""}" style="--color:${colorEstadoRecurso(estado)}">` +
          `<img src="${urlIconoRecurso(tipo)}" alt="" draggable="false"></span>`,
        iconSize: [TAMANO_MARCADOR, TAMANO_MARCADOR],
        iconAnchor: [TAMANO_MARCADOR / 2, TAMANO_MARCADOR / 2],
        tooltipAnchor: [TAMANO_MARCADOR / 2, 0],
      }),
    );
  }
  return cache.get(clave);
}

/** El mismo ícono para listas y leyendas (fuera del mapa). `chico` lo achica para las filas. */
export function IconoRecurso({ tipo, estado, chico = false }) {
  return (
    <span
      className={chico ? "insignia-icono insignia-icono--chico" : "insignia-icono"}
      style={{ "--color": colorEstadoRecurso(estado) }}
      role="img"
      aria-label={estado ? `${nombreTipoRecurso(tipo)} (${estado})` : nombreTipoRecurso(tipo)}
    >
      <img src={urlIconoRecurso(tipo)} alt="" draggable="false" />
    </span>
  );
}
