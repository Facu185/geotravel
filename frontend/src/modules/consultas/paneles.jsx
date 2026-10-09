import { useEffect, useId, useMemo, useState } from "react";
import { Aviso, Insignia, Segmentado, Selector } from "../../components/ui.jsx";
import { COLOR_ESTADO_INCIDENTE, COLOR_ESTADO_RECURSO, COLOR_PRIORIDAD } from "../../components/colores.js";
import { api } from "../../api/client.js";

/**
 * Las consultas geográficas de la letra, un panel por consulta. Todas siguen el mismo patrón:
 *   1. el usuario elige los parámetros (una zona, un incidente, un punto del mapa, fechas...);
 *   2. se llama a /api/consultas/... y el cálculo lo hace PostGIS en el backend;
 *   3. el resultado se muestra como lista y, con setResultado, también dibujado en el mapa.
 *
 * Las consultas devuelven solo ids y datos, sin geometría: para dibujar, la página ya trae
 * las zonas, incidentes y recursos (con su geometría) y acá se cruzan por id.
 */

/** Lo que un panel le pide dibujar al mapa. */
export const RESULTADO_VACIO = {
  zonas: {}, // { [zonaId]: intensidad entre 0 y 1 } -- zonas resaltadas
  incidentes: [], // ids de incidentes a resaltar
  recursos: [], // ids de recursos a resaltar
  lineas: [], // [{ desde: [lat, lng], hasta: [lat, lng], texto }]
  area: null, // GeoJSON (lon/lat) de un área buscada, p. ej. el pasillo alrededor de una línea
};

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

const opcionesZona = (datos) => datos.zonas.map((z) => ({ valor: z.id, texto: `${z.nombre} (prioridad ${z.nivelPrioridad})` }));
const opcionesIncidente = (datos) => datos.incidentes.map((i) => ({ valor: i.id, texto: `#${i.id} ${i.titulo} — ${i.estado}` }));
const opcionesRecurso = (datos) => datos.recursos.map((r) => ({ valor: r.id, texto: `${r.identificacion} — ${r.tipo}` }));

function FilaIncidente({ i, extra }) {
  const detalle = [i.tipoIncidente, i.prioridad ? `prioridad ${i.prioridad}` : null, i.fechaHoraRegistro?.slice(0, 16)]
    .filter(Boolean)
    .join(" · ");
  return (
    <li className="fila">
      <span className="item__marca item__marca--circulo" style={{ "--color": COLOR_ESTADO_INCIDENTE[i.estado] }} aria-hidden="true" />
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
      <span className="item__marca item__marca--cuadrado" style={{ "--color": COLOR_ESTADO_RECURSO[r.estadoOperativo] }} aria-hidden="true" />
      <span className="item__texto">
        <span className="item__titulo">{r.identificacion}</span>
        <span className="item__detalle">
          {r.tipo} · {r.estadoOperativo}
        </span>
      </span>
      {dato && <span className="resultado__dato">{dato}</span>}
    </li>
  );
}

// ------------------------------------------ 1 y 6: incidentes y recursos por zona

/** Incidentes o recursos que están dentro de una zona elegida. */
function PanelPorZona({ datos, setResultado, tipo }) {
  const [zonaId, setZonaId] = useState("");
  const { fase, datos: filas, error } = useRuta(zonaId ? `/consultas/${tipo}-por-zona/${zonaId}` : null);

  useEffect(() => {
    if (!filas) {
      setResultado(RESULTADO_VACIO);
      return;
    }
    setResultado({ ...RESULTADO_VACIO, zonas: { [zonaId]: 1 }, [tipo]: filas.map((f) => f.id) });
  }, [filas, zonaId, tipo, setResultado]);

  const nombre = tipo === "incidentes" ? "incidentes" : "recursos";
  return (
    <>
      <Selector etiqueta="Zona operativa" valor={zonaId} onChange={setZonaId} opciones={opcionesZona(datos)} vacio="Elegí una zona…" />
      <Estado fase={fase} error={error} />
      {filas && (
        <>
          <p className="ayuda">
            {filas.length} {filas.length === 1 ? nombre.slice(0, -1) : nombre} en la zona.
          </p>
          <ul className="items">
            {filas.map((f) => (tipo === "incidentes" ? <FilaIncidente key={f.id} i={f} /> : <FilaRecurso key={f.id} r={f} />))}
          </ul>
        </>
      )}
    </>
  );
}

