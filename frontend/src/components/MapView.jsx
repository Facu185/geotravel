import { MapContainer, TileLayer, WMSTileLayer } from "react-leaflet";

const GEOSERVER_WMS_URL =
  import.meta.env.VITE_GEOSERVER_WMS_URL ?? "http://localhost:8082/geoserver/geotravel/wms";

// Centro aproximado de Montevideo. Ajustar si el proyecto trabaja otra zona.
const MONTEVIDEO_CENTER = [-34.9011, -56.1645];

/**
 * Mapa base compartido por todos los módulos. Cada página pasa qué capas WMS
 * de GeoServer quiere mostrar (nombre de capa = workspace:layer) y puede
 * agregar overlays propios (markers, popups) como children.
 *
 * Ejemplo:
 *   <MapView layers={["geotravel:zona_turistica", "geotravel:atraccion"]} />
 */
export default function MapView({ layers = [], children, height = "70vh" }) {
  return (
    <MapContainer center={MONTEVIDEO_CENTER} zoom={13} style={{ height, width: "100%" }}>
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      {layers.map((layerName) => (
        <WMSTileLayer key={layerName} url={GEOSERVER_WMS_URL} layers={layerName} format="image/png" transparent />
      ))}
      {children}
    </MapContainer>
  );
}
