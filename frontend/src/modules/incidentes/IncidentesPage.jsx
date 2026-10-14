import { useEffect, useState } from "react";
import { CircleMarker, Tooltip, useMapEvents } from "react-leaflet";
import PaginaMapa from "../../components/PaginaMapa.jsx";
import { Aviso, BotonVolver, IconoFlecha, IconoMas, Insignia, Segmentado } from "../../components/ui.jsx";
import { COLOR_ESTADO_INCIDENTE, OPCIONES_PRIORIDAD } from "../../components/colores.js";
import { api } from "../../api/client.js";

/**
 * Módulo Incidentes (dueño: P4): ABM + avanzar estado (con ramas) + histórico.
 * Reemplaza al módulo "Recorridos" de GeoTravel -- ya no hay estacionalidad, y "avanzar"
 * ahora elige un estado destino entre varios posibles, no un único botón.
 *
 * TRANSICIONES espeja la del backend (IncidenteResource.java) solo para decidir qué
 * opciones mostrar; el backend es quien valida de verdad (409 si no es válida) -- si
 * alguna vez se desincronizan, el mensaje de error del backend manda.
 *
 * El panel tiene tres vistas: la lista, el detalle de un incidente (con su historial y las
 * transiciones posibles) y el formulario para registrar uno nuevo. El mapa solo acepta
 * clics de ubicación cuando el formulario está abierto.
 */

const TRANSICIONES = {
  Registrado: ["En atención", "Derivado", "Cancelado"],
  "En atención": ["Resuelto", "Derivado", "Cancelado"],
  Derivado: ["En atención", "Cancelado"],
  Resuelto: [],
  Cancelado: [],
};

const FORM_VACIO = { titulo: "", descripcion: "", tipoIncidente: "", prioridad: 3, equipoResponsable: "" };

const posicionDe = (incidente) => {
  const [lng, lat] = JSON.parse(incidente.geom).coordinates;
  return { lat, lng };
};
const geometria = ({ lat, lng }) => ({ type: "Point", coordinates: [lng, lat] });

