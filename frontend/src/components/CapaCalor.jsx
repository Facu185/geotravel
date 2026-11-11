import { useEffect } from "react";
import L from "leaflet";
import { useMap } from "react-leaflet";
import { GEOSERVER_WMS_URL } from "./MapView.jsx";

/**
 * Mapa de calor que dibuja GeoServer (transformación vec:Heatmap, ver geoserver/styles/incidentes_calor.sld), pedido como
 * UNA sola imagen de lo que se ve y no en teselas de 256 px.
 *
 * Por qué una imagen y no teselas: GeoServer escala la intensidad de cada imagen que dibuja según su propio máximo. Con
 * teselas, la de un pueblo con 3 incidentes quedaba tan roja como la de la ciudad con 40 y el mapa mentía. En una sola imagen
 * la escala es la misma para todo lo que se ve (la intensidad es relativa a lo visible).
 *
 * La imagen cubre un poco más que la vista (así se puede arrastrar sin ver el borde) y se pide de nuevo cuando el mapa
 * deja de moverse. La anterior se queda hasta que llega la nueva, para que no parpadee. Va dentro del mapa.
 *
 *   capa     capa de GeoServer ("geotravel:incidente")
 *   estilo   estilo de calor ("incidentes_calor")
 *   cql      filtro CQL ("INCLUDE" o "" = sin filtro)
 *   version  cambiarlo fuerza a pedir de nuevo (botón "Actualizar")
 */
const MARGEN = 0.25; // fracción extra de cada lado
const LADO_MAXIMO = 3000; // píxeles: tope para pantallas muy grandes

export default function CapaCalor({ capa, estilo, cql, version }) {
  const map = useMap();

  useEffect(() => {
    let imagen = null;
    let pedido = 0;

    const pedir = () => {
      const limites = map.getBounds().pad(MARGEN);
      const sw = map.options.crs.project(limites.getSouthWest());
      const ne = map.options.crs.project(limites.getNorthEast());
      const tamanio = map.getSize().multiplyBy(1 + 2 * MARGEN);
      const escala = Math.min(1, LADO_MAXIMO / Math.max(tamanio.x, tamanio.y));
      const params = new URLSearchParams({
        service: "WMS",
        version: "1.1.1",
        request: "GetMap",
        layers: capa,
        styles: estilo,
        srs: "EPSG:3857",
        bbox: [sw.x, sw.y, ne.x, ne.y].join(","),
        width: Math.round(tamanio.x * escala),
        height: Math.round(tamanio.y * escala),
        format: "image/png",
        transparent: "true",
      });
      if (cql && cql !== "INCLUDE") params.set("cql_filter", cql);
      const url = `${GEOSERVER_WMS_URL}?${params}`;

      const este = ++pedido;
      const cargando = new Image();
      cargando.onload = () => {
        if (este !== pedido) return; // llegó tarde: ya se pidió otra
        const nueva = L.imageOverlay(url, limites, { interactive: false, opacity: 1 }).addTo(map);
        if (imagen) map.removeLayer(imagen);
        imagen = nueva;
      };
      cargando.src = url;
    };

    pedir();
    map.on("moveend", pedir);
    return () => {
      pedido++; // lo que todavía no llegó ya no se dibuja
      map.off("moveend", pedir);
      if (imagen) map.removeLayer(imagen);
    };
  }, [map, capa, estilo, cql, version]);

  return null;
}
