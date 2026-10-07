import { useCallback, useEffect, useState } from "react";
import { GEOSERVER_WMS_URL } from "../../components/MapView.jsx";
import PaginaMapa from "../../components/PaginaMapa.jsx";
import { CAPAS } from "./capas.js";

/**
 * Módulo Invitado (dueño: P5). Sin login: mapa público, de solo lectura.
 *
 * Todo lo que se ve sale de GeoServer: las capas por WMS y los conteos por WFS
 * (resultType=hits, que cuenta sin descargar los objetos). Si GeoServer no responde,
 * el panel lo dice en vez de quedarse mudo.
 *
 * TODO (P5): filtros por tipo/estado/prioridad/fecha de incidentes y selección de un
 * objeto para ver su información detallada (WMS GetFeatureInfo).
 */

const WFS_URL = GEOSERVER_WMS_URL.replace(/\/wms$/, "/ows");
const REFRESCO_CONTEOS_MS = 30000;

/** Cantidad de objetos de una capa, sin descargarlos (WFS 2.0, resultType=hits). */
async function contarObjetos(capa) {
  const url = `${WFS_URL}?service=WFS&version=2.0.0&request=GetFeature&typeNames=${encodeURIComponent(capa)}&resultType=hits`;
  const respuesta = await fetch(url);
  if (!respuesta.ok) throw new Error(`GeoServer respondió ${respuesta.status}`);
  const xml = new DOMParser().parseFromString(await respuesta.text(), "text/xml");
  const cantidad = Number(xml.documentElement.getAttribute("numberMatched"));
  if (Number.isNaN(cantidad)) throw new Error("Respuesta inesperada de GeoServer");
  return cantidad;
}

/** Conteos por capa + si hay conexión con GeoServer. `version` fuerza una nueva lectura. */
function useGeoServer(version) {
  const [estado, setEstado] = useState({ conexion: "conectando", conteos: {}, ultima: null });

  useEffect(() => {
    let vigente = true;
    async function leer() {
      try {
        const pares = await Promise.all(CAPAS.map(async (c) => [c.id, await contarObjetos(c.capa)]));
        if (vigente) setEstado({ conexion: "ok", conteos: Object.fromEntries(pares), ultima: new Date() });
      } catch {
        if (vigente) setEstado((anterior) => ({ ...anterior, conexion: "error" }));
      }
    }
    leer();
    const reloj = setInterval(leer, REFRESCO_CONTEOS_MS);
    return () => {
      vigente = false;
      clearInterval(reloj);
    };
  }, [version]);

  return estado;
}

/** Ícono de la forma con la que se dibuja cada capa en el mapa (ver los SLD). */
function IconoCapa({ forma }) {
  return (
    <svg viewBox="0 0 24 24" width="22" height="22" aria-hidden="true" focusable="false">
      {forma === "zona" && (
        <path d="M4.5 8 12 4.5 19.5 8v8L12 19.5 4.5 16z" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round" />
      )}
      {forma === "circulo" && <circle cx="12" cy="12" r="6.2" fill="currentColor" stroke="#fff" strokeWidth="1.6" />}
      {forma === "cuadrado" && <rect x="6" y="6" width="12" height="12" rx="1.5" fill="currentColor" stroke="#fff" strokeWidth="1.6" />}
    </svg>
  );
}

const TEXTO_CONEXION = {
  conectando: "Conectando con GeoServer…",
  ok: "Conectado a GeoServer",
  error: "Sin conexión con GeoServer",
};

export default function InvitadoPage() {
  const [activas, setActivas] = useState(() => new Set(CAPAS.map((c) => c.id)));
  const [version, setVersion] = useState(0);
  const { conexion, conteos, ultima } = useGeoServer(version);

  const alternarCapa = useCallback((id) => {
    setActivas((anterior) => {
      const siguiente = new Set(anterior);
      if (siguiente.has(id)) siguiente.delete(id);
      else siguiente.add(id);
      return siguiente;
    });
  }, []);

  // Se respeta el orden de CAPAS: la primera queda abajo en el mapa.
  const capasVisibles = CAPAS.filter((c) => activas.has(c.id)).map((c) => c.capa);

  return (
    <PaginaMapa
      etiqueta="Vista pública · solo lectura"
      titulo="Mapa de emergencias"
      etiquetaBoton="Capas"
      abiertoEnMovil={false}
      mapaProps={{ layers: capasVisibles, wmsExtra: { actualizado: version } }}
      aviso={capasVisibles.length === 0 && <p className="pagina-mapa__vacio">Todas las capas están ocultas</p>}
      pie={
        <>
          <p className={`estado estado--${conexion}`} role="status">
            <span className="estado__punto" aria-hidden="true" />
            <span className="estado__texto">
              {TEXTO_CONEXION[conexion]}
              {conexion === "ok" && ultima && (
                <small>Datos de las {ultima.toLocaleTimeString("es-UY", { hour: "2-digit", minute: "2-digit", hour12: false })}</small>
              )}
            </span>
          </p>
          <button type="button" className="btn btn--secundario" onClick={() => setVersion((v) => v + 1)}>
            Actualizar
          </button>
        </>
      }
    >
      <ul className="capas">
        {CAPAS.map((c) => {
          const activa = activas.has(c.id);
          const cantidad = conteos[c.id];
          return (
            <li key={c.id} className={activa ? "capa capa--activa" : "capa"}>
              <label className="capa__fila">
                <input type="checkbox" checked={activa} onChange={() => alternarCapa(c.id)} />
                <span className="interruptor" aria-hidden="true" />
                <span className="capa__icono">
                  <IconoCapa forma={c.forma} />
                </span>
                <span className="capa__texto">
                  <span className="capa__nombre">{c.nombre}</span>
                  <span className="capa__descripcion">{c.descripcion}</span>
                </span>
                <span className="capa__conteo" title={cantidad === undefined ? "Sin dato" : `${cantidad} en la base`}>
                  {cantidad === undefined ? "—" : cantidad}
                </span>
              </label>
              {activa && (
                <ul className="leyenda" aria-label={`Leyenda de ${c.nombre}`}>
                  {c.leyenda.map((item) => (
                    <li key={item.etiqueta} className="leyenda__item">
                      <span className={`leyenda__marca leyenda__marca--${c.forma}`} style={{ "--color": item.color }} aria-hidden="true" />
                      {item.etiqueta}
                    </li>
                  ))}
                </ul>
              )}
            </li>
          );
        })}
      </ul>
    </PaginaMapa>
  );
}
