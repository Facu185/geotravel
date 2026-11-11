import { useCallback, useEffect, useId, useMemo, useRef, useState } from "react";
import { Aviso, Insignia, Selector } from "../../components/ui.jsx";
import { COLOR_ESTADO_INCIDENTE, COLOR_PRIORIDAD, nombreTipoIncidente, nombreTipoRecurso } from "../../components/colores.js";
import { IconoIncidente, IconoRecurso } from "../../components/iconos.jsx";
import { api } from "../../api/client.js";
import useRutasDisponibles from "../../api/useRutasDisponibles.js";
import { DEPARTAMENTOS, REGION, nombreLugar } from "../../components/region.js";
import { conGeometria } from "./geometria.js";

/**
 * Las consultas geográficas de la letra, un panel por consulta. Todas siguen el mismo patrón:
 *   1. el usuario elige los parámetros (una zona, un incidente, un punto del mapa, fechas...);
 *   2. se llama a /api/consultas/... y el cálculo lo hace PostGIS en el backend;
 *   3. el resultado se muestra como lista y, con setResultado, también dibujado en el mapa.
 *
 * Las consultas son "a demanda": cada una devuelve ya la geometría de lo que encontró (campo "geom",
 * GeoJSON en lon/lat) y, las que pueden dar muchas filas, un límite y el total real. La página no
 * carga todos los objetos: lo demás lo dibuja GeoServer de fondo. Para elegir una zona, un incidente
 * o un recurso (consultas 1, 2, 3, 6 y 7) se usan los de la parte visible del mapa: la página los carga
 * (CargaPorZona), el mapa los dibuja y el panel los lista; se elige con un clic en cualquiera de los dos.
 *
 * Cada panel recibe de la página: setResultado (lo que se dibuja como resultado), setElegibles (los objetos
 * del mapa que se pueden elegir), carga (los objetos de la vista) y vista (el bbox visible).
 */

/** Lo que un panel le pide dibujar al mapa: objetos con su geometría ya leída (ver geometria.js). */
export const RESULTADO_VACIO = {
  zonas: [], // [{ id, nombre, nivelPrioridad, geometria, intensidad entre 0 y 1 }]
  incidentes: [], // [{ id, titulo, estado, geometria, pos }]
  recursos: [], // [{ id, identificacion, estadoOperativo, geometria, pos }]
  lineas: [], // [{ desde: [lat, lng], hasta: [lat, lng], texto, color?, elegida? }]: una línea directa (punteada)
  rutas: [], // [{ id, geometria (LineString GeoJSON), texto, elegida }]: recorridos por calles (consulta 3)
  area: null, // GeoJSON (lon/lat) de un área buscada genérica (se dibuja punteada)
  ajuste: null, // si se pone, el mapa se vuelve a encuadrar solo cuando esta clave cambia (no con cada cambio del resultado)
};

/** Una zona de la API (o de una búsqueda) lista para dibujar, con la intensidad con la que se pinta. */
const comoZona = (z, intensidad = 1) => ({ ...conGeometria(z), intensidad });

const ESTADOS_INCIDENTE = Object.keys(COLOR_ESTADO_INCIDENTE);

// ---------------------------------------------------------------------------- utilidades

/** Pide una ruta GET. Mientras cambia la ruta devuelve "cargando" (nunca datos de la ruta anterior). */
function useRuta(ruta) {
  const [estado, setEstado] = useState({ ruta: null, fase: "quieto", datos: null, error: null });

  useEffect(() => {
    if (!ruta) return undefined;
    let vigente = true;
    api
      .get(ruta)
      .then((datos) => vigente && setEstado({ ruta, fase: "ok", datos, error: null }))
      .catch((e) => vigente && setEstado({ ruta, fase: "error", datos: null, error: e.message }));
    return () => {
      vigente = false;
    };
  }, [ruta]);

  if (!ruta) return { fase: "quieto", datos: null, error: null };
  if (estado.ruta !== ruta) return { fase: "cargando", datos: null, error: null };
  return estado;
}

/** "?a=1&b=2" con los parámetros que tengan valor. */
const query = (params) => {
  const q = new URLSearchParams();
  Object.entries(params).forEach(([clave, valor]) => {
    if (valor !== "" && valor != null) q.set(clave, valor);
  });
  const texto = q.toString();
  return texto ? `?${texto}` : "";
};

/** El backend filtra con "fecha < hasta": para incluir el día elegido se manda el día siguiente. */
const diaSiguiente = (fecha) => {
  if (!fecha) return "";
  const [a, m, d] = fecha.split("-").map(Number);
  return new Date(Date.UTC(a, m - 1, d + 1)).toISOString().slice(0, 10);
};

const metros = (m) => (m >= 1000 ? `${(m / 1000).toFixed(2)} km` : `${Math.round(m)} m`);

function Estado({ fase, error }) {
  if (fase === "cargando") return <p className="ayuda">Calculando…</p>;
  if (fase === "error") return <Aviso tipo="error">{error}</Aviso>;
  return null;
}

/**
 * Elegir una zona, un incidente o un recurso escribiendo: mientras se escribe se piden pocas opciones
 * a /consultas/buscar (nunca la lista completa). Al elegir una sugerencia, onChange recibe el objeto
 * (con su geometría); si se cambia el texto, recibe null.
 */
function BuscadorObjeto({ etiqueta, tipo, onChange, placeholder }) {
  const [texto, setTexto] = useState("");
  const [sugerencias, setSugerencias] = useState([]);
  const id = useId();

  useEffect(() => {
    let vigente = true;
    const espera = setTimeout(() => {
      api
        .get(`/consultas/buscar${query({ tipo, q: texto })}`)
        .then((lista) => vigente && setSugerencias(lista))
        .catch(() => {}); // sin sugerencias se puede seguir escribiendo
    }, 250);
    return () => {
      vigente = false;
      clearTimeout(espera);
    };
  }, [tipo, texto]);

  const cambiar = (e) => {
    const nuevo = e.target.value;
    setTexto(nuevo);
    onChange(sugerencias.find((o) => o.etiqueta === nuevo) ?? null);
  };

  return (
    <label className="campo">
      <span className="campo__etiqueta">{etiqueta}</span>
      <input list={id} value={texto} onChange={cambiar} placeholder={placeholder} autoComplete="off" />
      <datalist id={id}>
        {sugerencias.map((o) => (
          <option key={o.id} value={o.etiqueta} />
        ))}
      </datalist>
    </label>
  );
}

/** Aviso cuando la consulta devolvió solo una parte de lo que hay. */
function Truncado({ r, nombre }) {
  return r?.truncado ? (
    <p className="ayuda">
      Se muestran {r.items.length} de {r.total} {nombre}.
    </p>
  ) : null;
}

