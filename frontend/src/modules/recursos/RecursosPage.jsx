import { useEffect, useState } from "react";
import { CircleMarker, Tooltip, useMapEvents } from "react-leaflet";
import MapView from "../../components/MapView.jsx";
import { api } from "../../api/client.js";

/**
 * Módulo Recursos de emergencia (dueño: P3): ABM de ambulancias, bomberos, patrullas, etc.
 *
 * Reemplaza al módulo "Atracciones" de GeoTravel: mismo patrón (clic en el mapa para
 * ubicar un punto), pero sin foto -- UrbanSafe no la pide -- y con "tipo" como texto
 * libre (la letra da ejemplos sin cerrar la lista; si el tutor confirma que debe ser
 * una lista fija, cambiar el <input> de tipo por un <select>).
 *
 * Igual que en Atracciones: Leaflet trabaja con [lat, lng] pero GeoJSON exige [lng, lat];
 * la conversión está aislada en "geometria" (al guardar) y "posicionDe" (al leer).
 */

const ESTADOS_OPERATIVOS = ["Disponible", "En servicio", "Fuera de servicio"];
const COLOR_ESTADO = { Disponible: "#1f7a5c", "En servicio": "#9a5a12", "Fuera de servicio": "#a8392b" };

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
  const [seleccionado, setSeleccionado] = useState(null);
  const [form, setForm] = useState(FORM_VACIO);
  const [punto, setPunto] = useState(null); // { lat, lng } del recurso que se está creando/editando
  const [error, setError] = useState(null);
  const [mensaje, setMensaje] = useState(null);

  const cargar = () => api.get("/recursos").then(setRecursos).catch((e) => setError(e.message));

  useEffect(() => {
    cargar();
  }, []);

  const nuevo = () => {
    setSeleccionado(null);
    setForm(FORM_VACIO);
    setPunto(null);
    setError(null);
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
      setMensaje(seleccionado ? "Recurso actualizado." : "Recurso creado.");
      nuevo();
      cargar();
    } catch (e) {
      setError(e.message);
    }
  };

  const eliminar = async () => {
    if (!window.confirm(`¿Eliminar "${seleccionado.identificacion}"?`)) return;
    try {
      await api.del(`/recursos/${seleccionado.id}`);
      setMensaje("Recurso eliminado.");
      nuevo();
      cargar();
    } catch (e) {
      setError(e.message);
    }
  };

  const campo = (nombre) => ({
    value: form[nombre],
    onChange: (e) => setForm({ ...form, [nombre]: e.target.value }),
  });

  return (
    <div>
      <h2>Recursos de emergencia</h2>

      <MapView>
        <ClickEnMapa alClick={setPunto} />

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
                pathOptions={{ color: COLOR_ESTADO[r.estadoOperativo] ?? "#555", fillOpacity: 0.8 }}
                bubblingMouseEvents={false}
                eventHandlers={{ click: () => seleccionar(r) }}
              >
                <Tooltip>{r.identificacion} — {r.tipo}</Tooltip>
              </CircleMarker>
            );
          })}

        {/* La ubicación que se está eligiendo (nueva o en edición). */}
        {punto && (
          <CircleMarker
            center={[punto.lat, punto.lng]}
            radius={12}
            pathOptions={{ color: COLOR_ESTADO[form.estadoOperativo], weight: 4, fillOpacity: 0.3 }}
          >
            <Tooltip permanent>{form.identificacion || "Nuevo recurso"}</Tooltip>
          </CircleMarker>
        )}
      </MapView>

      <form onSubmit={guardar} style={{ display: "grid", gap: 8, maxWidth: 480, marginTop: 16 }}>
        <h3>{seleccionado ? `Editando: ${seleccionado.identificacion}` : "Nuevo recurso"}</h3>
        <p style={{ margin: 0, color: "#555" }}>
          Hacé clic en el mapa para {seleccionado ? "mover" : "elegir"} la ubicación.
        </p>

        <label>
          Identificación (ej. &quot;Ambulancia 12&quot;) <input required {...campo("identificacion")} />
        </label>
        <label>
          Nombre (opcional) <input {...campo("nombre")} />
        </label>
        <label>
          Tipo (ej. ambulancia, bomberos, patrulla, centro_atencion) <input required {...campo("tipo")} />
        </label>
        <label>
          Estado operativo
          <select {...campo("estadoOperativo")}>
            {ESTADOS_OPERATIVOS.map((e) => (
              <option key={e} value={e}>
                {e}
              </option>
            ))}
          </select>
        </label>
        <label>
          Descripción <textarea rows={2} {...campo("descripcion")} />
        </label>

        {error && (
          <p role="alert" style={{ color: "crimson", margin: 0 }}>
            {error}
          </p>
        )}
        {mensaje && <p style={{ color: "seagreen", margin: 0 }}>{mensaje}</p>}

        <div style={{ display: "flex", gap: 8 }}>
          <button type="submit">{seleccionado ? "Guardar cambios" : "Crear recurso"}</button>
          {seleccionado && (
            <>
              <button type="button" onClick={eliminar}>
                Eliminar
              </button>
              <button type="button" onClick={nuevo}>
                Cancelar
              </button>
            </>
          )}
        </div>
      </form>

      <h3>Recursos existentes</h3>
      <ul>
        {recursos.map((r) => (
          <li key={r.id}>
            <button type="button" onClick={() => seleccionar(r)}>
              {r.identificacion}
            </button>{" "}
            — {r.tipo} ({r.estadoOperativo})
          </li>
        ))}
      </ul>
    </div>
  );
}
