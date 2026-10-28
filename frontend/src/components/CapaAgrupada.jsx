import { useEffect, useRef } from "react";
import L from "leaflet";
import "leaflet.markercluster";
import "leaflet.markercluster/dist/MarkerCluster.css";
import { useMap } from "react-leaflet";

/**
 * Del zoom 15 en adelante se ven los íconos de cada objeto; más lejos (zoom 14 o menos) los objetos que quedan juntos se
 * agrupan en un círculo con la cantidad, como en Airbnb. Es el mismo corte que usan los estilos de GeoServer cuando
 * dibuja él (geoserver/agrupamiento_sld.py), para que el agrupamiento no cambie al pasar de una imagen a objetos.
 */
export const ZOOM_ICONOS = 15;
const RADIO_PX = 64; // como la celda de GeoServer

const tamanoDe = (cantidad) => (cantidad < 10 ? 28 : cantidad < 100 ? 34 : 40);

/** El círculo con la cantidad. El color distingue qué se agrupó (incidentes o recursos). */
const iconoGrupo = (color) => (grupo) => {
  const cantidad = grupo.getChildCount();
  const tamano = tamanoDe(cantidad);
  return L.divIcon({
    className: "grupo",
    html: `<span class="grupo__numero" style="--color:${color};width:${tamano}px;height:${tamano}px">${cantidad}</span>`,
    iconSize: [tamano, tamano],
  });
};

/**
 * Dibuja marcadores que se agrupan con un número cuando el mapa está alejado. Va DENTRO del mapa.
 *
 *   items  [{ id, pos: [lat, lng], icon (L.divIcon), etiqueta (rótulo al pasar el mouse), alClick(),
 *            soloAgrupado, libre }]
 *            soloAgrupado: un objeto que no es un punto (una calle cortada, un área): su forma ya se dibuja aparte y acá solo
 *                          entra, por su centro, mientras el mapa está alejado, para que se cuente en el grupo
 *            libre: el que se está eligiendo: nunca se agrupa, siempre se ve
 *   color  color del círculo de los grupos
 *
 * Conviene pasar `items` memorizado (useMemo): se vuelve a dibujar cada vez que cambia.
 */
export default function CapaAgrupada({ items, color = "#13202c" }) {
  const map = useMap();
  const grupoRef = useRef(null);
  const libresRef = useRef(null);
  const itemsRef = useRef(items);
  itemsRef.current = items;

  const dibujar = () => {
    const grupo = grupoRef.current;
    const libres = libresRef.current;
    if (!grupo || !libres) return;
    const cerca = map.getZoom() >= ZOOM_ICONOS;
    grupo.clearLayers();
    libres.clearLayers();
    const agrupables = [];
    itemsRef.current.forEach((item) => {
      if (item.soloAgrupado && (cerca || item.libre)) return;
      const marcador = L.marker(item.pos, { icon: item.icon, bubblingMouseEvents: false });
      if (item.etiqueta) marcador.bindTooltip(item.etiqueta);
      if (item.alClick) {
        marcador.on("click", (e) => {
          L.DomEvent.stopPropagation(e);
          item.alClick();
        });
      }
      if (item.libre) libres.addLayer(marcador);
      else agrupables.push(marcador);
    });
    grupo.addLayers(agrupables);
  };

  useEffect(() => {
    const grupo = L.markerClusterGroup({
      maxClusterRadius: RADIO_PX,
      disableClusteringAtZoom: ZOOM_ICONOS,
      showCoverageOnHover: false,
      spiderfyOnMaxZoom: false,
      iconCreateFunction: iconoGrupo(color),
    });
    const libres = L.layerGroup();
    grupoRef.current = grupo;
    libresRef.current = libres;
    map.addLayer(grupo);
    map.addLayer(libres);
    dibujar();

    // Al cruzar el zoom de los íconos entran o salen los centros de las formas.
    let eraCerca = map.getZoom() >= ZOOM_ICONOS;
    const alZoom = () => {
      const esCerca = map.getZoom() >= ZOOM_ICONOS;
      if (esCerca !== eraCerca) {
        eraCerca = esCerca;
        dibujar();
      }
    };
    map.on("zoomend", alZoom);
    return () => {
      map.off("zoomend", alZoom);
      map.removeLayer(grupo);
      map.removeLayer(libres);
      grupoRef.current = null;
      libresRef.current = null;
    };
    // dibujar lee siempre lo último desde las refs
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [map, color]);

  useEffect(() => {
    dibujar();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [items]);

  return null;
}
