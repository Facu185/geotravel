import { useEffect } from "react";
import L from "leaflet";
import { useMap } from "react-leaflet";

/**
 * Capas WMS de puntos (incidentes y recursos con su agrupamiento) pedidas como UNA sola imagen de lo que se ve, y no en teselas
 * de 256 px.
 *
 * Por qué una imagen: GeoServer agrupa (vec:PointStacker, ver geoserver/agrupamiento_sld.py) los puntos de cada pedido por
 * separado. Con teselas, un círculo de grupo cuyo centro caía cerca del borde de una tesela quedaba cortado y sin su número
 * (la tesela vecina no sabe que ese grupo existe, y el parámetro `buffer` no cambia eso). En una sola imagen solo hay borde en el
 * límite de la imagen, que queda fuera de la vista gracias al margen.
 *
 * La imagen cubre la vista más un margen (así se puede arrastrar sin ver el borde) y se pide de nuevo solo cuando la vista se
 * sale de lo que ya cubre, cuando cambia el zoom o cuando cambian las capas o los filtros. Su esquina y su tamaño se ajustan a
 * una grilla de 64 px fija en el mundo (la celda del agrupamiento): así los grupos no se reacomodan al mover el mapa. La imagen
 * anterior se queda hasta que llega la nueva, para que no parpadee. Va dentro del mapa.
 *
 *   url     dirección del WMS de GeoServer
 *   capas   capas separadas con coma, en orden (la primera queda abajo)
 *   extra   parámetros WMS adicionales (cql_filter, actualizado...)
 *   pane    nombre del panel de Leaflet donde se dibuja (se crea si no existe)
 *   zIndex  z-index del panel si hay que crearlo
 */
const CELDA = 64; // px: la celda del agrupamiento (tiene que ser igual a CELDA de agrupamiento_sld.py)
const MARGEN = 3 * CELDA; // px de cada lado

export default function CapaWmsImagen({ url, capas, extra, pane, zIndex }) {
  const map = useMap();
  const claveExtra = JSON.stringify(extra ?? {});

  useEffect(() => {
    if (pane && !map.getPane(pane)) {
      map.createPane(pane).style.zIndex = String(zIndex ?? 450);
    }

    let imagen = null; // la que se ve
    let cubre = null; // { zoom, minX, minY, maxX, maxY } en píxeles de ese zoom: lo que cubre la imagen que se ve
    let pedido = 0;

    const pedir = (forzar) => {
      const zoom = map.getZoom();
      const vista = map.getPixelBounds();
      const dentro =
        cubre && cubre.zoom === zoom &&
        vista.min.x >= cubre.minX && vista.min.y >= cubre.minY && vista.max.x <= cubre.maxX && vista.max.y <= cubre.maxY;
      if (dentro && !forzar) return;

      const minX = Math.floor((vista.min.x - MARGEN) / CELDA) * CELDA;
      const minY = Math.floor((vista.min.y - MARGEN) / CELDA) * CELDA;
      const maxX = Math.ceil((vista.max.x + MARGEN) / CELDA) * CELDA;
      const maxY = Math.ceil((vista.max.y + MARGEN) / CELDA) * CELDA;
      const sw = map.unproject([minX, maxY], zoom);
      const ne = map.unproject([maxX, minY], zoom);
      const limites = L.latLngBounds(sw, ne);
      const swM = map.options.crs.project(sw);
      const neM = map.options.crs.project(ne);

      const params = new URLSearchParams({
        service: "WMS",
        version: "1.1.1",
        request: "GetMap",
        layers: capas,
        styles: "",
        srs: "EPSG:3857",
        bbox: [swM.x, swM.y, neM.x, neM.y].join(","),
        width: String(maxX - minX),
        height: String(maxY - minY),
        format: "image/png",
        transparent: "true",
        ...(extra ?? {}),
      });
      const direccion = `${url}?${params}`;

      const este = ++pedido;
      const cargando = new Image();
      cargando.onload = () => {
        if (este !== pedido) return; // llegó tarde: ya se pidió otra
        const nueva = L.imageOverlay(direccion, limites, { interactive: false, pane }).addTo(map);
        if (imagen) map.removeLayer(imagen);
        imagen = nueva;
        cubre = { zoom, minX, minY, maxX, maxY };
      };
      cargando.src = direccion;
    };

    const alMover = () => pedir(false);
    pedir(true);
    map.on("moveend", alMover);
    return () => {
      pedido++; // lo que todavía no llegó ya no se dibuja
      map.off("moveend", alMover);
      if (imagen) map.removeLayer(imagen);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps -- `extra` entra por su texto (claveExtra)
  }, [map, url, capas, claveExtra, pane, zIndex]);

  return null;
}
