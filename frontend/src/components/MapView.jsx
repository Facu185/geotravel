import { useEffect, useRef } from "react";
import OlMap from "ol/Map";
import View from "ol/View";
import TileLayer from "ol/layer/Tile";
import OSM from "ol/source/OSM";
import TileWMS from "ol/source/TileWMS";
import { fromLonLat } from "ol/proj";
import "ol/ol.css";

const GEOSERVER_WMS_URL =
  import.meta.env.VITE_GEOSERVER_WMS_URL ?? "http://localhost:8082/geoserver/geotravel/wms";

// Centro aproximado de Montevideo. Ajustar si el proyecto trabaja otra zona.
const MONTEVIDEO_CENTER = fromLonLat([-56.1645, -34.9011]);

/**
 * Mapa base compartido por todos los módulos. Cada página pasa qué capas WMS
 * de GeoServer quiere mostrar (nombre de capa = workspace:layer).
 *
 * Ejemplo:
 *   <MapView layers={["geotravel:zona_turistica", "geotravel:atraccion"]} />
 *
 * Para agregar dibujo/edición (ABM de zonas, etc.) o markers propios, usar
 * `onMapReady(map)`: recibe la instancia de ol/Map ya creada, para agregarle
 * capas/interacciones desde el módulo que la necesite (ver docs de OpenLayers,
 * ol/interaction/Draw para dibujar polígonos sobre el mapa).
 */
export default function MapView({ layers = [], height = "70vh", onMapReady }) {
  const containerRef = useRef(null);
  const mapRef = useRef(null);
  const wmsLayersRef = useRef([]);

  // Crear el mapa una sola vez.
  useEffect(() => {
    const map = new OlMap({
      target: containerRef.current,
      layers: [
        new TileLayer({
          source: new OSM(),
        }),
      ],
      view: new View({
        center: MONTEVIDEO_CENTER,
        zoom: 13,
      }),
    });
    mapRef.current = map;
    onMapReady?.(map);

    return () => {
      map.setTarget(null);
      mapRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Sincronizar las capas WMS con la prop `layers` cada vez que su contenido cambia
  // (se compara por valor, no por referencia: los llamadores suelen pasar un array
  // nuevo en cada render, ej. InvitadoPage.jsx).
  const layersKey = layers.join(",");
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    wmsLayersRef.current.forEach((layer) => map.removeLayer(layer));

    wmsLayersRef.current = layers.map((layerName) => {
      const layer = new TileLayer({
        source: new TileWMS({
          url: GEOSERVER_WMS_URL,
          params: { LAYERS: layerName, TILED: true },
          serverType: "geoserver",
          transition: 0,
        }),
      });
      map.addLayer(layer);
      return layer;
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [layersKey]);

  return <div ref={containerRef} style={{ height, width: "100%" }} />;
}