function FilaIncidente({ i, extra }) {
  const detalle = [nombreTipoIncidente(i.tipoIncidente), i.prioridad ? `prioridad ${i.prioridad}` : null, i.fechaHoraRegistro?.slice(0, 16)]
    .filter(Boolean)
    .join(" · ");
  return (
    <li className="fila">
      <IconoIncidente tipo={i.tipoIncidente} estado={i.estado} chico />
      <span className="item__texto">
        <span className="item__titulo">{i.titulo}</span>
        {detalle && <span className="item__detalle">{detalle}</span>}
      </span>
      {extra ?? <Insignia color={COLOR_ESTADO_INCIDENTE[i.estado]}>{i.estado}</Insignia>}
    </li>
  );
}

function FilaRecurso({ r, dato }) {
  return (
    <li className="fila">
      <IconoRecurso tipo={r.tipo} estado={r.estadoOperativo} chico />
      <span className="item__texto">
        <span className="item__titulo">{r.identificacion}</span>
        <span className="item__detalle">
          {nombreTipoRecurso(r.tipo)} · {r.estadoOperativo}
        </span>
      </span>
      {dato && <span className="resultado__dato">{dato}</span>}
    </li>
  );
}

// --------------------------------------- elegir un objeto de la vista (zona, incidente o recurso)

const NOMBRE_OBJETO = { zona: "zonas", incidente: "incidentes", recurso: "recursos" };

/** Los objetos de la parte visible del mapa (con la geometría ya leída), o null si no hay nada para elegir todavía. */
export function useObjetosDeLaVista(carga) {
  return useMemo(() => {
    if (carga.estado === "lejos" || (carga.estado === "cargando" && carga.items.length === 0)) return null;
    return carga.items.map(conGeometria);
  }, [carga]);
}

/** Le pide a la página que dibuje estos objetos en el mapa y deje elegirlos con un clic; null los saca. */
function useElegibles(setElegibles, tipo, items, elegido, elegir) {
  useEffect(() => {
    setElegibles(items ? { tipo, items, elegidoId: elegido?.id ?? null, elegir } : null);
  }, [setElegibles, tipo, items, elegido, elegir]);
  useEffect(() => () => setElegibles(null), [setElegibles]);
}

/** Un objeto para elegir en una lista (zona, incidente o recurso): ícono, nombre y detalle, con un clic se elige. */
function ItemElegible({ tipo, objeto: o, activo, onElegir }) {
  return (
    <li>
      <button type="button" className={activo ? "item item--activo" : "item"} onClick={() => onElegir(o)}>
        {tipo === "zona" && <span className="item__marca item__marca--zona" style={{ "--color": COLOR_PRIORIDAD[o.nivelPrioridad] }} aria-hidden="true" />}
        {tipo === "incidente" && <IconoIncidente tipo={o.tipoIncidente} estado={o.estado} chico />}
        {tipo === "recurso" && <IconoRecurso tipo={o.tipo} estado={o.estadoOperativo} chico />}
        <span className="item__texto">
          <span className="item__titulo">{tipo === "zona" ? o.nombre : tipo === "incidente" ? o.titulo : o.identificacion}</span>
          <span className="item__detalle">
            {tipo === "zona" && `Prioridad ${o.nivelPrioridad}`}
            {tipo === "incidente" && `${o.estado} · prioridad ${o.prioridad}`}
            {tipo === "recurso" && `${nombreTipoRecurso(o.tipo)} · ${o.estadoOperativo}`}
          </span>
        </span>
      </button>
    </li>
  );
}

/** La lista de los objetos de la vista: se elige uno con un clic (igual que en el mapa). */
export function ListaElegible({ carga, tipo, objetos, elegido, onElegir }) {
  const nombre = NOMBRE_OBJETO[tipo];
  if (carga.estado === "lejos") return <Aviso tipo="info">Acercá el mapa para ver y elegir {nombre}.</Aviso>;
  if (carga.estado === "error") return <Aviso tipo="error">No se pudieron cargar {nombre}: {carga.error}</Aviso>;
  if (!objetos) return <p className="ayuda">Cargando {nombre}…</p>;
  if (objetos.length === 0) return <p className="ayuda">No hay {nombre} en esta parte del mapa. Movelo o alejalo para ver otras.</p>;

  return (
    <>
      <p className="ayuda">
        {carga.truncado ? `Mostrando ${objetos.length} de ${carga.total} ${nombre}: acercá el mapa para ver el resto.` : `${objetos.length} ${nombre} en esta parte del mapa.`}{" "}
        Elegí uno con un clic, acá o en el mapa.
      </p>
      <ul className="items">
        {objetos.map((o) => (
          <ItemElegible key={o.id} tipo={tipo} objeto={o} activo={elegido?.id === o.id} onElegir={onElegir} />
        ))}
      </ul>
    </>
  );
}

/**
 * Desplegable para elegir un incidente o un recurso de TODO el sistema (no solo de la parte visible del mapa): al hacer
 * clic en el campo se abre la lista y escribiendo se filtra. Pide pocos resultados a /consultas/buscar. `filtrar`
 * (opcional) descarta resultados, por ejemplo los incidentes ya resueltos.
 */
export function SelectorBuscable({ etiqueta, tipo, onElegir, filtrar, placeholder }) {
  const [texto, setTexto] = useState("");
  const [abierto, setAbierto] = useState(false);
  const [resultados, setResultados] = useState(null);
  const [error, setError] = useState(null);
  const id = useId();

  useEffect(() => {
    if (!abierto) return undefined;
    let vigente = true;
    const espera = setTimeout(() => {
      api
        .get(`/consultas/buscar${query({ tipo, q: texto, limite: 25 })}`)
        .then((lista) => {
          if (!vigente) return;
          setError(null);
          setResultados(lista.map(conGeometria));
        })
        .catch((e) => vigente && setError(e.message));
    }, 200);
    return () => {
      vigente = false;
      clearTimeout(espera);
    };
  }, [tipo, texto, abierto]);

  const mostrados = resultados && (filtrar ? resultados.filter(filtrar) : resultados);

  return (
    <div className="combo">
      <label className="campo" htmlFor={id}>
        <span className="campo__etiqueta">{etiqueta}</span>
        <input
          id={id}
          type="search"
          role="combobox"
          aria-expanded={abierto}
          aria-controls={`${id}-lista`}
          value={texto}
          placeholder={placeholder}
          autoComplete="off"
          onFocus={() => setAbierto(true)}
          onClick={() => setAbierto(true)}
          onBlur={() => setAbierto(false)}
          onKeyDown={(e) => e.key === "Escape" && e.currentTarget.blur()}
          onChange={(e) => {
            setTexto(e.target.value);
            setAbierto(true);
          }}
        />
      </label>
      {abierto && (
        // onMouseDown evita que el campo pierda el foco (y se cierre la lista) antes de que llegue el clic.
        <div className="combo__lista" id={`${id}-lista`} role="listbox" onMouseDown={(e) => e.preventDefault()}>
          {error && <p className="item__detalle item__detalle--error">No se pudo buscar: {error}</p>}
          {!error && !mostrados && <p className="ayuda">Buscando…</p>}
          {mostrados && mostrados.length === 0 && <p className="ayuda">No hay coincidencias.</p>}
          {mostrados && mostrados.length > 0 && (
            <ul className="items">
              {mostrados.map((o) => (
                <ItemElegible
                  key={o.id}
                  tipo={tipo}
                  objeto={o}
                  activo={false}
                  onElegir={(objeto) => {
                    setAbierto(false);
                    document.activeElement?.blur?.();
                    onElegir(objeto);
                  }}
                />
              ))}
            </ul>
          )}
        </div>
      )}
    </div>
  );
}

