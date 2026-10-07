import { useEffect, useState } from "react";
import { CircleMarker, Tooltip, useMapEvents } from "react-leaflet";
import PaginaMapa from "../../components/PaginaMapa.jsx";
import { Aviso, BotonVolver, IconoFlecha, IconoMas, Segmentado } from "../../components/ui.jsx";
import { COLOR_ESTADO_RECURSO, TIPOS_RECURSO } from "../../components/colores.js";
import { api } from "../../api/client.js";

/**
 * Módulo Recursos de emergencia (dueño: P3): ABM de ambulancias, bomberos, patrullas, etc.
 *
 * Reemplaza al módulo "Atracciones" de GeoTravel: mismo patrón (clic en el mapa para
 * ubicar un punto), pero sin foto -- UrbanSafe no la pide -- y con "tipo" como texto
 * libre (la letra da ejemplos sin cerrar la lista; si el tutor confirma que debe ser
 * una lista fija, cambiar el <input> de tipo por un <select>). Los tipos que conoce el
 * estilo de GeoServer se sugieren al escribir, pero no se obligan.
 *
 * Igual que en Atracciones: Leaflet trabaja con [lat, lng] pero GeoJSON exige [lng, lat];
 * la conversión está aislada en "geometria" (al guardar) y "posicionDe" (al leer).
 *
 * El panel tiene dos vistas: la lista de recursos y el formulario (nuevo o en edición).
 * El mapa solo acepta clics de ubicación cuando el formulario está abierto.
 */

const ESTADOS_OPERATIVOS = Object.keys(COLOR_ESTADO_RECURSO).map((estado) => ({
  valor: estado,
  etiqueta: estado,
  color: COLOR_ESTADO_RECURSO[estado],
}));

const FORM_VACIO = { identificacion: "", nombre: "", tipo: "", estadoOperativo: "Disponible", descripcion: "" };

const posicionDe = (recurso) => {
  const [lng, lat] = JSON.parse(recurso.geom).coordinates;
  return { lat, lng };
};
const geometria = ({ lat, lng }) => ({ type: "Point", coordinates: [lng, lat] });

/** Componente sin UI: escucha los clics del mapa (useMapEvents solo funciona dentro de un mapa). */
function ClickEnMapa({ alClick }) {
  useMapEvents({ click: (e) => alClick(e.latlng) });
  return null;
}

