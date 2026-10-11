import { useCallback, useEffect, useState } from "react";
import { GEOSERVER_WMS_URL } from "../../components/MapView.jsx";
import PaginaMapa from "../../components/PaginaMapa.jsx";
import { Selector } from "../../components/ui.jsx";
import { api } from "../../api/client.js";
import { COLOR_ESTADO_INCIDENTE, COLOR_ESTADO_RECURSO, TIPOS_RECURSO } from "../../components/colores.js";
import { CAPAS } from "./capas.js";
import { ClickConsulta, DetalleFlotante, Seleccion } from "./detalle.jsx";
import { FILTROS_VACIOS, cqlDeCapa, cqlParaCapas } from "./filtros.js";

/**
 * Módulo Invitado (dueño: P5). Sin login: mapa público, de solo lectura.
 *
 * Todo lo que se ve sale de GeoServer:
 *   - las capas, por WMS (GetMap);
 *   - los conteos, por WFS (resultType=hits, que cuenta sin descargar los objetos);
 *   - el detalle al tocar un objeto, por WMS GetFeatureInfo (ver detalle.jsx);
 *   - los filtros de incidentes y recursos, como CQL_FILTER en los tres pedidos (ver filtros.js).
 * Lo único que no viene de GeoServer es la lista de tipos de incidente del filtro (la API la
 * entrega con un DISTINCT en la base). Si GeoServer no responde, el panel lo dice en vez de quedarse mudo.
 */

const WFS_URL = GEOSERVER_WMS_URL.replace(/\/wms$/, "/ows");
const REFRESCO_CONTEOS_MS = 30000;

const ESTADOS_INCIDENTE = Object.keys(COLOR_ESTADO_INCIDENTE).map((e) => ({ valor: e, texto: e }));
const ESTADOS_RECURSO = Object.keys(COLOR_ESTADO_RECURSO).map((e) => ({ valor: e, texto: e }));
const TIPOS_DE_RECURSO = TIPOS_RECURSO.map((t) => ({ valor: t, texto: t }));
const PRIORIDADES = [1, 2, 3, 4, 5].map((n) => ({ valor: n, texto: String(n) }));

/** Cantidad de objetos de una capa que cumplen el filtro, sin descargarlos (WFS 2.0, resultType=hits). */
async function contarObjetos(capa, cql) {
  let url = `${WFS_URL}?service=WFS&version=2.0.0&request=GetFeature&typeNames=${encodeURIComponent(capa)}&resultType=hits`;
  if (cql !== "INCLUDE") url += `&cql_filter=${encodeURIComponent(cql)}`;
  const respuesta = await fetch(url);
  if (!respuesta.ok) throw new Error(`GeoServer respondió ${respuesta.status}`);
  const xml = new DOMParser().parseFromString(await respuesta.text(), "text/xml");
  const cantidad = Number(xml.documentElement.getAttribute("numberMatched"));
  if (Number.isNaN(cantidad)) throw new Error("Respuesta inesperada de GeoServer");
  return cantidad;
}

/**
 * Conteos por capa (con el filtro aplicado y el total sin filtrar) + si hay conexión con
 * GeoServer. `version` fuerza una nueva lectura.
 */