// ------------------------------------------ 1 y 6: incidentes y recursos por zona

/** Lo que hay dentro de una zona elegida: encabezado, cantidad y lista (incidentes o recursos). */
function ResultadoPorZona({ zona, tipo, fase, datos: r, error, onQuitar }) {
  const nombre = tipo === "incidentes" ? "incidentes" : "recursos";
  return (
    <section className="bloque">
      <h4 className="resultado__grupo">{zona.nombre}</h4>
      <Estado fase={fase} error={error} />
      {r && (
        <>
          <p className="ayuda">
            {r.total} {r.total === 1 ? nombre.slice(0, -1) : nombre} en la zona.
          </p>
          <Truncado r={r} nombre={nombre} />
          <ul className="items">
            {r.items.map((f) => (tipo === "incidentes" ? <FilaIncidente key={f.id} i={f} /> : <FilaRecurso key={f.id} r={f} />))}
          </ul>
        </>
      )}
      <button type="button" className="btn btn--secundario" onClick={onQuitar}>
        Elegir otra zona
      </button>
    </section>
  );
}

/** Incidentes o recursos que están dentro de una zona elegida entre las que se ven en el mapa. */
function PanelPorZona({ setResultado, setElegibles, carga, tipo }) {
  const [zona, setZona] = useState(null);
  const zonas = useObjetosDeLaVista(carga);
  useElegibles(setElegibles, "zona", zonas, zona, setZona);
  const { fase, datos: r, error } = useRuta(zona ? `/consultas/${tipo}-por-zona/${zona.id}` : null);

  useEffect(() => {
    if (!r || !zona) {
      setResultado(RESULTADO_VACIO);
      return;
    }
    setResultado({ ...RESULTADO_VACIO, zonas: [comoZona(zona)], [tipo]: r.items.map(conGeometria) });
  }, [r, zona, tipo, setResultado]);

  return (
    <>
      {zona && <ResultadoPorZona zona={zona} tipo={tipo} fase={fase} datos={r} error={error} onQuitar={() => setZona(null)} />}
      {!zona && <ListaElegible carga={carga} tipo="zona" objetos={zonas} elegido={zona} onElegir={setZona} />}
    </>
  );
}

const PanelIncidentesZona = (props) => <PanelPorZona {...props} tipo="incidentes" />;
const PanelRecursosZona = (props) => <PanelPorZona {...props} tipo="recursos" />;

// ------------------------------------------------------ 3: recursos cercanos a un incidente

const CANTIDADES = [1, 2, 3, 5, 10];

/** Leyenda del color del recorrido en el mapa (el que dibuja CapaResultado). */
function LeyendaRutas() {
  return (
    <ul className="leyenda-ruta" aria-label="Leyenda del mapa">
      <li>
        <span className="leyenda-ruta__muestra leyenda-ruta__muestra--ruta" aria-hidden="true" />
        Verde: recorrido por calles
      </li>
    </ul>
  );
}

/** Una tarjeta por recurso: distancia directa, distancia por calles, tiempo y disponibilidad de la ruta. */
function FilaRecursoCercano({ it, elegido, mejor, onElegir }) {
  const hayRuta = it.estadoRuta === "disponible";
  const sinRuta = it.estadoRuta === "sin_ruta" || it.estadoRuta === "error";
  return (
    <li>
      <button type="button" className={elegido ? "item item--activo" : "item"} onClick={onElegir} aria-pressed={elegido}>
        <IconoRecurso tipo={it.tipo} estado={it.estadoOperativo} chico />
        <span className="item__texto">
          <span className="item__titulo">{it.identificacion}</span>
          <span className="item__detalle">
            {nombreTipoRecurso(it.tipo)} · {it.estadoOperativo}
          </span>
          <span className="item__detalle">Directa: {metros(it.distanciaDirectaM)}</span>
          {hayRuta && (
            <span className="item__detalle">
              Por calles: {metros(it.distanciaViaM)} · {it.tiempoEstimadoMinutos} min
            </span>
          )}
          {sinRuta && <span className="item__detalle">Ruta no disponible</span>}
          {hayRuta && it.advertencia && <span className="item__detalle">⚠ {it.advertencia}</span>}
        </span>
        {mejor && <Insignia color="#16a34a">Más cercano por calles</Insignia>}
      </button>
    </li>
  );
}