export default function RecursosPage() {
  const [recursos, setRecursos] = useState([]);
  const [vista, setVista] = useState("lista"); // "lista" | "form"
  const [seleccionado, setSeleccionado] = useState(null);
  const [form, setForm] = useState(FORM_VACIO);
  const [punto, setPunto] = useState(null); // { lat, lng } del recurso que se está creando/editando
  const [error, setError] = useState(null);
  const [mensaje, setMensaje] = useState(null);

  const cargar = () => api.get("/recursos").then(setRecursos).catch((e) => setError(e.message));

  useEffect(() => {
    cargar();
  }, []);

  const reiniciar = () => {
    setSeleccionado(null);
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
    setVista("form");
  };

  const seleccionar = (r) => {
    setSeleccionado(r);
    setForm({
      identificacion: r.identificacion,
      nombre: r.nombre ?? "",
      tipo: r.tipo,
      estadoOperativo: r.estadoOperativo,
      descripcion: r.descripcion ?? "",
    });
    setPunto(posicionDe(r));
    setError(null);
    setMensaje(null);
    setVista("form");
  };

  const guardar = async (ev) => {
    ev.preventDefault();
    setError(null);
    setMensaje(null);
    if (!punto) {
      setError("Hacé clic en el mapa para elegir la ubicación del recurso.");
      return;
    }
    const cuerpo = { ...form, geomGeoJson: JSON.stringify(geometria(punto)) };
    try {
      if (seleccionado) {
        await api.put(`/recursos/${seleccionado.id}`, cuerpo);
      } else {
        await api.post("/recursos", cuerpo);
      }
      const texto = seleccionado ? "Recurso actualizado." : "Recurso creado.";
      volverALista();
      setMensaje(texto);
      cargar();
    } catch (e) {
      setError(e.message);
    }
  };

  const eliminar = async () => {
    if (!window.confirm(`¿Eliminar "${seleccionado.identificacion}"?`)) return;
    try {
      await api.del(`/recursos/${seleccionado.id}`);
      volverALista();
      setMensaje("Recurso eliminado.");
      cargar();
    } catch (e) {
      setError(e.message);
    }
  };

  const campo = (nombre) => ({
    value: form[nombre],
    onChange: (e) => setForm({ ...form, [nombre]: e.target.value }),
  });

  const hijosMapa = (
    <>
      <ClickEnMapa alClick={(ubicacion) => vista === "form" && setPunto(ubicacion)} />

      {/* Los demás recursos, de fondo. bubblingMouseEvents=false evita que el clic sobre un
          marcador también cuente como clic en el mapa (y mueva la ubicación en edición). */}
      {recursos
        .filter((r) => r.id !== seleccionado?.id)
        .map((r) => {
          const { lat, lng } = posicionDe(r);
          return (
            <CircleMarker
              key={r.id}
              center={[lat, lng]}
              radius={8}
              pathOptions={{ color: COLOR_ESTADO_RECURSO[r.estadoOperativo] ?? "#555", fillOpacity: 0.85 }}
              bubblingMouseEvents={false}
              eventHandlers={{ click: () => seleccionar(r) }}
            >
              <Tooltip>
                {r.identificacion} — {r.tipo}
              </Tooltip>
            </CircleMarker>
          );
        })}

      {/* La ubicación que se está eligiendo (nueva o en edición). */}
      {vista === "form" && punto && (
        <CircleMarker
          center={[punto.lat, punto.lng]}
          radius={12}
          pathOptions={{ color: COLOR_ESTADO_RECURSO[form.estadoOperativo], weight: 4, fillOpacity: 0.3 }}
        >
          <Tooltip permanent>{form.identificacion || "Nuevo recurso"}</Tooltip>
        </CircleMarker>
      )}
    </>
  );

  return (
    <PaginaMapa etiqueta="Administración" titulo="Recursos de emergencia" etiquetaBoton="Recursos" hijosMapa={hijosMapa}>
      {vista === "lista" ? (
        <>
          <div className="panel__seccion">
            {mensaje && <Aviso tipo="ok">{mensaje}</Aviso>}
            {error && <Aviso tipo="error">{error}</Aviso>}
            <button type="button" className="btn btn--primario btn--ancho" onClick={abrirNuevo}>
              <IconoMas /> Nuevo recurso
            </button>
            <p className="ayuda">También podés tocar un recurso en el mapa para editarlo.</p>
          </div>
          <ul className="items">
            {recursos.map((r) => (
              <li key={r.id}>
                <button type="button" className="item" onClick={() => seleccionar(r)}>
                  <span className="item__marca item__marca--cuadrado" style={{ "--color": COLOR_ESTADO_RECURSO[r.estadoOperativo] }} aria-hidden="true" />
                  <span className="item__texto">
                    <span className="item__titulo">{r.identificacion}</span>
                    <span className="item__detalle">
                      {r.tipo} · {r.estadoOperativo}
                    </span>
                  </span>
                  <IconoFlecha />
                </button>
              </li>
            ))}
          </ul>
          {recursos.length === 0 && <p className="vacio">Todavía no hay recursos.</p>}
        </>
      ) : (
        <form className="panel__seccion formulario" onSubmit={guardar}>
          <BotonVolver onClick={volverALista}>Recursos</BotonVolver>
          <h3 className="formulario__titulo">{seleccionado ? seleccionado.identificacion : "Nuevo recurso"}</h3>

          <p className={punto ? "paso paso--listo" : "paso"}>
            {punto
              ? `Ubicación elegida (${punto.lat.toFixed(5)}, ${punto.lng.toFixed(5)}). Tocá otro punto del mapa para moverla.`
              : "Hacé clic en el mapa para elegir la ubicación."}
          </p>

          <label className="campo">
            <span className="campo__etiqueta">Identificación</span>
            <input required placeholder="Ej.: Ambulancia 12" {...campo("identificacion")} />
          </label>
          <label className="campo">
            <span className="campo__etiqueta">Nombre (opcional)</span>
            <input {...campo("nombre")} />
          </label>
          <label className="campo">
            <span className="campo__etiqueta">Tipo</span>
            <input required list="tipos-recurso" placeholder="Ej.: ambulancia" {...campo("tipo")} />
            <datalist id="tipos-recurso">
              {TIPOS_RECURSO.map((t) => (
                <option key={t} value={t} />
              ))}
            </datalist>
          </label>
          <Segmentado
            leyenda="Estado operativo"
            nombre="estadoOperativo"
            opciones={ESTADOS_OPERATIVOS}
            valor={form.estadoOperativo}
            onChange={(estado) => setForm({ ...form, estadoOperativo: estado })}
          />
          <label className="campo">
            <span className="campo__etiqueta">Descripción</span>
            <textarea rows={2} {...campo("descripcion")} />
          </label>

          {error && <Aviso tipo="error">{error}</Aviso>}

          <div className="acciones">
            <button type="submit" className="btn btn--primario">
              {seleccionado ? "Guardar cambios" : "Crear recurso"}
            </button>
            <button type="button" className="btn btn--secundario" onClick={volverALista}>
              Cancelar
            </button>
            {seleccionado && (
              <button type="button" className="btn btn--peligro" onClick={eliminar}>
                Eliminar
              </button>
            )}
          </div>
        </form>
      )}
    </PaginaMapa>
  );
}
