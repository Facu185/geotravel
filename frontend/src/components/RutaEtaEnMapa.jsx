import { useEffect } from "react";
import { CircleMarker, Polyline, Tooltip, useMap } from "react-leaflet";

const posicionesDe = (ruta) => ruta.coordinates.map(([lng, lat]) => [lat, lng]);

export default function RutaEtaEnMapa({ ruta }) {
  const mapa = useMap();
  const posiciones = posicionesDe(ruta);

  useEffect(() => {
    const coordenadas = posicionesDe(ruta);
    if (coordenadas.length > 1) mapa.fitBounds(coordenadas, { padding: [48, 48], maxZoom: 16 });
  }, [mapa, ruta]);

  if (posiciones.length < 2) return null;

  return (
    <>
      <Polyline positions={posiciones} pathOptions={{ color: "#c34d32", weight: 6, opacity: 0.9 }}>
        <Tooltip sticky>Ruta OSRM</Tooltip>
      </Polyline>
      <CircleMarker center={posiciones[0]} radius={8} pathOptions={{ color: "#176b87", fillOpacity: 1 }}>
        <Tooltip>Salida del recurso</Tooltip>
      </CircleMarker>
      <CircleMarker center={posiciones[posiciones.length - 1]} radius={8} pathOptions={{ color: "#c34d32", fillOpacity: 1 }}>
        <Tooltip>Llegada al incidente</Tooltip>
      </CircleMarker>
    </>
  );
}