import L from "leaflet";
import { CircleMarker, Polygon, Polyline, useMap, useMapEvents } from "react-leaflet";
import { Insignia } from "../../components/ui.jsx";
import { COLOR_ESTADO_INCIDENTE, COLOR_ESTADO_RECURSO, COLOR_PRIORIDAD } from "../../components/colores.js";
import { GEOSERVER_WMS_URL } from "../../components/MapView.jsx";

/**
 * Detalle de lo que hay bajo un clic en el mapa público, con WMS GetFeatureInfo: le pregunta a
 * GeoServer qué objetos de las capas visibles hay en ese píxel (con los mismos filtros que el
 * mapa) y devuelve sus atributos en JSON. No usa la API del backend.
 */

// GeoServer devuelve las geometrías en el SRS del pedido (EPSG:3857, el del mapa).
const aLatLng = ([x, y]) => L.CRS.EPSG3857.unproject(L.point(x, y));

const WFS_URL = GEOSERVER_WMS_URL.replace(/\/wms$/, "/ows");
const ORDEN = { incidente: 0, recurso: 1, acceso: 2, zona_operativa: 3, via: 4 };
const capaDe = (objeto) => objeto.id.split(".")[0];

async function consultarObjetos(map, latlng, capas, cql) {
  const limites = map.getBounds();
  const sw = map.options.crs.project(limites.getSouthWest());
  const ne = map.options.crs.project(limites.getNorthEast());
  const tamanio = map.getSize();
  const pixel = map.latLngToContainerPoint(latlng);
  const nombres = capas.join(",");

  const params = new URLSearchParams({
    service: "WMS",
    version: "1.1.1",
    request: "GetFeatureInfo",
    layers: nombres,
    query_layers: nombres,
    styles: "",
    srs: "EPSG:3857",
    bbox: [sw.x, sw.y, ne.x, ne.y].join(","),
    width: tamanio.x,
    height: tamanio.y,
    x: Math.round(pixel.x),
    y: Math.round(pixel.y),
    info_format: "application/json",
    feature_count: 10,
    buffer: 8, // tolerancia en píxeles: no hace falta acertarle al punto exacto
  });
  if (cql) params.set("cql_filter", cql);

  const respuesta = await fetch(`${GEOSERVER_WMS_URL}?${params}`);
  if (!respuesta.ok) throw new Error(`GeoServer respondió ${respuesta.status}`);
  const datos = await respuesta.json();
  const objetos = datos.features ?? [];

  // Una calle está partida en muchos tramos y el clic solo toca uno: se piden todos los tramos
  // con ese nombre (WFS) para resaltarla entera.
  const calles = [...new Set(objetos.filter((o) => capaDe(o) === "via").map((o) => o.properties.nom_calle))];
  for (const nombre of calles) {
    const tramos = await tramosDeCalle(nombre);
    const sinTramos = objetos.filter((o) => !(capaDe(o) === "via" && o.properties.nom_calle === nombre));
    objetos.splice(0, objetos.length, ...sinTramos, ...tramos);
  }
  return objetos.sort((a, b) => (ORDEN[capaDe(a)] ?? 9) - (ORDEN[capaDe(b)] ?? 9));
}

/** Todos los tramos de una calle, por WFS, en EPSG:3857 como el resto de las geometrías del detalle. */
async function tramosDeCalle(nombre) {
  const params = new URLSearchParams({
    service: "WFS",
    version: "2.0.0",
    request: "GetFeature",
    typeNames: "geotravel:via",
    outputFormat: "application/json",
    srsName: "EPSG:3857",
    cql_filter: `nom_calle='${nombre.replace(/'/g, "''")}'`,
  });
  const respuesta = await fetch(`${WFS_URL}?${params}`);
  if (!respuesta.ok) throw new Error(`GeoServer respondió ${respuesta.status}`);
  return (await respuesta.json()).features ?? [];
}

/** Escucha los clics del mapa y devuelve los objetos que hay ahí. Va dentro del mapa. */
export function ClickConsulta({ capas, cql, alResultado, alError }) {
  const map = useMap();
  useMapEvents({
    click: async (e) => {
      if (capas.length === 0) return;
      try {
        alResultado(await consultarObjetos(map, e.latlng, capas, cql));
        alError(null);
      } catch (error) {
        alError(error.message);
      }
    },
  });
  return null;
}

/** Contorno sobre lo elegido, para ver cuál es en el mapa. Va dentro del mapa. */
export function Seleccion({ objetos }) {
  return objetos.map((objeto) => {
    const geometria = objeto.geometry;
    if (geometria?.type === "Point") {
      return (
        <CircleMarker key={objeto.id} center={aLatLng(geometria.coordinates)} radius={16} interactive={false} pathOptions={{ color: "#13202c", weight: 3, fillOpacity: 0 }} />
      );
    }
    if (geometria?.type === "LineString") {
      return <Polyline key={objeto.id} positions={geometria.coordinates.map(aLatLng)} interactive={false} pathOptions={{ color: "#13202c", weight: 5, opacity: 0.8 }} />;
    }
    if (geometria?.type === "MultiLineString") {
      return (
        <Polyline key={objeto.id} positions={geometria.coordinates.map((linea) => linea.map(aLatLng))} interactive={false} pathOptions={{ color: "#13202c", weight: 5, opacity: 0.8 }} />
      );
    }
    if (geometria?.type === "Polygon") {
      return (
        <Polygon
          key={objeto.id}
          positions={geometria.coordinates.map((anillo) => anillo.map(aLatLng))}
          interactive={false}
          pathOptions={{ color: "#13202c", weight: 3, fill: false, dashArray: "6 4" }}
        />
      );
    }
    return null;
  });
}

