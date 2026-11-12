import { useState } from "react";
import L from "leaflet";
import { MapContainer, Pane, TileLayer, WMSTileLayer, ZoomControl, useMap, useMapEvents } from "react-leaflet";
import { REGION, REGIONES } from "./region.js";
import CapaWmsImagen from "./CapaWmsImagen.jsx";

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
 * Fondo de referencia para guiarse: las calles de GeoServer por jerarquía (a lo lejos solo las rutas y avenidas principales; al
 * acercarse, las secundarias y las de barrio, con sus nombres) y los nombres de ciudades, pueblos y barrios (hasta el zoom 14,
 * cuando toman la posta los nombres de las calles). Salen de la red de rutas (red_vial_arco, estilo calles_referencia) y de
 * lugar_osm (estilo lugares_referencia); ver geoserver/styles. Es una sola imagen por tesela, en un panel propio por encima de las zonas y las calles de datos y por debajo de los puntos (incidentes y recursos).
 */
const REFERENCIA = {
  todo: "geotravel:referencia_todo", // grupo de capas: calles (calles_referencia) y lugares (lugares_referencia)
  barrios: "geotravel:referencia_barrios", // grupo de capas: solo los lugares
};

/**
 * La referencia no cambia, así que se pide por GeoWebCache (el caché de teselas de GeoServer): la primera vez dibuja y guarda
 * el bloque de 4x4 teselas, y después responde del caché sin tocar la base. Si la URL de GeoServer no tiene el formato de
 * siempre (.../geotravel/wms), se usa tal cual: sigue andando, pero sin caché.
 */
const GWC_URL = GEOSERVER_WMS_URL.replace(/\/geotravel\/wms$/, "/gwc/service/wms");

/**
 * Las capas de datos se dividen en dos pedidos para respetar el orden contra la referencia: las zonas y las calles quedan DEBAJO
 * (los nombres y las calles de referencia se leen sobre ellas) y los puntos (incidentes, recursos, grupos) ENCIMA. Si los puntos
 * quedaran debajo, el halo blanco de los nombres les comería un pedazo (un círculo de grupo con un tajo).
 */
const CAPAS_DEBAJO = new Set(["geotravel:zona_operativa", "geotravel:via", "geotravel:red_vial_arco"]);

/** Parte las capas en [debajo, encima] y reparte su cql_filter (uno por capa, separados con ";") al mismo orden. */
function dividirCapas(layers, wmsExtra) {
  const cqls = typeof wmsExtra?.cql_filter === "string" ? wmsExtra.cql_filter.split(";") : null;
  const porCapa = cqls && cqls.length === layers.length ? cqls : null; // un solo filtro: vale para todas
  const grupos = [{ capas: [], cql: [] }, { capas: [], cql: [] }];
  layers.forEach((capa, i) => {
    const g = grupos[CAPAS_DEBAJO.has(capa) ? 0 : 1];
    g.capas.push(capa);
    if (porCapa) g.cql.push(porCapa[i]);
  });
  return grupos.map((g) => ({
    capas: g.capas,
    extra: { ...wmsExtra, ...(porCapa ? { cql_filter: g.cql.join(";") } : {}) },
  }));
}

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
 *   referencia    "todo" (default): calles por jerarquía y nombres de barrios de fondo; "barrios": solo los nombres de
 *                 barrios (el mapa público tiene sus propias calles, que se prenden y apagan); false: nada
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
  referencia = "todo",
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
      {/* Un panel propio entre las formas (400) y los marcadores (600): así las calles y los nombres se ven también encima de las
          zonas pintadas, y los íconos quedan arriba. Las teselas no reciben clics: no estorban. */}
      {REFERENCIA[referencia] && (
        <Pane name="referencia" style={{ zIndex: 450 }}>
          <WMSTileLayer
            key={`referencia|${referencia}`}
            url={GWC_URL}
            layers={REFERENCIA[referencia]}
            format="image/png"
            transparent
            // tiled: GeoWebCache solo atiende teselas alineadas a su grilla (256 px, la misma de Leaflet).
            tiled
            opacity={0.9}
            pane="referencia"
          />
        </Pane>
      )}
      {zoomPosition && <ZoomControl position={zoomPosition} />}
      {irARegion && <IrARegion />}
      {mostrarZoom && <IndicadorZoom zoomMinimo={zoomMinimo} />}
      {/* Las capas de datos van en dos grupos: debajo y encima de la referencia (ver dividirCapas). Lo de abajo (zonas y calles)
          sale en teselas: un pedido WMS por tesela, con las capas del grupo dibujadas juntas (la primera queda abajo). Lo de arriba
          (puntos y grupos) sale como UNA imagen de la vista: con teselas, los círculos de grupo del borde quedaban cortados
          (ver CapaWmsImagen). */}
      <Pane name="datos-debajo" style={{ zIndex: 300 }} />
      {(() => {
        const [debajo, encima] = dividirCapas(layers, wmsExtra);
        return (
          <>
            {debajo.capas.length > 0 && (
              <WMSTileLayer
                key={`${debajo.capas.join(",")}|${JSON.stringify(debajo.extra)}`}
                url={GEOSERVER_WMS_URL}
                layers={debajo.capas.join(",")}
                format="image/png"
                transparent
                pane="datos-debajo"
                {...debajo.extra}
              />
            )}
            {encima.capas.length > 0 && (
              <CapaWmsImagen
                url={GEOSERVER_WMS_URL}
                capas={encima.capas.join(",")}
                extra={encima.extra}
                pane="datos-encima"
                zIndex={460}
              />
            )}
          </>
        );
      })()}
      {children}
    </MapContainer>
  );
}