function PanelRecursosCercanos({ setResultado, setElegibles, carga }) {
  const [incidente, setIncidente] = useState(null);
  const [limite, setLimite] = useState(5);
  const [soloDisponibles, setSoloDisponibles] = useState(true);
  const { aviso: avisoRutas } = useRutasDisponibles();
  const [elegidoId, setElegidoId] = useState(null);
  const [calculo, setCalculo] = useState(null); // rutas pedidas: { base, fase, datos, error }

  const incidentes = useObjetosDeLaVista(carga);
  const elegirIncidente = useCallback((objeto) => {
    setIncidente(objeto);
    setElegidoId(null);
  }, []);
  useElegibles(setElegibles, "incidente", incidentes, incidente, elegirIncidente);

  // Buscar los recursos más cercanos solo usa PostGIS; las rutas por calles se piden recién con el botón.
  const base = incidente ? `/consultas/recursos-cercanos/${incidente.id}/analisis-vial${query({ limite, soloDisponibles })}` : null;
  const { fase, datos: previo, error } = useRuta(base);

  const calculoVigente = calculo && calculo.base === base ? calculo : null;
  const datos = calculoVigente?.datos ?? previo;
  const calculando = calculoVigente?.fase === "cargando";
  const conRutas = Boolean(calculoVigente?.datos);

  const calcularRutas = () => {
    if (!base || avisoRutas) return;
    setCalculo({ base, fase: "cargando", datos: null, error: null });
    api
      .get(`${base}&conRutas=true`)
      .then((d) => setCalculo((c) => (c?.base === base ? { base, fase: "ok", datos: d, error: null } : c)))
      .catch((e) => setCalculo((c) => (c?.base === base ? { base, fase: "error", datos: null, error: e.message } : c)));
  };

  useEffect(() => {
    if (!datos || !incidente) {
      setResultado(RESULTADO_VACIO);
      return;
    }
    const recursos = datos.items.map((it) => ({
      ...conGeometria(it),
      id: it.recursoId,
      elegido: it.recursoId === elegidoId,
      alElegir: () => setElegidoId(it.recursoId),
    }));
    const rutas = datos.items
      .filter((it) => it.estadoRuta === "disponible")
      .map((it) => ({
        id: it.recursoId,
        geometria: it.geometriaRuta,
        texto: `${it.identificacion}: ${metros(it.distanciaViaM)} por calles · ${it.tiempoEstimadoMinutos} min`,
        elegida: it.recursoId === elegidoId,
      }));
    setResultado({
      ...RESULTADO_VACIO,
      incidentes: [incidente],
      recursos,
      rutas,
      ajuste: `${incidente.id}|${limite}|${soloDisponibles}`, // elegir un recurso o ver sus rutas no mueve el mapa
    });
  }, [datos, incidente, elegidoId, limite, soloDisponibles, setResultado]);

  const items = datos?.items ?? [];

  return (
    <>
      <label className="campo">
        <span className="campo__etiqueta">Cuántos recursos</span>
        <select value={limite} onChange={(e) => setLimite(Number(e.target.value))}>
          {CANTIDADES.map((n) => (
            <option key={n} value={n}>
              {n}
            </option>
          ))}
        </select>
      </label>
      <label className="casilla">
        <input type="checkbox" checked={soloDisponibles} onChange={(e) => setSoloDisponibles(e.target.checked)} />
        Solo recursos disponibles
      </label>
      {avisoRutas && <Aviso tipo="error">{avisoRutas}</Aviso>}

      <button type="button" className="btn btn--primario btn--ancho" onClick={calcularRutas} disabled={!incidente || items.length === 0 || calculando || conRutas || Boolean(avisoRutas)}>
        {calculando ? "Calculando rutas…" : conRutas ? "Rutas por calles calculadas" : "Calcular rutas por calles"}
      </button>
      <p className="ayuda">
        {!incidente
          ? "Elegí un incidente y se calcula el recorrido por calles de los recursos más cercanos."
          : datos && items.length > 0 && !conRutas
            ? `Se calculan las rutas de los ${Math.min(items.length, datos.rutasMaximas)} recursos más cercanos.`
            : null}
      </p>

      {!incidente && <ListaElegible carga={carga} tipo="incidente" objetos={incidentes} elegido={incidente} onElegir={elegirIncidente} />}

      {incidente && (
        <section className="bloque">
          <h4 className="resultado__grupo">{incidente.titulo}</h4>
          {fase === "cargando" && <p className="ayuda">Buscando los recursos más cercanos…</p>}
          {fase === "error" && <Aviso tipo="error">{error}</Aviso>}
          {datos && items.length === 0 && (
            <p className="ayuda">No hay recursos {soloDisponibles ? "disponibles " : ""}para mostrar. Probá quitar el filtro de disponibles.</p>
          )}
          {datos && items.length > 0 && (
            <>
              <p className="ayuda">
                {items.length === 1 ? "El recurso más cercano" : `Los ${items.length} recursos más cercanos`} al incidente, de menor a mayor distancia directa. Elegí uno para resaltarlo en el mapa.
              </p>
              <ul className="items">
                {items.map((it) => (
                  <FilaRecursoCercano
                    key={it.recursoId}
                    it={it}
                    elegido={it.recursoId === elegidoId}
                    mejor={conRutas && it.recursoId === datos.recursoMasCercanoId}
                    onElegir={() => setElegidoId(it.recursoId === elegidoId ? null : it.recursoId)}
                  />
                ))}
              </ul>
              {calculando && <p className="ayuda">Calculando rutas por calles…</p>}
              {calculoVigente?.fase === "error" && <Aviso tipo="error">{calculoVigente.error}</Aviso>}
              {conRutas && datos.rutasDisponibles === 0 && <Aviso tipo="error">Ruta no disponible: no se pudo obtener ningún recorrido por calles. Se muestra la distancia directa.</Aviso>}
              {conRutas && datos.rutasDisponibles > 0 && datos.rutasDisponibles < Math.min(items.length, datos.rutasMaximas) && (
                <Aviso>Algunos recursos no tienen ruta disponible; conservan su distancia directa.</Aviso>
              )}
              {conRutas && (
                <p className="ayuda">
                  Los recorridos son el <strong>camino más corto</strong> (menos metros) por calles, respetando los sentidos de circulación. Tiempo estimado sin tráfico en tiempo real.
                </p>
              )}
              {conRutas && datos.rutasDisponibles > 0 && <LeyendaRutas />}
            </>
          )}
          <button type="button" className="btn btn--secundario" onClick={() => elegirIncidente(null)}>
            Elegir otro incidente
          </button>
        </section>
      )}
    </>
  );
}


// ------------------------------------- elegir el punto por intersección de dos calles

/** Campo de texto con sugerencias de nombres de calle (se piden a la API mientras se escribe). */
function CampoCalle({ etiqueta, valor, onChange }) {
  const [sugerencias, setSugerencias] = useState([]);
  const id = useId();

  useEffect(() => {
    // Las sugerencias salen de la red vial de todo el país (OpenStreetMap), con o sin tildes.
    if (valor.trim().length < 2) {
      setSugerencias([]);
      return undefined;
    }
    let vigente = true;
    const espera = setTimeout(() => {
      api
        .get(`/consultas/calles${query({ q: valor.trim() })}`)
        .then((lista) => vigente && setSugerencias(lista))
        .catch(() => {}); // sin sugerencias se puede escribir igual
    }, 250);
    return () => {
      vigente = false;
      clearTimeout(espera);
    };
  }, [valor]);

  return (
    <label className="campo">
      <span className="campo__etiqueta">{etiqueta}</span>
      <input list={id} value={valor} onChange={(e) => onChange(e.target.value)} placeholder="Escribí y elegí de la lista" autoComplete="off" />
      <datalist id={id}>
        {sugerencias.map((nombre) => (
          <option key={nombre} value={nombre} />
        ))}
      </datalist>
    </label>
  );
}

