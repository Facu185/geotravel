import { useEffect, useState } from "react";
import { CircleMarker, Tooltip, useMapEvents } from "react-leaflet";
import MapView from "../../components/MapView.jsx";
import { api } from "../../api/client.js";

/**
 * Módulo Incidentes (dueño: P4): ABM + avanzar estado (con ramas) + histórico.
 * Reemplaza al módulo "Recorridos" de GeoTravel -- ya no hay estacionalidad, y "avanzar"
 * ahora elige un estado destino entre varios posibles, no un único botón.
 *
 * TRANSICIONES espeja la del backend (IncidenteResource.java) solo para decidir qué
 * opciones mostrar en el <select>; el backend es quien valida de verdad (409 si no es
 * válida) -- si alguna vez se desincronizan, el mensaje de error del backend manda.
 */

const TRANSICIONES = {
  Registrado: ["En atención", "Derivado", "Cancelado"],
  "En atención": ["Resuelto", "Derivado", "Cancelado"],
  Derivado: ["En atención", "Cancelado"],
  Resuelto: [],
  Cancelado: [],
};

const COLOR_ESTADO = {
  Registrado: "#2b6b9e",
  "En atención": "#9a5a12",
  Derivado: "#7a3b8f",
  Resuelto: "#1f7a5c",
  Cancelado: "#a8392b",
};

const FORM_VACIO = { titulo: "", descripcion: "", tipoIncidente: "", prioridad: 3, equipoResponsable: "" };

const posicionDe = (incidente) => {
  const [lng, lat] = JSON.parse(incidente.geom).coordinates;
  return { lat, lng };
};
const geometria = ({ lat, lng }) => ({ type: "Point", coordinates: [lng, lat] });

function ClickEnMapa({ alClick }) {
  useMapEvents({ click: (e) => alClick(e.latlng) });
  return null;
}

export default function IncidentesPage() {
  const [incidentes, setIncidentes] = useState([]);
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

  const nuevo = () => {
    setSeleccionado(null);
    setHistorial([]);
    setForm(FORM_VACIO);
    setPunto(null);
    setError(null);
  };

  const seleccionar = async (inc) => {
    setSeleccionado(inc);
    setPunto(posicionDe(inc));
    setEstadoDestino("");
    setError(null);
    setMensaje(null);
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
      setMensaje("Incidente registrado.");
      nuevo();
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

  const opcionesDestino = seleccionado ? TRANSICIONES[seleccionado.estado] ?? [] : [];

  return (
    <div>
      <h2>Incidentes</h2>
      {error && (
        <p role="alert" style={{ color: "crimson" }}>
          {error}
        </p>
      )}
      {mensaje && <p style={{ color: "seagreen" }}>{mensaje}</p>}

      <MapView>
        <ClickEnMapa alClick={setPunto} />
        {incidentes
          .filter((i) => i.id !== seleccionado?.id)
          .map((i) => {
            const { lat, lng } = posicionDe(i);
            return (
              <CircleMarker
                key={i.id}
                center={[lat, lng]}
                radius={8}
                pathOptions={{ color: COLOR_ESTADO[i.estado] ?? "#555", fillOpacity: 0.8 }}
                bubblingMouseEvents={false}
                eventHandlers={{ click: () => seleccionar(i) }}
              >
                <Tooltip>{i.titulo} — {i.estado}</Tooltip>
              </CircleMarker>
            );
          })}
        {punto && (
          <CircleMarker center={[punto.lat, punto.lng]} radius={12} pathOptions={{ color: "#333", weight: 4, fillOpacity: 0.2 }}>
            <Tooltip permanent>{seleccionado ? seleccionado.titulo : form.titulo || "Nuevo incidente"}</Tooltip>
          </CircleMarker>
        )}
      </MapView>

      {seleccionado ? (
        <div style={{ marginTop: 16, maxWidth: 480 }}>
          <h3>{seleccionado.titulo}</h3>
          <p>
            Estado actual: <strong>{seleccionado.estado}</strong> · Prioridad {seleccionado.prioridad} · {seleccionado.tipoIncidente}
          </p>

          {opcionesDestino.length > 0 ? (
            <div style={{ display: "flex", gap: 8, alignItems: "center", flexWrap: "wrap" }}>
              <select value={estadoDestino} onChange={(e) => setEstadoDestino(e.target.value)}>
                <option value="">Avanzar a…</option>
                {opcionesDestino.map((e) => (
                  <option key={e} value={e}>
                    {e}
                  </option>
                ))}
              </select>
              <input placeholder="Tu usuario (opcional)" value={usuario} onChange={(e) => setUsuario(e.target.value)} />
              <button type="button" onClick={avanzar} disabled={!estadoDestino}>
                Confirmar
              </button>
            </div>
          ) : (
            <p style={{ color: "#555" }}>Estado terminal: no admite más transiciones.</p>
          )}

          <h4>Histórico</h4>
          <ul>
            {historial.map((h, i) => (
              <li key={i}>
                {new Date(h.fechaHora).toLocaleString()} — {h.estado} ({h.usuario})
              </li>
            ))}
          </ul>

          <button type="button" onClick={nuevo}>
            Volver
          </button>
        </div>
      ) : (
        <form onSubmit={crear} style={{ display: "grid", gap: 8, maxWidth: 480, marginTop: 16 }}>
          <h3>Nuevo incidente</h3>
          <p style={{ margin: 0, color: "#555" }}>Hacé clic en el mapa para elegir la ubicación.</p>
          <label>
            Título <input required {...campo("titulo")} />
          </label>
          <label>
            Descripción <textarea rows={2} {...campo("descripcion")} />
          </label>
          <label>
            Tipo (ej. accidente_transito, incendio, corte_servicio, inundacion)
            <input required {...campo("tipoIncidente")} />
          </label>
          <label>
            Prioridad (1 = máxima, 5 = mínima)
            <select {...campo("prioridad")}>
              {[1, 2, 3, 4, 5].map((n) => (
                <option key={n} value={n}>
                  {n}
                </option>
              ))}
            </select>
          </label>
          <label>
            Equipo responsable <input {...campo("equipoResponsable")} />
          </label>
          <button type="submit">Registrar incidente</button>
        </form>
      )}

      <h3>Incidentes existentes</h3>
      <ul>
        {incidentes.map((i) => (
          <li key={i.id}>
            <button type="button" onClick={() => seleccionar(i)}>
              {i.titulo}
            </button>{" "}
            — {i.estado}
          </li>
        ))}
      </ul>
    </div>
  );
}