const PanelIncidentesZona = (props) => <PanelPorZona {...props} tipo="incidentes" />;
const PanelRecursosZona = (props) => <PanelPorZona {...props} tipo="recursos" />;

// ------------------------------------------------------ 3: recursos cercanos a un incidente

function PanelRecursosCercanos({ datos, setResultado }) {
  const [incidenteId, setIncidenteId] = useState("");
  const [limite, setLimite] = useState(3);
  const [soloDisponibles, setSoloDisponibles] = useState(true);
  const cantidad = Math.min(10, Math.max(1, Number(limite) || 3));

  const ruta = incidenteId ? `/consultas/recursos-cercanos/${incidenteId}${query({ limite: cantidad, soloDisponibles })}` : null;
  const { fase, datos: filas, error } = useRuta(ruta);

  useEffect(() => {
    const incidente = datos.incidentes.find((i) => String(i.id) === incidenteId);
    if (!filas || !incidente) {
      setResultado(RESULTADO_VACIO);
      return;
    }
    const lineas = filas
      .map((f) => ({ f, recurso: datos.recursos.find((r) => r.id === f.id) }))
      .filter(({ recurso }) => recurso)
      .map(({ f, recurso }) => ({ desde: incidente.pos, hasta: recurso.pos, texto: `${f.identificacion}: ${metros(f.distanciaM)}` }));
    setResultado({ ...RESULTADO_VACIO, incidentes: [incidente.id], recursos: filas.map((f) => f.id), lineas });
  }, [filas, incidenteId, datos, setResultado]);

  return (
    <>
      <Selector etiqueta="Incidente" valor={incidenteId} onChange={setIncidenteId} opciones={opcionesIncidente(datos)} vacio="Elegí un incidente…" />
      <label className="campo">
        <span className="campo__etiqueta">Cuántos recursos</span>
        <input type="number" min="1" max="10" value={limite} onChange={(e) => setLimite(e.target.value)} />
      </label>
      <label className="casilla">
        <input type="checkbox" checked={soloDisponibles} onChange={(e) => setSoloDisponibles(e.target.checked)} />
        Solo recursos disponibles
      </label>
      <Estado fase={fase} error={error} />
      {filas && filas.length === 0 && <p className="ayuda">No hay recursos que cumplan.</p>}
      {filas && filas.length > 0 && (
        <ul className="items">
          {filas.map((f) => (
            <FilaRecurso key={f.id} r={f} dato={metros(f.distanciaM)} />
          ))}
        </ul>
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
 * Alternativa al clic en el mapa: ubica el punto donde se cruzan dos calles (PostGIS intersecta
 * los tramos de cada una, ver /consultas/interseccion) y lo deja como punto de búsqueda.
 */
function BuscadorIntersecciones({ setPunto }) {
  const [calle1, setCalle1] = useState("");
  const [calle2, setCalle2] = useState("");
  const [busqueda, setBusqueda] = useState({ fase: "quieto", cruces: [], elegido: 0, error: null });

  const buscar = async (evento) => {
    evento.preventDefault();
    setBusqueda({ fase: "cargando", cruces: [], elegido: 0, error: null });
    try {
      const cruces = await api.get(`/consultas/interseccion${query({ calle1: calle1.trim(), calle2: calle2.trim() })}`);
      setBusqueda({ fase: "ok", cruces, elegido: 0, error: null });
      if (cruces.length > 0) setPunto([cruces[0].lat, cruces[0].lon]);
    } catch (e) {
      setBusqueda({ fase: "error", cruces: [], elegido: 0, error: e.message });
    }
  };

  const elegir = (n) => {
    setBusqueda((b) => ({ ...b, elegido: n }));
    setPunto([busqueda.cruces[n].lat, busqueda.cruces[n].lon]);
  };

  return (
    <form className="bloque" onSubmit={buscar}>
      <h4 className="bloque__titulo">O por intersección de calles</h4>
      <CampoCalle etiqueta="Calle" valor={calle1} onChange={setCalle1} />
      <CampoCalle etiqueta="y calle" valor={calle2} onChange={setCalle2} />
      <button type="submit" className="btn btn--secundario" disabled={!calle1.trim() || !calle2.trim() || busqueda.fase === "cargando"}>
        {busqueda.fase === "cargando" ? "Buscando…" : "Ubicar el cruce"}
      </button>
      {busqueda.fase === "error" && <Aviso tipo="error">{busqueda.error}</Aviso>}
      {busqueda.fase === "ok" && busqueda.cruces.length === 0 && (
        <Aviso tipo="info">Esas calles no se cruzan, o algún nombre no existe. Elegí los nombres de la lista de sugerencias.</Aviso>
      )}
      {busqueda.cruces.length > 1 && (
        <>
          <p className="ayuda">Hay {busqueda.cruces.length} cruces con esos nombres. Elegí uno:</p>
          <div className="acciones">
            {busqueda.cruces.map((c, n) => (
              <button key={n} type="button" className={n === busqueda.elegido ? "btn btn--primario" : "btn btn--secundario"} onClick={() => elegir(n)}>
                Cruce {n + 1}
              </button>
            ))}
          </div>
        </>
      )}
    </form>
  );
}

// ------------------------------------------------ elegir el punto escribiendo una dirección

/**
 * Ubica una dirección ("calle número") con los números de puerta de Montevideo (ver
 * /consultas/geocodificar) y la deja como punto de búsqueda.
 */
function BuscadorDireccion({ setPunto }) {
  const [texto, setTexto] = useState("");
  const [busqueda, setBusqueda] = useState({ fase: "quieto", resultado: null, error: null });

  const buscar = async (evento) => {
    evento.preventDefault();
    setBusqueda({ fase: "cargando", resultado: null, error: null });
    try {
      const r = await api.get(`/consultas/geocodificar${query({ direccion: texto.trim() })}`);
      setBusqueda({ fase: "ok", resultado: r, error: null });
      setPunto([r.lat, r.lon]);
    } catch (e) {
      setBusqueda({ fase: "error", resultado: null, error: e.message });
    }
  };

  const { fase, resultado, error } = busqueda;
  return (
    <form className="bloque" onSubmit={buscar}>
      <h4 className="bloque__titulo">Por dirección</h4>
      <label className="campo">
        <span className="campo__etiqueta">Calle y número</span>
        <input value={texto} onChange={(e) => setTexto(e.target.value)} placeholder="Ej.: Buenos Aires 451" autoComplete="off" />
      </label>
      <button type="submit" className="btn btn--secundario" disabled={!texto.trim() || fase === "cargando"}>
        {fase === "cargando" ? "Buscando…" : "Ubicar la dirección"}
      </button>
      {fase === "error" && <Aviso tipo="error">{error}</Aviso>}
      {fase === "ok" && (
        <Aviso tipo={resultado.aproximada ? "info" : "ok"}>
          {resultado.aproximada ? resultado.aviso : "Dirección ubicada"}: <strong>{resultado.direccion}</strong>
          {resultado.fuente === "IDE" && " (servicio de la IDE)"}
        </Aviso>
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
      <p className="ayuda">Las direcciones se buscan en los números de puerta de Montevideo (capa «acceso» de GeoServer).</p>
    </>
  );
}

// ---------------------------- 4: búsqueda de incidente (incidente más cercano a un punto)

function PanelIncidenteCercano({ datos, punto, setPunto, setResultado }) {
  const { fase, datos: dato, error } = useRuta(punto ? `/consultas/incidente-mas-cercano?lon=${punto[1]}&lat=${punto[0]}` : null);

  useEffect(() => {
    const incidente = dato?.id && datos.incidentes.find((i) => i.id === dato.id);
    if (!incidente) {
      setResultado(RESULTADO_VACIO);
      return;
    }
    setResultado({ ...RESULTADO_VACIO, incidentes: [incidente.id], lineas: [{ desde: punto, hasta: incidente.pos, texto: metros(dato.distanciaM) }] });
  }, [dato, datos, punto, setResultado]);

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

// -------------------------------------------------- 5: búsqueda de zona (zona de un punto)

function PanelZonaPunto({ datos, punto, setPunto, setResultado }) {
  const { fase, datos: dato, error } = useRuta(punto ? `/consultas/zona-por-punto?lon=${punto[1]}&lat=${punto[0]}` : null);

  useEffect(() => {
    setResultado(dato?.id ? { ...RESULTADO_VACIO, zonas: { [dato.id]: 1 } } : RESULTADO_VACIO);
  }, [dato, setResultado]);

  const zona = dato?.id && datos.zonas.find((z) => z.id === dato.id);
  return (
    <>
      {!punto && <Aviso tipo="info">Hacé clic en el mapa, o escribí una dirección, para elegir el punto a ubicar.</Aviso>}
      <Estado fase={fase} error={error} />
      {zona && (
        <ul className="items">
          <li className="fila">
            <span className="item__marca item__marca--zona" style={{ "--color": COLOR_PRIORIDAD[zona.nivelPrioridad] }} aria-hidden="true" />
            <span className="item__texto">
              <span className="item__titulo">{zona.nombre}</span>
              <span className="item__detalle">
                Prioridad {zona.nivelPrioridad}
                {zona.responsable ? ` · ${zona.responsable}` : ""}
              </span>
            </span>
          </li>
        </ul>
      )}
      {fase === "ok" && !dato?.id && <Aviso tipo="info">El punto no está dentro de ninguna zona operativa.</Aviso>}
      <BuscadoresDePunto setPunto={setPunto} />
    </>
  );
}

// -------------------------------------------------------------- 7: incidentes por recurso

function PanelIncidentesRecurso({ datos, setResultado }) {
  const [recursoId, setRecursoId] = useState("");
  const { fase, datos: filas, error } = useRuta(recursoId ? `/consultas/incidentes-por-recurso/${recursoId}` : null);

  useEffect(() => {
    const recurso = datos.recursos.find((r) => String(r.id) === recursoId);
    if (!filas || !recurso) {
      setResultado(RESULTADO_VACIO);
      return;
    }
    const lineas = filas
      .map((f) => datos.incidentes.find((i) => i.id === f.id))
      .filter(Boolean)
      .map((i) => ({ desde: recurso.pos, hasta: i.pos, texto: i.titulo }));
    setResultado({ ...RESULTADO_VACIO, recursos: [recurso.id], incidentes: filas.map((f) => f.id), lineas });
  }, [filas, recursoId, datos, setResultado]);

  return (
    <>
      <Selector etiqueta="Recurso" valor={recursoId} onChange={setRecursoId} opciones={opcionesRecurso(datos)} vacio="Elegí un recurso…" />
      <Estado fase={fase} error={error} />
      {filas && filas.length === 0 && <p className="ayuda">Este recurso no tiene incidentes asignados.</p>}
      {filas && filas.length > 0 && (
        <ul className="items">
          {filas.map((f) => (
            <FilaIncidente key={f.id} i={f} />
          ))}
        </ul>
      )}
    </>
  );
}

// --------------------------------------- 2 y 8: zonas con más incidentes / mayor concentración

const METRICAS = {
  cantidad: { ruta: "zonas-mas-incidentes", campo: "cantidadIncidentes", unidad: ["incidente", "incidentes"] },
  km2: { ruta: "zonas-mayor-concentracion", campo: "incidentesPorKm2", unidad: [" / km²", " / km²"] },
};

function PanelRankings({ setResultado }) {
  const [metrica, setMetrica] = useState("cantidad");
  const [desde, setDesde] = useState("");
  const [hasta, setHasta] = useState("");
  const { ruta, campo, unidad } = METRICAS[metrica];

  const { fase, datos: filas, error } = useRuta(`/consultas/${ruta}${query({ desde, hasta: diaSiguiente(hasta) })}`);
  const maximo = Math.max(0, ...(filas ?? []).map((z) => Number(z[campo])));

  useEffect(() => {
    if (!filas || maximo <= 0) {
      setResultado(RESULTADO_VACIO);
      return;
    }
    const zonas = {};
    filas.forEach((z) => {
      const valor = Number(z[campo]);
      if (valor > 0) zonas[z.id] = valor / maximo;
    });
    setResultado({ ...RESULTADO_VACIO, zonas });
  }, [filas, campo, maximo, setResultado]);

  return (
    <>
      <Segmentado
        leyenda="Ordenar por"
        nombre="metrica"
        valor={metrica}
        onChange={setMetrica}
        opciones={[
          { valor: "cantidad", etiqueta: "Cantidad", color: "#2b6b9e" },
          { valor: "km2", etiqueta: "Por km²", color: "#9a5a12" },
        ]}
      />
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
      <Estado fase={fase} error={error} />
      {filas && (
        <ol className="ranking">
          {filas.map((z, i) => {
            const valor = Number(z[campo]);
            const porcentaje = maximo > 0 ? Math.max((valor / maximo) * 100, valor > 0 ? 3 : 0) : 0;
            return (
              <li key={z.id} className={i === 0 && valor > 0 ? "ranking__fila ranking__fila--primero" : "ranking__fila"}>
                <span className="ranking__nombre">{z.nombre}</span>
                <span className="ranking__barra" aria-hidden="true">
                  <span style={{ width: `${porcentaje}%` }} />
                </span>
                <span className="ranking__valor">
                  {valor}
                  <small>{metrica === "km2" ? unidad[0] : ` ${valor === 1 ? unidad[0] : unidad[1]}`}</small>
                </span>
              </li>
            );
          })}
        </ol>
      )}
      <p className="ayuda">
        {metrica === "cantidad"
          ? "Incidentes registrados dentro de cada zona en el período."
          : "Incidentes por kilómetro cuadrado: una zona chica con pocos incidentes puede estar más cargada que una grande."}{" "}
        Sin fechas se cuenta todo el historial.
      </p>
    </>
  );
}

// ------------------------------------------ reporte de incidentes por zona (filtros)

function PanelReporte({ datos, setResultado }) {
  const [filtros, setFiltros] = useState({ zonaId: "", tipo: "", prioridad: "", estado: "", desde: "", hasta: "" });
  const cambiar = (clave) => (valor) => setFiltros((f) => ({ ...f, [clave]: valor }));

  const ruta = `/consultas/reportes/incidentes-por-zona${query({ ...filtros, hasta: diaSiguiente(filtros.hasta) })}`;
  const { fase, datos: filas, error } = useRuta(ruta);

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
    const zonas = {};
    grupos.forEach((g) => {
      zonas[g.zonaId] = 1;
    });
    setResultado({ ...RESULTADO_VACIO, zonas, incidentes: filas.map((f) => f.id) });
  }, [filas, grupos, setResultado]);

  const tipos = [...new Set(datos.incidentes.map((i) => i.tipoIncidente))].sort().map((t) => ({ valor: t, texto: t }));

  return (
    <>
      <Selector etiqueta="Zona" valor={filtros.zonaId} onChange={cambiar("zonaId")} opciones={opcionesZona(datos)} vacio="Todas" />
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
          {filas.length} {filas.length === 1 ? "incidente" : "incidentes"} en {grupos.length} {grupos.length === 1 ? "zona" : "zonas"}.
        </p>
      )}
      {grupos.map((g) => (
        <section key={g.zonaId}>
          <h4 className="resultado__grupo">
            {g.nombre} — {g.incidentes.length}
          </h4>
          <ul className="items">
            {g.incidentes.map((i) => (
              <FilaIncidente key={i.id} i={i} />
            ))}
          </ul>
        </section>
      ))}
    </>
  );
}

// --------------------------------------- extra: una línea o un polígono dibujado en el mapa

const formatoArea = (m2) => (m2 >= 1e6 ? `${(m2 / 1e6).toFixed(2)} km²` : `${Math.round(m2)} m²`);

/** Pide qué hay cerca de la figura dibujada; se repite si cambia la figura o la distancia. */
function useFigura(figura, distanciaM) {
  const [estado, setEstado] = useState({ clave: null, fase: "quieto", datos: null, error: null });
  const clave = figura ? JSON.stringify([figura, distanciaM]) : null;

  useEffect(() => {
    if (!figura) return undefined;
    let vigente = true;
    const cuerpo = { geomGeoJson: JSON.stringify(figura), ...(distanciaM !== "" ? { distanciaM: Number(distanciaM) } : {}) };
    api
      .post("/consultas/por-figura", cuerpo)
      .then((datos) => vigente && setEstado({ clave, fase: "ok", datos, error: null }))
      .catch((e) => vigente && setEstado({ clave, fase: "error", datos: null, error: e.message }));
    return () => {
      vigente = false;
    };
  }, [clave, figura, distanciaM]);

  if (!figura) return { fase: "quieto", datos: null, error: null };
  if (estado.clave !== clave) return { fase: "cargando", datos: null, error: null };
  return estado;
}

function PanelFigura({ figura, setResultado }) {
  const [distanciaTexto, setDistanciaTexto] = useState("");
  const [distancia, setDistancia] = useState(""); // la que se aplica: espera a que se deje de escribir
  useEffect(() => {
    const espera = setTimeout(() => setDistancia(distanciaTexto), 400);
    return () => clearTimeout(espera);
  }, [distanciaTexto]);

  const esLinea = figura?.type === "LineString";
  const { fase, datos: r, error } = useFigura(figura, distancia);

  useEffect(() => {
    if (!r) {
      setResultado(RESULTADO_VACIO);
      return;
    }
    setResultado({
      ...RESULTADO_VACIO,
      area: r.area ? JSON.parse(r.area) : null,
      zonas: Object.fromEntries(r.zonas.map((z) => [z.id, 1])),
      incidentes: r.incidentes.filas.map((f) => f.id),
      recursos: r.recursos.filas.map((f) => f.id),
    });
  }, [r, setResultado]);

  const dentro = (m) => (m === 0 ? "adentro" : metros(m));
  const resumen = (lista, nombre) => (
    <p className="ayuda">
      {lista.total} {nombre}
      {lista.total > lista.filas.length && ` (se muestran los ${lista.filas.length} más cercanos)`}
    </p>
  );

  return (
    <>
      {!figura && <Aviso tipo="info">Dibujá una línea o un polígono con las herramientas de arriba a la derecha del mapa.</Aviso>}
      {figura && (
        <label className="campo">
          <span className="campo__etiqueta">{esLinea ? "Buscar a menos de (metros)" : "Agrandar el área (metros)"}</span>
          <input type="number" min="0" max="10000" step="50" value={distanciaTexto} placeholder={esLinea ? "200" : "0 = solo lo de adentro"} onChange={(e) => setDistanciaTexto(e.target.value)} />
        </label>
      )}
      <Estado fase={fase} error={error} />
      {r && (
        <>
          <p className="ayuda">
            {r.tipo === "LineString" ? `Línea de ${metros(r.largoM)}` : `Polígono de ${formatoArea(r.areaM2)} (perímetro ${metros(r.perimetroM)})`}
            {r.distanciaM > 0 && `, buscando a menos de ${metros(r.distanciaM)}`}.
          </p>
          {r.zonas.length > 0 && <p className="ayuda">Zonas que toca: {r.zonas.map((z) => z.nombre).join(", ")}.</p>}

          <h4 className="resultado__grupo">Incidentes</h4>
          {resumen(r.incidentes, r.incidentes.total === 1 ? "incidente" : "incidentes")}
          <ul className="items">
            {r.incidentes.filas.map((f) => (
              <FilaIncidente key={f.id} i={f} extra={<span className="resultado__dato">{dentro(f.distanciaM)}</span>} />
            ))}
          </ul>

          <h4 className="resultado__grupo">Recursos</h4>
          {resumen(r.recursos, r.recursos.total === 1 ? "recurso" : "recursos")}
          <ul className="items">
            {r.recursos.filas.map((f) => (
              <FilaRecurso key={f.id} r={f} dato={dentro(f.distanciaM)} />
            ))}
          </ul>
        </>
      )}
    </>
  );
}

// ------------------------------------------------------------------------ el catálogo

/**
 * Orden y textos del selector de la página. Los números son los de las "Consultas geográficas" de la letra. `pideClic`: la consulta usa un punto del mapa,
 * así que la página escucha los clics. `dibuja`: usa una línea o un polígono dibujado en el
 * mapa, así que la página muestra la barra de dibujo. `postgis`: qué función espacial la resuelve.
 */
export const CONSULTAS = [
  {
    id: "incidentes-zona",
    titulo: "1. Incidentes por zona",
    descripcion: "Elegí una zona y se muestran en el mapa los incidentes que están dentro de ella.",
    postgis: "ST_Contains(zona, incidente)",
    Panel: PanelIncidentesZona,
  },
  {
    id: "rankings",
    titulo: "2 y 8. Zonas con más incidentes (cantidad y concentración)",
    descripcion: "Ranking de zonas en un período, por cantidad o por concentración. En el mapa, más oscura = más incidentes.",
    postgis: "ST_Contains + COUNT; ST_Area para la concentración",
    Panel: PanelRankings,
  },
  {
    id: "recursos-cercanos",
    titulo: "3. Recursos cercanos a un incidente",
    descripcion: "Dado un incidente, los recursos más cercanos, ordenados por distancia en línea recta.",
    postgis: "operador <-> (vecino más cercano) y ST_Distance",
    Panel: PanelRecursosCercanos,
  },
  {
    id: "incidente-cercano",
    titulo: "4. Búsqueda de incidente (dirección, cruce o punto)",
    descripcion: "Elegí un punto con un clic en el mapa, escribí una dirección o ubicá el cruce de dos calles, y se busca el incidente más cercano.",
    postgis: "operador <-> y ST_Distance; la dirección con la tabla de puertas; el cruce de calles con ST_Intersection",
    pideClic: true,
    Panel: PanelIncidenteCercano,
  },
  {
    id: "zona-punto",
    titulo: "5. Búsqueda de zona (dirección, cruce o punto)",
    descripcion: "Elegí un punto con un clic en el mapa, escribí una dirección o ubicá el cruce de dos calles, y se indica a qué zona operativa pertenece.",
    postgis: "ST_Contains(zona, punto); la dirección con la tabla de puertas; el cruce de calles con ST_Intersection",
    pideClic: true,
    Panel: PanelZonaPunto,
  },
  {
    id: "recursos-zona",
    titulo: "6. Recursos por zona",
    descripcion: "Elegí una zona y se muestran los recursos de emergencia que están dentro de ella.",
    postgis: "ST_Contains(zona, recurso)",
    Panel: PanelRecursosZona,
  },
  {
    id: "incidentes-recurso",
    titulo: "7. Incidentes por recurso",
    descripcion: "Elegí un recurso y se muestran los incidentes que tiene asignados.",
    postgis: "tabla incidente_recurso (relación recurso-incidente)",
    Panel: PanelIncidentesRecurso,
  },
  {
    id: "reporte",
    titulo: "Reporte de incidentes por zona",
    descripcion: "Listado filtrable por zona, tipo, prioridad, estado y fechas, agrupado por zona.",
    postgis: "ST_Contains(zona, incidente) con filtros",
    Panel: PanelReporte,
  },
  {
    id: "figura",
    titulo: "Extra: dibujar una línea o un polígono",
    descripcion:
      "Dibujá una línea (por ejemplo, una avenida) o un polígono (un área) y se muestra qué incidentes, recursos y zonas hay adentro o a lo largo de ella.",
    postgis: "ST_DWithin y ST_Buffer; ST_Length y ST_Area de la figura",
    dibuja: true,
    Panel: PanelFigura,
  },
];