/**
 * Alternativa al clic en el mapa: ubica el punto donde se cruzan dos calles y lo deja como punto de búsqueda.
 * Se busca en TODO el país con la red vial de OpenStreetMap que está en la base (/consultas/interseccion), sin internet. Si las
 * dos calles se cruzan en varios lugares (una calle se repite en muchas localidades) se listan, del más cercano a la región
 * al más lejano, cada uno con la ciudad, el pueblo o el barrio más próximo. Si no se cruzan en la red, se prueba con el servicio
 * de direcciones de la IDE como "esquina" (/consultas/geocodificar).
 */
function BuscadorIntersecciones({ setPunto }) {
  const [calle1, setCalle1] = useState("");
  const [calle2, setCalle2] = useState("");
  const [busqueda, setBusqueda] = useState({ fase: "quieto", cruces: [], elegido: 0, error: null, ide: false });

  const esquinaPorIde = async () => [
    await api.get(`/consultas/geocodificar${query({ direccion: calle1.trim(), esquina: calle2.trim(), ...REGION.ide })}`),
  ];

  const buscar = async (evento) => {
    evento.preventDefault();
    setBusqueda({ fase: "cargando", cruces: [], elegido: 0, error: null, ide: false });
    try {
      const [lat, lon] = REGION.centro;
      let cruces = await api.get(`/consultas/interseccion${query({ calle1: calle1.trim(), calle2: calle2.trim(), cercaLon: lon, cercaLat: lat })}`);
      let ide = false;
      if (cruces.length === 0) {
        // Sin cruce en la red vial: se prueba con el servicio de la IDE.
        try {
          cruces = await esquinaPorIde();
          ide = true;
        } catch {
          // sin cruce en la IDE tampoco: se avisa abajo
        }
      }
      setBusqueda({ fase: "ok", cruces, elegido: 0, error: null, ide });
      if (cruces.length > 0) setPunto([cruces[0].lat, cruces[0].lon]);
    } catch (e) {
      setBusqueda({ fase: "error", cruces: [], elegido: 0, error: e.message, ide: false });
    }
  };

  const elegir = (n) => {
    setBusqueda((b) => ({ ...b, elegido: n }));
    setPunto([busqueda.cruces[n].lat, busqueda.cruces[n].lon]);
  };

  /** El lugar más próximo al cruce (ciudad, pueblo o barrio), por ejemplo "Centro" o "Algorta". */
  const rotulo = (c) => c.lugar ?? "Cruce";

  const { fase, cruces, elegido, ide } = busqueda;
  return (
    <form className="bloque" onSubmit={buscar}>
      <h4 className="bloque__titulo">O por intersección de calles</h4>
      <CampoCalle etiqueta="Calle" valor={calle1} onChange={setCalle1} />
      <CampoCalle etiqueta="y calle" valor={calle2} onChange={setCalle2} />
      <button type="submit" className="btn btn--secundario" disabled={!calle1.trim() || !calle2.trim() || fase === "cargando"}>
        {fase === "cargando" ? "Buscando…" : "Ubicar el cruce"}
      </button>
      {fase === "error" && <Aviso tipo="error">{busqueda.error}</Aviso>}
      {fase === "ok" && cruces.length === 0 && (
        <Aviso tipo="info">Esas calles no se cruzan, o algún nombre no existe. Elegí los nombres de la lista de sugerencias.</Aviso>
      )}
      {fase === "ok" && ide && cruces.length === 1 && (
        <Aviso tipo="ok">
          Esquina ubicada (servicio de la IDE): <strong>{cruces[0].direccion}</strong>
        </Aviso>
      )}
      {fase === "ok" && !ide && cruces.length === 1 && (
        <Aviso tipo="ok">
          Cruce ubicado: <strong>{rotulo(cruces[0])}</strong>
        </Aviso>
      )}
      {cruces.length > 1 && (
        <>
          <p className="ayuda">Hay {cruces.length} cruces con esos nombres en el país. Elegí uno:</p>
          <ul className="items">
            {cruces.map((c, n) => (
              <li key={n}>
                <button type="button" className={n === elegido ? "item item--activo" : "item"} onClick={() => elegir(n)} aria-pressed={n === elegido}>
                  <span className="item__texto">
                    <span className="item__titulo">{rotulo(c)}</span>
                    <span className="item__detalle">Cruce {n + 1}</span>
                  </span>
                </button>
              </li>
            ))}
          </ul>
        </>
      )}
    </form>
  );
}

// ------------------------------------------------ elegir el punto escribiendo una dirección

/**
 * Ubica una dirección ("calle número") y la deja como punto de búsqueda (ver /consultas/geocodificar).
 * Se busca en TODO el país: primero en los números de puerta propios de Salto y, si no está, en el servicio de
 * direcciones de la IDE (los 19 departamentos). Si la calle existe en varios lugares se ubica la mejor coincidencia y se
 * ofrecen las demás. También se puede limitar la búsqueda a un departamento.
 */
function BuscadorDireccion({ setPunto }) {
  const [texto, setTexto] = useState("");
  const [donde, setDonde] = useState("todo"); // "todo" o un departamento
  const [busqueda, setBusqueda] = useState({ fase: "quieto", resultado: null, error: null });

  const buscar = async (evento) => {
    evento.preventDefault();
    setBusqueda({ fase: "cargando", resultado: null, error: null });
    try {
      const r = await api.get(`/consultas/geocodificar${query({ direccion: texto.trim(), departamento: donde })}`);
      setBusqueda({ fase: "ok", resultado: r, error: null });
      setPunto([r.lat, r.lon]);
    } catch (e) {
      setBusqueda({ fase: "error", resultado: null, error: e.message });
    }
  };

  // Elegir una de las otras coincidencias: el punto pasa a ser ese lugar.
  const elegirAlternativa = (a) => {
    setBusqueda({ fase: "ok", resultado: { ...a, fuente: "IDE", aviso: a.aproximada ? "No se encontró ese número de puerta: se ubicó sobre la calle (aproximado)." : null, alternativas: [] }, error: null });
    setPunto([a.lat, a.lon]);
  };

  const { fase, resultado, error } = busqueda;
  return (
    <form className="bloque" onSubmit={buscar}>
      <h4 className="bloque__titulo">Por dirección</h4>
      <label className="campo">
        <span className="campo__etiqueta">Calle y número</span>
        <input value={texto} onChange={(e) => setTexto(e.target.value)} placeholder={`Ej.: ${REGION.ejemploDireccion}`} autoComplete="off" />
      </label>
      <label className="campo">
        <span className="campo__etiqueta">Dónde buscar</span>
        <select value={donde} onChange={(e) => setDonde(e.target.value)}>
          <option value="todo">Todo el país</option>
          {DEPARTAMENTOS.map((d) => (
            <option key={d.valor} value={d.valor}>
              {d.nombre}
            </option>
          ))}
        </select>
      </label>
      <button type="submit" className="btn btn--secundario" disabled={!texto.trim() || fase === "cargando"}>
        {fase === "cargando" ? "Buscando…" : "Ubicar la dirección"}
      </button>
      {fase === "error" && <Aviso tipo="error">{error}</Aviso>}
      {fase === "ok" && (
        <Aviso tipo={resultado.aproximada ? "info" : "ok"}>
          {resultado.aproximada ? resultado.aviso : "Dirección ubicada"}: <strong>{resultado.direccion}</strong>
          {resultado.fuente === "IDE" && resultado.departamento && ` — ${nombreLugar(resultado.localidad)}, ${nombreLugar(resultado.departamento)}`}
          {resultado.fuente === "IDE" ? " (servicio de la IDE)" : ""}
        </Aviso>
      )}
      {fase === "ok" && resultado.alternativas?.length > 0 && (
        <>
          <p className="ayuda">Hay otras coincidencias en el país:</p>
          <ul className="items">
            {resultado.alternativas.map((a) => (
              <li key={`${a.direccion}-${a.localidad}-${a.departamento}`}>
                <button type="button" className="item" onClick={() => elegirAlternativa(a)}>
                  <span className="item__texto">
                    <span className="item__titulo">{a.direccion}</span>
                    <span className="item__detalle">
                      {nombreLugar(a.localidad)}, {nombreLugar(a.departamento)}
                      {a.aproximada ? " · aproximada" : ""}
                    </span>
                  </span>
                </button>
              </li>
            ))}
          </ul>
        </>
      )}
    </form>
  );
}

