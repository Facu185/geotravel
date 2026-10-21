import { useState } from "react";
import L from "leaflet";
import { MapContainer, TileLayer, WMSTileLayer, ZoomControl, useMap, useMapEvents } from "react-leaflet";
import { REGION, REGIONES } from "./region.js";

export const GEOSERVER_WMS_URL =
  import.meta.env.VITE_GEOSERVER_WMS_URL ?? "http://localhost:8082/geoserver/geotravel/wms";

// Centro y encuadre iniciales: dependen de la región configurada (ver region.js, VITE_REGION).
// El encuadre lo usan las páginas que ocupan todo el mapa.
export const ENCUADRE_REGION = REGION.encuadre;

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
 * Botones para llevar el mapa a cada región de region.js (el sistema atiende todo el país: hay datos en Salto y en
 * Montevideo). Deja libre el lado del panel, como Enfocar. Va dentro del mapa.
 */
function IrARegion() {
  const map = useMap();
  const ir = (region) => {
    const escritorio = window.matchMedia("(min-width: 800px)").matches;
    const margen = escritorio
      ? { paddingTopLeft: [390, 32], paddingBottomRight: [32, 32] }
      : { paddingTopLeft: [16, 16], paddingBottomRight: [16, Math.round(window.innerHeight * 0.46) + 8] };
    map.flyToBounds(region.encuadre, { ...margen, duration: 0.8 });
  };
  // Que un clic o un gesto sobre los botones no llegue al mapa (en Consultas un clic en el mapa elige un punto).
  const aislar = (el) => {
    if (el) {
      L.DomEvent.disableClickPropagation(el);
      L.DomEvent.disableScrollPropagation(el);
    }
  };
  return (
    <div className="ir-a-region" ref={aislar}>
      <span className="ir-a-region__titulo">Ir a</span>
      {Object.entries(REGIONES).map(([clave, region]) => (
        <button key={clave} type="button" className="ir-a-region__boton" onClick={() => ir(region)}>
          {region.nombre}
        </button>
      ))}
    </div>
  );
}

/** Nivel de zoom actual del mapa, en una esquina. Va dentro del mapa. */
function IndicadorZoom({ zoomMinimo }) {
  const map = useMap();
  const [zoom, setZoom] = useState(map.getZoom());
  useMapEvents({ zoomend: () => setZoom(map.getZoom()) });
  return (
    <div className="indicador-zoom" role="status" aria-live="off">
      Zoom {zoom}
      {zoomMinimo != null && <small>{zoom >= zoomMinimo ? ` · se ven los objetos (desde el ${zoomMinimo})` : ` · acercá hasta el ${zoomMinimo} para ver los objetos`}</small>}
    </div>
  );
}

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
 *   irARegion     true: botones para llevar el mapa a cada región de region.js (Salto, Montevideo...)
 *   mostrarZoom   true: muestra el nivel de zoom actual en una esquina (útil donde algo depende del zoom)
 *   zoomMinimo    con mostrarZoom, el zoom desde el que se ven los objetos, para mostrarlo junto al actual
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
  irARegion = false,
  mostrarZoom = false,
  zoomMinimo,
  className,
}) {
  const mapaBase = MAPAS_BASE[base] ?? MAPAS_BASE.osm;
  const encuadre = bounds ? { bounds, boundsOptions } : { center: REGION.centro, zoom: 13 };

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
      {irARegion && <IrARegion />}
      {mostrarZoom && <IndicadorZoom zoomMinimo={zoomMinimo} />}
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