const formatoFecha = (iso) =>
  new Date(iso).toLocaleString("es-UY", { day: "2-digit", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit", hour12: false });

function Dato({ nombre, children }) {
  if (children === null || children === undefined || children === "") return null;
  return (
    <>
      <dt>{nombre}</dt>
      <dd>{children}</dd>
    </>
  );
}

function Objeto({ objeto }) {
  const p = objeto.properties;
  const capa = capaDe(objeto);

  if (capa === "incidente") {
    return (
      <article className="seleccion">
        <header className="detalle__cabecera">
          <div>
            <p className="seleccion__tipo">Incidente</p>
            <h3 className="bloque__titulo">{p.titulo}</h3>
          </div>
          <Insignia color={COLOR_ESTADO_INCIDENTE[p.estado]}>{p.estado}</Insignia>
        </header>
        {p.descripcion && <p className="detalle__descripcion">{p.descripcion}</p>}
        <dl className="datos">
          <Dato nombre="Tipo">{p.tipo_incidente}</Dato>
          <Dato nombre="Prioridad">{p.prioridad}</Dato>
          <Dato nombre="Fecha">{p.fecha_hora_registro && formatoFecha(p.fecha_hora_registro)}</Dato>
          <Dato nombre="Equipo">{p.equipo_responsable}</Dato>
        </dl>
      </article>
    );
  }

  if (capa === "recurso") {
    return (
      <article className="seleccion">
        <header className="detalle__cabecera">
          <div>
            <p className="seleccion__tipo">Recurso</p>
            <h3 className="bloque__titulo">{p.identificacion}</h3>
          </div>
          <Insignia color={COLOR_ESTADO_RECURSO[p.estado_operativo]}>{p.estado_operativo}</Insignia>
        </header>
        {p.descripcion && <p className="detalle__descripcion">{p.descripcion}</p>}
        <dl className="datos">
          <Dato nombre="Tipo">{p.tipo}</Dato>
          <Dato nombre="Nombre">{p.nombre}</Dato>
        </dl>
      </article>
    );
  }

  if (capa === "acceso") {
    return (
      <article className="seleccion">
        <header className="detalle__cabecera">
          <div>
            <p className="seleccion__tipo">Número de puerta</p>
            <h3 className="bloque__titulo">
              {p.nom_calle} {p.num_puerta}
              {p.letra ?? ""}
            </h3>
          </div>
        </header>
      </article>
    );
  }

  if (capa === "via") {
    return (
      <article className="seleccion">
        <header className="detalle__cabecera">
          <div>
            <p className="seleccion__tipo">Calle</p>
            <h3 className="bloque__titulo">{p.nom_calle}</h3>
          </div>
          <Insignia color="#5f6f7e">{p.tipo}</Insignia>
        </header>
      </article>
    );
  }

  return (
    <article className="seleccion">
      <header className="detalle__cabecera">
        <div>
          <p className="seleccion__tipo">Zona operativa</p>
          <h3 className="bloque__titulo">{p.nombre}</h3>
        </div>
        <Insignia color={COLOR_PRIORIDAD[p.nivel_prioridad]}>Prioridad {p.nivel_prioridad}</Insignia>
      </header>
      {p.descripcion && <p className="detalle__descripcion">{p.descripcion}</p>}
      <dl className="datos">
        <Dato nombre="Responsable">{p.responsable}</Dato>
        <Dato nombre="Observaciones">{p.observaciones}</Dato>
      </dl>
    </article>
  );
}

/** Tarjeta flotante sobre el mapa con el detalle de lo elegido (sirve también en el celular). */
export function DetalleFlotante({ objetos: todos, alCerrar }) {
  // Una calle son varios tramos: en un cruce se tocan dos o más tramos de la misma calle, y se
  // muestra una sola tarjeta por nombre (en el mapa se resaltan todos).
  const objetos = todos.filter(
    (o, i) => capaDe(o) !== "via" || todos.findIndex((x) => capaDe(x) === "via" && x.properties.nom_calle === o.properties.nom_calle) === i,
  );
  return (
    <aside className="detalle-flotante" aria-label="Detalle de lo seleccionado">
      <button type="button" className="panel__cerrar detalle-flotante__cerrar" onClick={alCerrar} aria-label="Cerrar el detalle">
        <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true" focusable="false">
          <path d="m6 6 12 12M18 6 6 18" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
        </svg>
      </button>
      {objetos.length > 1 && <p className="ayuda">{objetos.length} objetos en este punto</p>}
      {objetos.map((objeto) => (
        <Objeto key={objeto.id} objeto={objeto} />
      ))}
    </aside>
  );
}