/** Las tres formas de elegir el punto además del clic: dirección o cruce de calles. */
function BuscadoresDePunto({ setPunto }) {
  return (
    <>
      <BuscadorDireccion setPunto={setPunto} />
      <BuscadorIntersecciones setPunto={setPunto} />
      <p className="ayuda">
        Las direcciones se buscan en todo el país: primero en los números de puerta de Salto (capa «acceso» de GeoServer) y después en el servicio de
        direcciones de la IDE (necesita internet). Los cruces de calles también se buscan en todo el país, con la red vial de la base (sin internet).
      </p>
    </>
  );
}

// ---------------------------- 4: búsqueda de incidente (incidente más cercano a un punto)

function PanelIncidenteCercano({ punto, setPunto, setResultado }) {
  const { fase, datos: dato, error } = useRuta(punto ? `/consultas/incidente-mas-cercano?lon=${punto[1]}&lat=${punto[0]}` : null);

  useEffect(() => {
    if (!dato?.id) {
      setResultado(RESULTADO_VACIO);
      return;
    }
    const incidente = conGeometria(dato);
    setResultado({ ...RESULTADO_VACIO, incidentes: [incidente], lineas: [{ desde: punto, hasta: incidente.pos, texto: metros(dato.distanciaM) }] });
  }, [dato, punto, setResultado]);

  return (
    <>
      {!punto && <Aviso tipo="info">Hacé clic en el mapa, o escribí una dirección, para elegir el punto de búsqueda.</Aviso>}
      <Estado fase={fase} error={error} />
      {fase === "ok" && !dato?.id && <p className="ayuda">No hay incidentes registrados.</p>}
      {dato?.id && (
        <ul className="items">
          <FilaIncidente i={dato} extra={<span className="resultado__dato">{metros(dato.distanciaM)}</span>} />
        </ul>
      )}
      <BuscadoresDePunto setPunto={setPunto} />
    </>
  );
}

// -------------------------------------------------- 5: búsqueda de zona (zonas de un punto)

/** Las zonas pueden superponerse: un punto puede estar en varias, y se muestran todas. */
function PanelZonaPunto({ punto, setPunto, setResultado }) {
  const { fase, datos: r, error } = useRuta(punto ? `/consultas/zona-por-punto?lon=${punto[1]}&lat=${punto[0]}` : null);
  const zonas = r?.items;

  useEffect(() => {
    setResultado(zonas?.length ? { ...RESULTADO_VACIO, zonas: zonas.map((z) => comoZona(z, 0.25)) } : RESULTADO_VACIO);
  }, [zonas, setResultado]);

  return (
    <>
      {!punto && <Aviso tipo="info">Hacé clic en el mapa, o escribí una dirección, para elegir el punto a ubicar.</Aviso>}
      <Estado fase={fase} error={error} />
      {zonas?.length > 0 && (
        <>
          <p className="ayuda">
            El punto está en {zonas.length} {zonas.length === 1 ? "zona operativa" : "zonas operativas (se superponen)"}:
          </p>
          <ul className="items">
            {zonas.map((zona) => (
              <li key={zona.id} className="fila">
                <span className="item__marca item__marca--zona" style={{ "--color": COLOR_PRIORIDAD[zona.nivelPrioridad] }} aria-hidden="true" />
                <span className="item__texto">
                  <span className="item__titulo">{zona.nombre}</span>
                  <span className="item__detalle">
                    Prioridad {zona.nivelPrioridad}
                    {zona.responsable ? ` · ${zona.responsable}` : ""}
                  </span>
                </span>
              </li>
            ))}
          </ul>
        </>
      )}
      {fase === "ok" && zonas?.length === 0 && <Aviso tipo="info">El punto no está dentro de ninguna zona operativa.</Aviso>}
      <BuscadoresDePunto setPunto={setPunto} />
    </>
  );
}

// -------------------------------------------------------------- 7: incidentes por recurso

function PanelIncidentesRecurso({ setResultado, setElegibles, carga }) {
  const [recurso, setRecurso] = useState(null);
  const recursos = useObjetosDeLaVista(carga);
  useElegibles(setElegibles, "recurso", recursos, recurso, setRecurso);
  const { fase, datos: r, error } = useRuta(recurso ? `/consultas/incidentes-por-recurso/${recurso.id}` : null);

  useEffect(() => {
    if (!r || !recurso) {
      setResultado(RESULTADO_VACIO);
      return;
    }
    const incidentes = r.items.map(conGeometria);
    const lineas = incidentes.map((i) => ({ desde: recurso.pos, hasta: i.pos, texto: i.titulo }));
    setResultado({ ...RESULTADO_VACIO, recursos: [recurso], incidentes, lineas });
  }, [r, recurso, setResultado]);

  return (
    <>
      {recurso && (
        <section className="bloque">
          <h4 className="resultado__grupo">{recurso.identificacion}</h4>
          <Estado fase={fase} error={error} />
          {r && r.items.length === 0 && <p className="ayuda">Este recurso no tiene incidentes asignados.</p>}
          {r && r.items.length > 0 && (
            <>
              <Truncado r={r} nombre="incidentes" />
              <ul className="items">
                {r.items.map((f) => (
                  <FilaIncidente key={f.id} i={f} />
                ))}
              </ul>
            </>
          )}
          <button type="button" className="btn btn--secundario" onClick={() => setRecurso(null)}>
            Elegir otro recurso
          </button>
        </section>
      )}
      {!recurso && <ListaElegible carga={carga} tipo="recurso" objetos={recursos} elegido={recurso} onElegir={setRecurso} />}
    </>
  );
}

