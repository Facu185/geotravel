import { useEffect } from "react";
import L from "leaflet";
import { useMap } from "react-leaflet";

/**
 * Lleva el mapa hasta una geometría (por ejemplo, la zona o el recurso que se eligió en la lista
 * del panel). Con la carga a demanda, lo que se elige puede no estar en pantalla.
 *
 * Va DENTRO del mapa. "objetivo" es { geom: GeoJSON en lon/lat } y se reenfoca cada vez que
 * cambia el objeto (aunque sea la misma geometría). Deja lugar para el panel: a la izquierda en
 * escritorio, abajo en pantallas chicas (ver PaginaMapa).
 */
export default function Enfocar({ objetivo, zoomMaximo = 17 }) {
  const map = useMap();

  useEffect(() => {
    if (!objetivo?.geom) return;
    const limites = L.geoJSON(objetivo.geom).getBounds();
    if (!limites.isValid()) return;
    const escritorio = window.matchMedia("(min-width: 800px)").matches;
    const margen = escritorio
      ? { paddingTopLeft: [390, 32], paddingBottomRight: [32, 32] }
      : { paddingTopLeft: [16, 16], paddingBottomRight: [16, Math.round(window.innerHeight * 0.46) + 8] };
    map.flyToBounds(limites, { ...margen, maxZoom: zoomMaximo, duration: 0.6 });
  }, [map, objetivo, zoomMaximo]);

  return null;
}