function useGeoServer(version, filtros) {
  const [estado, setEstado] = useState({ conexion: "conectando", conteos: {}, ultima: null });

  useEffect(() => {
    let vigente = true;
    async function leer() {
      try {
        const pares = await Promise.all(
          CAPAS.map(async (c) => {
            const cql = cqlDeCapa(c.id, filtros);
            const cantidad = await contarObjetos(c.capa, cql);
            const total = cql === "INCLUDE" ? cantidad : await contarObjetos(c.capa, "INCLUDE");
            return [c.id, { cantidad, total }];
          }),
        );
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
  }, [version, filtros]);

  return estado;
}

/**
 * Los tipos de incidente que existen, para el filtro. Los entrega la API con un DISTINCT en la
 * base: pedirle a GeoServer todos los incidentes para sacar los valores distintos no escala.
 */
function useTiposIncidente(version) {
  const [tipos, setTipos] = useState([]);

  useEffect(() => {
    let vigente = true;
    api
      .get("/consultas/tipos-incidente")
      .then((lista) => {
        if (vigente) setTipos(lista.map((t) => ({ valor: t, texto: t })));
      })
      .catch(() => {}); // sin tipos el filtro queda vacío, pero el mapa sigue funcionando
    return () => {
      vigente = false;
    };
  }, [version]);

  return tipos;
}

/** Ícono de la forma con la que se dibuja cada capa en el mapa (ver los SLD). */
function IconoCapa({ forma }) {
  return (
    <svg viewBox="0 0 24 24" width="22" height="22" aria-hidden="true" focusable="false">
      {forma === "zona" && (
        <path d="M4.5 8 12 4.5 19.5 8v8L12 19.5 4.5 16z" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round" />
      )}
      {forma === "linea" && <path d="M4 17.5 10 9l4.5 6L20 6.5" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />}
      {forma === "circulo" && <circle cx="12" cy="12" r="6.2" fill="currentColor" stroke="#fff" strokeWidth="1.6" />}
      {forma === "cuadrado" && <rect x="6" y="6" width="12" height="12" rx="1.5" fill="currentColor" stroke="#fff" strokeWidth="1.6" />}
    </svg>
  );
}

/** Filtros de una capa (incidentes o recursos), plegados dentro de la propia capa. */
function Filtros({ capaId, valores, onChange, tipos }) {
  const cambiar = (clave) => (valor) => onChange({ ...valores, [clave]: valor });
  const activos = Object.values(valores).filter(Boolean).length;

  return (
    <details className="filtros">
      <summary>
        Filtrar
        {activos > 0 && <span className="filtros__activos">{activos === 1 ? "1 filtro" : `${activos} filtros`}</span>}
      </summary>
      <div className="filtros__cuerpo">
        {capaId === "incidentes" ? (
          <>
            <Selector etiqueta="Tipo" valor={valores.tipo} onChange={cambiar("tipo")} opciones={tipos} vacio="Todos" />
            <div className="campos-2">
              <Selector etiqueta="Estado" valor={valores.estado} onChange={cambiar("estado")} opciones={ESTADOS_INCIDENTE} vacio="Todos" />
              <Selector etiqueta="Prioridad" valor={valores.prioridad} onChange={cambiar("prioridad")} opciones={PRIORIDADES} vacio="Todas" />
            </div>
            <div className="campos-2">
              <label className="campo">
                <span className="campo__etiqueta">Desde</span>
                <input type="date" value={valores.desde} onChange={(e) => cambiar("desde")(e.target.value)} />
              </label>
              <label className="campo">
                <span className="campo__etiqueta">Hasta</span>
                <input type="date" value={valores.hasta} onChange={(e) => cambiar("hasta")(e.target.value)} />
              </label>
            </div>
          </>
        ) : (
          <div className="campos-2">
            <Selector etiqueta="Tipo" valor={valores.tipo} onChange={cambiar("tipo")} opciones={TIPOS_DE_RECURSO} vacio="Todos" />
            <Selector etiqueta="Estado" valor={valores.estado} onChange={cambiar("estado")} opciones={ESTADOS_RECURSO} vacio="Todos" />
          </div>
        )}
        <button type="button" className="btn btn--secundario" disabled={activos === 0} onClick={() => onChange(FILTROS_VACIOS[capaId])}>
          Limpiar filtros
        </button>
      </div>
    </details>
  );
}

const TEXTO_CONEXION = {
  conectando: "Conectando con GeoServer…",
  ok: "Conectado a GeoServer",
  error: "Sin conexión con GeoServer",
};

export default function InvitadoPage() {
  const [activas, setActivas] = useState(() => new Set(CAPAS.filter((c) => c.activaPorDefecto !== false).map((c) => c.id)));
  const [version, setVersion] = useState(0);
  const [filtros, setFiltros] = useState(FILTROS_VACIOS);
  const [objetos, setObjetos] = useState([]); // lo que se tocó en el mapa (GetFeatureInfo)
  const [errorDetalle, setErrorDetalle] = useState(null);
  const { conexion, conteos, ultima } = useGeoServer(version, filtros);
  const tiposIncidente = useTiposIncidente(version);

  const alternarCapa = useCallback((id) => {
    setObjetos([]);
    setActivas((anterior) => {
      const siguiente = new Set(anterior);
      if (siguiente.has(id)) siguiente.delete(id);
      else siguiente.add(id);
      return siguiente;
    });
  }, []);

  const cambiarFiltros = (capaId, valores) => {
    setObjetos([]);
    setFiltros((anterior) => ({ ...anterior, [capaId]: valores }));
  };

  // Se respeta el orden de CAPAS: la primera queda abajo en el mapa.
  const visibles = CAPAS.filter((c) => activas.has(c.id));
  const capasVisibles = visibles.map((c) => c.capa);
  const cql = cqlParaCapas(visibles, filtros);

  const hijosMapa = (
    <>
      <ClickConsulta capas={capasVisibles} cql={cql} alResultado={setObjetos} alError={setErrorDetalle} />
      <Seleccion objetos={objetos} />
    </>
  );

  return (
    <PaginaMapa
      etiqueta="Vista pública · solo lectura"
      titulo="Mapa de emergencias"
      etiquetaBoton="Capas"
      abiertoEnMovil={false}
      hijosMapa={hijosMapa}
      mapaProps={{ layers: capasVisibles, wmsExtra: { actualizado: version, ...(cql ? { cql_filter: cql } : {}) } }}
      aviso={
        <>
          {capasVisibles.length === 0 && <p className="pagina-mapa__vacio">Todas las capas están ocultas</p>}
          {errorDetalle && <p className="pagina-mapa__vacio">No se pudo consultar el detalle: {errorDetalle}</p>}
          {objetos.length > 0 && <DetalleFlotante objetos={objetos} alCerrar={() => setObjetos([])} />}
        </>
      }
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
          const conteo = conteos[c.id];
          const filtrado = conteo && conteo.cantidad !== conteo.total;
          const tieneFiltros = c.id in FILTROS_VACIOS;
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
                <span className="capa__conteo" title={conteo === undefined ? "Sin dato" : filtrado ? `${conteo.cantidad} de ${conteo.total} con los filtros` : `${conteo.cantidad} en la base`}>
                  {conteo === undefined ? "—" : conteo.cantidad}
                  {filtrado && <small>de {conteo.total}</small>}
                </span>
              </label>
              {activa && tieneFiltros && (
                <Filtros
                  capaId={c.id}
                  valores={filtros[c.id]}
                  onChange={(valores) => cambiarFiltros(c.id, valores)}
                  tipos={tiposIncidente}
                />
              )}
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
      <p className="ayuda panel__nota">Tocá un incidente, recurso o zona del mapa para ver su detalle.</p>
    </PaginaMapa>
  );
}