// ------------------------------------------------ 2: zonas con mayor cantidad de incidentes

/**
 * Ranking de las zonas que se ven en el mapa (el backend cuenta solo las del bbox visible). En el mapa, cuanto
 * más oscura la zona, más incidentes. Elegir una zona (en el ranking o con un clic en el mapa) muestra sus incidentes.
 */
function PanelRankings({ setResultado, setElegibles, vista }) {
  const [desde, setDesde] = useState("");
  const [hasta, setHasta] = useState("");
  const [zona, setZona] = useState(null);

  const ruta = vista ? `/consultas/zonas-mas-incidentes${query({ desde, hasta: diaSiguiente(hasta), bbox: vista.bbox })}` : null;
  const { fase, datos, error } = useRuta(ruta);
  // Mientras se pide el de la vista nueva se sigue mostrando el anterior (sin parpadeos al mover el mapa).
  const anterior = useRef(null);
  if (datos) anterior.current = datos;
  const r = datos ?? anterior.current;
  const filas = r?.items;
  const maximo = Math.max(0, ...(filas ?? []).map((z) => Number(z.cantidadIncidentes)));

  const zonas = useMemo(
    () => (filas ? filas.map((z) => comoZona(z, maximo > 0 ? Number(z.cantidadIncidentes) / maximo : 0)) : null),
    [filas, maximo],
  );
  useElegibles(setElegibles, "zona", zonas, zona, setZona);

  const { fase: faseZona, datos: incidentesZona, error: errorZona } = useRuta(zona ? `/consultas/incidentes-por-zona/${zona.id}` : null);
  useEffect(() => {
    if (!zona || !incidentesZona) {
      setResultado(RESULTADO_VACIO);
      return;
    }
    setResultado({ ...RESULTADO_VACIO, zonas: [comoZona(zona)], incidentes: incidentesZona.items.map(conGeometria) });
  }, [zona, incidentesZona, setResultado]);

  return (
    <>
      <div className="campos-2">
        <label className="campo">
          <span className="campo__etiqueta">Desde</span>
          <input type="date" value={desde} onChange={(e) => setDesde(e.target.value)} />
        </label>
        <label className="campo">
          <span className="campo__etiqueta">Hasta</span>
          <input type="date" value={hasta} onChange={(e) => setHasta(e.target.value)} />
        </label>
      </div>
      <p className="ayuda">Incidentes registrados dentro de cada zona que se ve en el mapa, en el período. Sin fechas se cuenta todo el historial.</p>
      {zona && <ResultadoPorZona zona={zona} tipo="incidentes" fase={faseZona} datos={incidentesZona} error={errorZona} onQuitar={() => setZona(null)} />}
      {!zona && (
        <>
          <Estado fase={fase === "error" ? "error" : !r ? "cargando" : "ok"} error={error} />
          <Truncado r={r} nombre="zonas (las de mayor valor)" />
          {filas && filas.length === 0 && <p className="ayuda">No hay zonas operativas en esta parte del mapa.</p>}
          {filas && filas.length > 0 && (
            <>
              <p className="ayuda">Elegí una zona con un clic, acá o en el mapa, para ver sus incidentes.</p>
              <ol className="ranking">
                {filas.map((z, i) => {
                  const valor = Number(z.cantidadIncidentes);
                  const porcentaje = maximo > 0 ? Math.max((valor / maximo) * 100, valor > 0 ? 3 : 0) : 0;
                  return (
                    <li key={z.id}>
                      <button type="button" className={i === 0 && valor > 0 ? "ranking__fila ranking__fila--primero" : "ranking__fila"} onClick={() => setZona(zonas[i])}>
                        <span className="ranking__nombre">{z.nombre}</span>
                        <span className="ranking__barra" aria-hidden="true">
                          <span style={{ width: `${porcentaje}%` }} />
                        </span>
                        <span className="ranking__valor">
                          {valor}
                          <small> {valor === 1 ? "incidente" : "incidentes"}</small>
                        </span>
                      </button>
                    </li>
                  );
                })}
              </ol>
            </>
          )}
        </>
      )}
    </>
  );
}

// ------------------------------------------ reporte de incidentes por zona (filtros)

function PanelReporte({ setResultado }) {
  const [filtros, setFiltros] = useState({ zonaId: "", tipo: "", prioridad: "", estado: "", desde: "", hasta: "" });
  const cambiar = (clave) => (valor) => setFiltros((f) => ({ ...f, [clave]: valor }));

  const ruta = `/consultas/reportes/incidentes-por-zona${query({ ...filtros, hasta: diaSiguiente(filtros.hasta) })}`;
  const { fase, datos: r, error } = useRuta(ruta);
  const filas = r?.items;
  const { datos: tiposIncidente } = useRuta("/consultas/tipos-incidente");

  const grupos = useMemo(() => {
    const porZona = new Map();
    (filas ?? []).forEach((f) => {
      if (!porZona.has(f.zonaId)) porZona.set(f.zonaId, { zonaId: f.zonaId, nombre: f.zonaNombre, incidentes: [] });
      porZona.get(f.zonaId).incidentes.push(f);
    });
    return [...porZona.values()];
  }, [filas]);

  useEffect(() => {
    if (!filas) {
      setResultado(RESULTADO_VACIO);
      return;
    }
    // Un incidente que cruza dos zonas aparece en las dos filas del reporte: se dibuja una sola vez.
    const unicos = new Map(filas.map((f) => [f.id, f]));
    setResultado({ ...RESULTADO_VACIO, incidentes: [...unicos.values()].map(conGeometria) });
  }, [filas, setResultado]);

  const tipos = (tiposIncidente ?? []).map((t) => ({ valor: t, texto: t }));

  return (
    <>
      <BuscadorObjeto
        etiqueta="Zona"
        tipo="zona"
        onChange={(zona) => cambiar("zonaId")(zona ? zona.id : "")}
        placeholder="Todas (escribí para elegir una)"
      />
      <Selector etiqueta="Tipo" valor={filtros.tipo} onChange={cambiar("tipo")} opciones={tipos} vacio="Todos" />
      <div className="campos-2">
        <Selector
          etiqueta="Prioridad"
          valor={filtros.prioridad}
          onChange={cambiar("prioridad")}
          opciones={[1, 2, 3, 4, 5].map((n) => ({ valor: n, texto: String(n) }))}
          vacio="Todas"
        />
        <Selector
          etiqueta="Estado"
          valor={filtros.estado}
          onChange={cambiar("estado")}
          opciones={ESTADOS_INCIDENTE.map((e) => ({ valor: e, texto: e }))}
          vacio="Todos"
        />
      </div>
      <div className="campos-2">
        <label className="campo">
          <span className="campo__etiqueta">Desde</span>
          <input type="date" value={filtros.desde} onChange={(e) => cambiar("desde")(e.target.value)} />
        </label>
        <label className="campo">
          <span className="campo__etiqueta">Hasta</span>
          <input type="date" value={filtros.hasta} onChange={(e) => cambiar("hasta")(e.target.value)} />
        </label>
      </div>
      <Estado fase={fase} error={error} />
      {filas && (
        <p className="ayuda">
          {r.total} {r.total === 1 ? "incidente" : "incidentes"} en {grupos.length} {grupos.length === 1 ? "zona" : "zonas"}.
        </p>
      )}
      <Truncado r={r} nombre="incidentes" />
      {grupos.map((g) => (
        <section key={g.zonaId}>
          <h4 className="resultado__grupo">
            {g.nombre} — {g.incidentes.length}
          </h4>
          <ul className="items">
            {g.incidentes.map((i) => (
              <FilaIncidente key={`${g.zonaId}-${i.id}`} i={i} />
            ))}
          </ul>
        </section>
      ))}
    </>
  );
}

