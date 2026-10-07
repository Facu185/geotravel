import { MapContainer, TileLayer, WMSTileLayer, ZoomControl } from "react-leaflet";

export const GEOSERVER_WMS_URL =
  import.meta.env.VITE_GEOSERVER_WMS_URL ?? "http://localhost:8082/geoserver/geotravel/wms";

// Centro aproximado de Montevideo. Ajustar si el proyecto trabaja otra zona.
const MONTEVIDEO_CENTER = [-34.9011, -56.1645];

// Rectángulo que encuadra los datos de ejemplo (Montevideo) con un poco de aire:
// [[lat sur, lng oeste], [lat norte, lng este]]. Lo usan las páginas que ocupan todo el mapa.
export const ENCUADRE_MONTEVIDEO = [
  [-34.9205, -56.2215],
  [-34.9005, -56.1395],
];

// Mapas base disponibles. "osm" es el de siempre; "claro" es más sobrio y deja que
// los colores de las capas de GeoServer sean lo único que destaque.
const MAPAS_BASE = {
  osm: {
    url: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
  },
  // Gris claro de Esri: no pide clave. (CARTO Positron sí la pide desde hace poco y devuelve
  // teselas con una marca de agua "API KEY REQUIRED" -- ojo, responde 200 igual.)
  // Las teselas llegan hasta el zoom 16; más allá Leaflet las agranda en vez de pedir vacías.
  claro: {
    url: "https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}",
    attribution:
      'Tiles &copy; <a href="https://www.esri.com">Esri</a> &mdash; Esri, HERE, Garmin, &copy; OpenStreetMap contributors',
    maxNativeZoom: 16,
    maxZoom: 19,
  },
};

/**
 * Mapa base compartido por todos los módulos. Cada página pasa qué capas WMS
 * de GeoServer quiere mostrar (nombre de capa = workspace:layer) y puede
 * agregar overlays propios (markers, popups) como children.
 *
 * Ejemplo:
 *   <MapView layers={["geotravel:zona_operativa", "geotravel:recurso"]} />
 *
 * Props opcionales (todas conservan el comportamiento anterior si se omiten):
 *   base          "osm" (default) | "claro"
 *   zoomPosition  p. ej. "bottomright": mueve el control de zoom de su lugar por defecto
 *   bounds        [[lat, lng], [lat, lng]]: encuadra el mapa a ese rectángulo en vez de center/zoom
 *   boundsOptions opciones de Leaflet para bounds (p. ej. paddingTopLeft)
 *   wmsExtra      parámetros extra para el pedido WMS; cambiarlos fuerza a recargar las capas
 *   className     clase CSS para el contenedor del mapa
 */
export default function MapView({
  layers = [],
  children,
  height = "70vh",
  base = "osm",
  zoomPosition,
  bounds,
  boundsOptions,
  wmsExtra,
  className,
}) {
  const mapaBase = MAPAS_BASE[base] ?? MAPAS_BASE.osm;
  const encuadre = bounds ? { bounds, boundsOptions } : { center: MONTEVIDEO_CENTER, zoom: 13 };

  return (
    <MapContainer
      {...encuadre}
      zoomControl={!zoomPosition}
      className={className}
      style={{ height, width: "100%" }}
    >
      <TileLayer
        key={base}
        attribution={mapaBase.attribution}
        url={mapaBase.url}
        maxNativeZoom={mapaBase.maxNativeZoom}
        maxZoom={mapaBase.maxZoom}
      />
      {zoomPosition && <ZoomControl position={zoomPosition} />}
      {/* Todas las capas van en UN solo pedido WMS por tesela: GeoServer las dibuja juntas
          (menos pedidos, y respeta el orden de la lista: la primera queda abajo). */}
      {layers.length > 0 && (
        <WMSTileLayer
          key={`${layers.join(",")}|${JSON.stringify(wmsExtra ?? {})}`}
          url={GEOSERVER_WMS_URL}
          layers={layers.join(",")}
          format="image/png"
          transparent
          {...wmsExtra}
        />
      )}
      {children}
    </MapContainer>
  );
}
