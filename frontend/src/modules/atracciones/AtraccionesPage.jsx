import { useEffect, useState } from "react";
import { CircleMarker, Tooltip, useMapEvents } from "react-leaflet";
import MapView from "../../components/MapView.jsx";
import { api } from "../../api/client.js";

/**
 * Módulo Atracciones (dueño: P3): ABM de atracciones turísticas puntuales.
 *
 * Cómo funciona:
 *  - La ubicación se elige haciendo clic en el mapa.
 *  - Leaflet trabaja con [lat, lng] pero GeoJSON exige [lng, lat]: la conversión está en
 *    "geometria" (al guardar) y en "posicionDe" (al leer). Si se invierten, el punto cae en
 *    otro continente y nada avisa, porque sigue siendo un punto válido.
 *  - Se usan CircleMarker y no Marker: el ícono por defecto de Leaflet se rompe con Vite.
 *  - La foto se puede pegar como URL o subir como archivo. Subir es un paso previo a guardar:
 *    POST /fotos devuelve una URL, y esa URL va en el campo fotoUrl de la atracción.
 */

// Únicos valores que acepta el backend y que conocen los estilos de GeoServer.
const CLASIFICACIONES = ["cultural", "gastronomica", "natural", "historica"];
const COLOR = { cultural: "#7a3b8f", gastronomica: "#9a5a12", natural: "#1f7a5c", historica: "#2b6b9e" };

const FORM_VACIO = { nombre: "", descripcion: "", clasificacion: "cultural", fotoUrl: "" };

const MAX_FOTO_MB = 5; // mismo límite que el backend (FotoResource)

const posicionDe = (atraccion) => {
  const [lng, lat] = JSON.parse(atraccion.geom).coordinates;
  return { lat, lng };
};
const geometria = ({ lat, lng }) => ({ type: "Point", coordinates: [lng, lat] });

/** Componente sin UI: escucha los clics del mapa (useMapEvents solo funciona dentro de un mapa). */
function ClickEnMapa({ alClick }) {
  useMapEvents({ click: (e) => alClick(e.latlng) });
  return null;
}