// ------------------------------------------------------------------------ el catálogo

/**
 * Orden y textos del selector de la página. Los números son los de las "Consultas geográficas" de la letra.
 *   pideClic     la consulta usa un punto del mapa, así que la página escucha los clics.
 *   objetos      ruta de los objetos que se eligen (se cargan los de la vista, ver CargaPorZona): "/zonas", "/incidentes" o "/recursos".
 *   sobreVista   la consulta pide al backend solo lo de la vista (bbox), como el ranking de zonas.
 *   fondo        el único tipo de objeto que GeoServer dibuja de fondo: "zona", "incidente" o "recurso".
 *   soloAdmin    el invitado no la ve.
 *   postgis      qué función espacial la resuelve.
 */
export const CONSULTAS = [
  {
    id: "incidentes-zona",
    fondo: "zona", // lo que GeoServer dibuja de fondo
    titulo: "1. Incidentes por zona",
    descripcion: "Se ven las zonas de esta parte del mapa. Elegí una (con un clic en el mapa o en la lista) y se muestran los incidentes que están dentro de ella.",
    postgis: "ST_Intersects(zona, incidente)",
    objetos: "/zonas",
    Panel: PanelIncidentesZona,
  },
  {
    id: "rankings",
    fondo: "zona", // lo que GeoServer dibuja de fondo
    titulo: "2. Zonas con mayor cantidad de incidentes",
    descripcion: "Ranking de las zonas que se ven en el mapa por cantidad de incidentes en un período. En el mapa, más oscura = más incidentes. Elegí una zona para ver sus incidentes.",
    postgis: "ST_Intersects + COUNT, solo para las zonas del rectángulo visible",
    sobreVista: true,
    Panel: PanelRankings,
  },
  {
    id: "recursos-cercanos",
    fondo: "incidente", // lo que GeoServer dibuja de fondo
    titulo: "3. Recursos cercanos a un incidente",
    descripcion: "Se ven los incidentes de esta parte del mapa. Elegí uno y cuántos recursos querés: se muestran los más cercanos, con la distancia directa. Con \"Calcular rutas por calles\" se agrega el recorrido más corto por las calles de los más cercanos.",
    postgis: "Operador <-> (vecino más cercano con índice GiST) y ST_Distance (distancia directa); camino más corto por calles con pgRouting",
    objetos: "/incidentes",
    Panel: PanelRecursosCercanos,
  },
  {
    id: "incidente-cercano",
    fondo: "incidente", // lo que GeoServer dibuja de fondo
    titulo: "4. Búsqueda de incidente (dirección, cruce o punto)",
    descripcion: "Elegí un punto con un clic en el mapa, escribí una dirección o ubicá el cruce de dos calles, y se busca el incidente más cercano.",
    postgis: "operador <-> y ST_Distance; la dirección con la tabla de puertas (Salto) o la IDE (resto del país); el cruce de calles con ST_Intersection",
    pideClic: true,
    Panel: PanelIncidenteCercano,
  },
  {
    id: "zona-punto",
    fondo: "zona", // lo que GeoServer dibuja de fondo
    titulo: "5. Búsqueda de zona (dirección, cruce o punto)",
    descripcion: "Elegí un punto con un clic en el mapa, escribí una dirección o ubicá el cruce de dos calles, y se indican las zonas operativas a las que pertenece (pueden ser varias: las zonas se superponen).",
    postgis: "ST_Contains(zona, punto); la dirección con la tabla de puertas (Salto) o la IDE (resto del país); el cruce de calles con ST_Intersection",
    pideClic: true,
    Panel: PanelZonaPunto,
  },
  {
    id: "recursos-zona",
    fondo: "zona", // lo que GeoServer dibuja de fondo
    titulo: "6. Recursos por zona",
    descripcion: "Se ven las zonas de esta parte del mapa. Elegí una (con un clic en el mapa o en la lista) y se muestran los recursos de emergencia que están dentro de ella.",
    postgis: "ST_Contains(zona, recurso)",
    objetos: "/zonas",
    Panel: PanelRecursosZona,
  },
  {
    id: "incidentes-recurso",
    fondo: "recurso", // lo que GeoServer dibuja de fondo
    titulo: "7. Incidentes por recurso",
    descripcion: "Se ven los recursos de esta parte del mapa. Elegí uno y se muestran los incidentes que tiene asignados.",
    postgis: "tabla incidente_recurso (relación recurso-incidente)",
    objetos: "/recursos",
    Panel: PanelIncidentesRecurso,
  },
  {
    id: "reporte",
    soloAdmin: true, // el invitado no lo ve ni puede pedirlo (la API lo exige, ver AuthFilter)
    fondo: "zona", // lo que GeoServer dibuja de fondo
    titulo: "Reporte de incidentes por zona",
    descripcion: "Listado filtrable por zona, tipo, prioridad, estado y fechas, agrupado por zona.",
    postgis: "ST_Contains(zona, incidente) con filtros",
    Panel: PanelReporte,
  },
];