const formatoFecha = (iso) =>
  new Date(iso).toLocaleString("es-UY", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit", hour12: false });

function ClickEnMapa({ alClick }) {
  useMapEvents({ click: (e) => alClick(e.latlng) });
  return null;
}

export default function IncidentesPage() {
  const [incidentes, setIncidentes] = useState([]);
  const [vista, setVista] = useState("lista"); // "lista" | "detalle" | "nuevo"
  const [seleccionado, setSeleccionado] = useState(null);
  const [historial, setHistorial] = useState([]);
  const [estadoDestino, setEstadoDestino] = useState("");
  const [usuario, setUsuario] = useState("");
  const [form, setForm] = useState(FORM_VACIO);
  const [punto, setPunto] = useState(null);
  const [error, setError] = useState(null);
  const [mensaje, setMensaje] = useState(null);

  const cargar = () => api.get("/incidentes").then(setIncidentes).catch((e) => setError(e.message));

  useEffect(() => {
    cargar();
  }, []);

  const reiniciar = () => {
    setSeleccionado(null);
    setHistorial([]);
    setEstadoDestino("");
    setForm(FORM_VACIO);
    setPunto(null);
    setError(null);
  };

  const volverALista = () => {
    reiniciar();
    setVista("lista");
  };

  const abrirNuevo = () => {
    reiniciar();
    setMensaje(null);
    setVista("nuevo");
  };

  const seleccionar = async (inc) => {
    reiniciar();
    setSeleccionado(inc);
    setPunto(posicionDe(inc));
    setMensaje(null);
    setVista("detalle");
    try {
      setHistorial(await api.get(`/incidentes/${inc.id}/historial`));
    } catch (e) {
      setError(e.message);
    }
  };

  const crear = async (ev) => {
    ev.preventDefault();
    setError(null);
    setMensaje(null);
    if (!punto) {
      setError("Hacé clic en el mapa para elegir la ubicación del incidente.");
      return;
    }
    try {
      await api.post("/incidentes", { ...form, prioridad: Number(form.prioridad), geomGeoJson: JSON.stringify(geometria(punto)) });
      volverALista();
      setMensaje("Incidente registrado.");
      cargar();
    } catch (e) {
      setError(e.message);
    }
  };

  const avanzar = async () => {
    if (!estadoDestino) return;
    setError(null);
    try {
      await api.post(`/incidentes/${seleccionado.id}/avanzar`, { estado: estadoDestino, usuario });
      setMensaje(`Pasó a "${estadoDestino}".`);
      const actualizado = { ...seleccionado, estado: estadoDestino };
      setSeleccionado(actualizado);
      setHistorial(await api.get(`/incidentes/${actualizado.id}/historial`));
      setEstadoDestino("");
      cargar();
    } catch (e) {
      setError(e.message); // p. ej. No se puede pasar de "Resuelto" a "Registrado"
    }
  };

  const campo = (nombre) => ({
    value: form[nombre],
    onChange: (e) => setForm({ ...form, [nombre]: e.target.value }),
  });

  const opcionesDestino = seleccionado
    ? (TRANSICIONES[seleccionado.estado] ?? []).map((estado) => ({ valor: estado, etiqueta: estado, color: COLOR_ESTADO_INCIDENTE[estado] }))
    : [];

  const hijosMapa = (
    <>
      <ClickEnMapa alClick={(ubicacion) => vista === "nuevo" && setPunto(ubicacion)} />
      {incidentes
        .filter((i) => i.id !== seleccionado?.id)
        .map((i) => {
          const { lat, lng } = posicionDe(i);
          return (
            <CircleMarker
              key={i.id}
              center={[lat, lng]}
              radius={8}
              pathOptions={{ color: COLOR_ESTADO_INCIDENTE[i.estado] ?? "#555", fillOpacity: 0.85 }}
              bubblingMouseEvents={false}
              eventHandlers={{ click: () => seleccionar(i) }}
            >
              <Tooltip>
                {i.titulo} — {i.estado}
              </Tooltip>
            </CircleMarker>
          );
        })}
      {punto && vista !== "lista" && (
        <CircleMarker
          center={[punto.lat, punto.lng]}
          radius={12}
          pathOptions={{ color: seleccionado ? COLOR_ESTADO_INCIDENTE[seleccionado.estado] : "#13202c", weight: 4, fillOpacity: 0.25 }}
        >
          <Tooltip permanent>{seleccionado ? seleccionado.titulo : form.titulo || "Nuevo incidente"}</Tooltip>
        </CircleMarker>
      )}
    </>
  );

  return (
    <PaginaMapa etiqueta="Administración" titulo="Incidentes" etiquetaBoton="Incidentes" hijosMapa={hijosMapa}>
      {vista === "lista" && (
        <>
          <div className="panel__seccion">
            {mensaje && <Aviso tipo="ok">{mensaje}</Aviso>}
            {error && <Aviso tipo="error">{error}</Aviso>}
            <button type="button" className="btn btn--primario btn--ancho" onClick={abrirNuevo}>
              <IconoMas /> Registrar incidente
            </button>
            <p className="ayuda">Tocá un incidente en el mapa o en la lista para ver su detalle y cambiar su estado.</p>
          </div>
          <ul className="items">
            {incidentes.map((i) => (
              <li key={i.id}>
                <button type="button" className="item" onClick={() => seleccionar(i)}>
                  <span className="item__marca item__marca--circulo" style={{ "--color": COLOR_ESTADO_INCIDENTE[i.estado] }} aria-hidden="true" />
                  <span className="item__texto">
                    <span className="item__titulo">{i.titulo}</span>
                    <span className="item__detalle">
                      {i.estado} · prioridad {i.prioridad}
                    </span>
                  </span>
                  <IconoFlecha />
                </button>
              </li>
            ))}
          </ul>
          {incidentes.length === 0 && <p className="vacio">Todavía no hay incidentes registrados.</p>}
        </>
      )}

      {vista === "detalle" && seleccionado && (
        <div className="panel__seccion detalle">
          <BotonVolver onClick={volverALista}>Incidentes</BotonVolver>
          <div className="detalle__cabecera">
            <h3 className="formulario__titulo">{seleccionado.titulo}</h3>
            <Insignia color={COLOR_ESTADO_INCIDENTE[seleccionado.estado]}>{seleccionado.estado}</Insignia>
          </div>
          {seleccionado.descripcion && <p className="detalle__descripcion">{seleccionado.descripcion}</p>}

          <dl className="datos">
            <div>
              <dt>Tipo</dt>
              <dd>{seleccionado.tipoIncidente}</dd>
            </div>
            <div>
              <dt>Prioridad</dt>
              <dd>{seleccionado.prioridad}</dd>
            </div>
            <div>
              <dt>Equipo</dt>
              <dd>{seleccionado.equipoResponsable || "—"}</dd>
            </div>
            <div>
              <dt>Registrado</dt>
              <dd>{formatoFecha(seleccionado.fechaHoraRegistro)}</dd>
            </div>
          </dl>

          {mensaje && <Aviso tipo="ok">{mensaje}</Aviso>}
          {error && <Aviso tipo="error">{error}</Aviso>}

          <section className="bloque">
            <h4 className="bloque__titulo">Cambiar estado</h4>
            {opcionesDestino.length > 0 ? (
              <>
                <Segmentado leyenda="Pasar a" nombre="estadoDestino" opciones={opcionesDestino} valor={estadoDestino} onChange={setEstadoDestino} />
                <label className="campo">
                  <span className="campo__etiqueta">Tu usuario (opcional)</span>
                  <input value={usuario} onChange={(e) => setUsuario(e.target.value)} />
                </label>
                <button type="button" className="btn btn--primario" onClick={avanzar} disabled={!estadoDestino}>
                  Confirmar cambio
                </button>
              </>
            ) : (
              <p className="ayuda">Estado final: este incidente ya no admite más cambios.</p>
            )}
          </section>

          <section className="bloque">
            <h4 className="bloque__titulo">Historial</h4>
            <ol className="cronologia">
              {historial.map((h, i) => (
                <li key={i} className="cronologia__item" style={{ "--color": COLOR_ESTADO_INCIDENTE[h.estado] }}>
                  <span className="cronologia__estado">{h.estado}</span>
                  <span className="cronologia__detalle">
                    {formatoFecha(h.fechaHora)} · {h.usuario}
                  </span>
                </li>
              ))}
            </ol>
          </section>
        </div>
      )}

      {vista === "nuevo" && (
        <form className="panel__seccion formulario" onSubmit={crear}>
          <BotonVolver onClick={volverALista}>Incidentes</BotonVolver>
          <h3 className="formulario__titulo">Registrar incidente</h3>

          <p className={punto ? "paso paso--listo" : "paso"}>
            {punto
              ? `Ubicación elegida (${punto.lat.toFixed(5)}, ${punto.lng.toFixed(5)}). Tocá otro punto del mapa para moverla.`
              : "Hacé clic en el mapa para elegir dónde ocurrió."}
          </p>

          <label className="campo">
            <span className="campo__etiqueta">Título</span>
            <input required {...campo("titulo")} />
          </label>
          <label className="campo">
            <span className="campo__etiqueta">Descripción</span>
            <textarea rows={2} {...campo("descripcion")} />
          </label>
          <label className="campo">
            <span className="campo__etiqueta">Tipo</span>
            <input required list="tipos-incidente" placeholder="Ej.: incendio" {...campo("tipoIncidente")} />
            <datalist id="tipos-incidente">
              {["accidente_transito", "incendio", "corte_servicio", "inundacion", "otro"].map((t) => (
                <option key={t} value={t} />
              ))}
            </datalist>
          </label>
          <Segmentado
            leyenda="Prioridad (1 = máxima, 5 = mínima)"
            nombre="prioridad"
            opciones={OPCIONES_PRIORIDAD}
            valor={Number(form.prioridad)}
            onChange={(n) => setForm({ ...form, prioridad: n })}
          />
          <label className="campo">
            <span className="campo__etiqueta">Equipo responsable</span>
            <input {...campo("equipoResponsable")} />
          </label>

          {error && <Aviso tipo="error">{error}</Aviso>}

          <div className="acciones">
            <button type="submit" className="btn btn--primario">
              Registrar incidente
            </button>
            <button type="button" className="btn btn--secundario" onClick={volverALista}>
              Cancelar
            </button>
          </div>
        </form>
      )}
    </PaginaMapa>
  );
}