export default function AtraccionesPage() {
  const [atracciones, setAtracciones] = useState([]);
  const [seleccionada, setSeleccionada] = useState(null);
  const [form, setForm] = useState(FORM_VACIO);
  const [punto, setPunto] = useState(null); // { lat, lng } de la atracción que se está creando/editando
  const [subiendo, setSubiendo] = useState(false);
  const [error, setError] = useState(null);
  const [mensaje, setMensaje] = useState(null);

  const cargar = () => api.get("/atracciones").then(setAtracciones).catch((e) => setError(e.message));

  useEffect(() => {
    cargar();
  }, []);

  const nueva = () => {
    setSeleccionada(null);
    setForm(FORM_VACIO);
    setPunto(null);
    setError(null);
  };

  const seleccionar = (a) => {
    setSeleccionada(a);
    setForm({
      nombre: a.nombre,
      descripcion: a.descripcion ?? "",
      clasificacion: a.clasificacion,
      fotoUrl: a.fotoUrl ?? "",
    });
    setPunto(posicionDe(a));
    setError(null);
    setMensaje(null);
  };

  const subirFoto = async (ev) => {
    const archivo = ev.target.files?.[0];
    ev.target.value = ""; // permite volver a elegir el mismo archivo
    if (!archivo) return;
    if (archivo.size > MAX_FOTO_MB * 1024 * 1024) {
      setError(`La imagen supera el máximo de ${MAX_FOTO_MB} MB.`);
      return;
    }
    setError(null);
    setSubiendo(true);
    try {
      const { url } = await api.upload("/fotos", archivo);
      setForm((actual) => ({ ...actual, fotoUrl: url }));
    } catch (e) {
      setError(e.message);
    } finally {
      setSubiendo(false);
    }
  };

  const guardar = async (ev) => {
    ev.preventDefault();
    setError(null);
    setMensaje(null);
    if (!punto) {
      setError("Hacé clic en el mapa para elegir la ubicación de la atracción.");
      return;
    }
    const cuerpo = { ...form, geomGeoJson: JSON.stringify(geometria(punto)) };
    try {
      if (seleccionada) {
        await api.put(`/atracciones/${seleccionada.id}`, cuerpo);
      } else {
        await api.post("/atracciones", cuerpo);
      }
      setMensaje(seleccionada ? "Atracción actualizada." : "Atracción creada.");
      nueva();
      cargar();
    } catch (e) {
      setError(e.message);
    }
  };

  const eliminar = async () => {
    if (!window.confirm(`¿Eliminar "${seleccionada.nombre}"?`)) return;
    try {
      await api.del(`/atracciones/${seleccionada.id}`);
      setMensaje("Atracción eliminada.");
      nueva();
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
      <h2>Atracciones turísticas</h2>

      <MapView>
        <ClickEnMapa alClick={setPunto} />

        {/* Las demás atracciones, de fondo. bubblingMouseEvents=false evita que el clic sobre un
            marcador también cuente como clic en el mapa (y mueva la ubicación en edición). */}
        {atracciones
          .filter((a) => a.id !== seleccionada?.id)
          .map((a) => {
            const { lat, lng } = posicionDe(a);
            return (
              <CircleMarker
                key={a.id}
                center={[lat, lng]}
                radius={8}
                pathOptions={{ color: COLOR[a.clasificacion] ?? "#555", fillOpacity: 0.8 }}
                bubblingMouseEvents={false}
                eventHandlers={{ click: () => seleccionar(a) }}
              >
                <Tooltip>{a.nombre}</Tooltip>
              </CircleMarker>
            );
          })}

        {/* La ubicación que se está eligiendo (nueva o en edición). */}
        {punto && (
          <CircleMarker
            center={[punto.lat, punto.lng]}
            radius={12}
            pathOptions={{ color: COLOR[form.clasificacion], weight: 4, fillOpacity: 0.3 }}
          >
            <Tooltip permanent>{form.nombre || "Nueva atracción"}</Tooltip>
          </CircleMarker>
        )}
      </MapView>

      <form onSubmit={guardar} style={{ display: "grid", gap: 8, maxWidth: 480, marginTop: 16 }}>
        <h3>{seleccionada ? `Editando: ${seleccionada.nombre}` : "Nueva atracción"}</h3>
        <p style={{ margin: 0, color: "#555" }}>
          Hacé clic en el mapa para {seleccionada ? "mover" : "elegir"} la ubicación.
        </p>

        <label>
          Nombre <input required {...campo("nombre")} />
        </label>
        <label>
          Descripción <textarea rows={2} {...campo("descripcion")} />
        </label>
        <label>
          Clasificación
          <select {...campo("clasificacion")}>
            {CLASIFICACIONES.map((c) => (
              <option key={c} value={c}>
                {c}
              </option>
            ))}
          </select>
        </label>

        <fieldset style={{ display: "grid", gap: 6 }}>
          <legend>Foto (opcional)</legend>
          <label>
            Subir imagen (JPG, PNG, GIF o WEBP, máx. {MAX_FOTO_MB} MB)
            <input
              type="file"
              accept="image/jpeg,image/png,image/gif,image/webp"
              onChange={subirFoto}
              disabled={subiendo}
            />
          </label>
          {subiendo && <span>Subiendo imagen…</span>}
          <label>
            …o pegar la URL de una imagen <input type="url" placeholder="https://..." {...campo("fotoUrl")} />
          </label>
          {form.fotoUrl && (
            <>
              <img
                src={form.fotoUrl}
                alt={`Foto de ${form.nombre || "la atracción"}`}
                style={{ maxWidth: 240, borderRadius: 6 }}
                onError={(e) => (e.currentTarget.style.display = "none")}
                onLoad={(e) => (e.currentTarget.style.display = "block")}
              />
              <button type="button" onClick={() => setForm({ ...form, fotoUrl: "" })}>
                Quitar foto
              </button>
            </>
          )}
        </fieldset>

        {error && (
          <p role="alert" style={{ color: "crimson", margin: 0 }}>
            {error}
          </p>
        )}
        {mensaje && <p style={{ color: "seagreen", margin: 0 }}>{mensaje}</p>}

        <div style={{ display: "flex", gap: 8 }}>
          <button type="submit" disabled={subiendo}>
            {seleccionada ? "Guardar cambios" : "Crear atracción"}
          </button>
          {seleccionada && (
            <>
              <button type="button" onClick={eliminar}>
                Eliminar
              </button>
              <button type="button" onClick={nueva}>
                Cancelar
              </button>
            </>
          )}
        </div>
      </form>

      <h3>Atracciones existentes</h3>
      <ul>
        {atracciones.map((a) => (
          <li key={a.id}>
            <button type="button" onClick={() => seleccionar(a)}>
              {a.nombre}
            </button>{" "}
            — {a.clasificacion}
          </li>
        ))}
      </ul>
    </div>
  );
}
