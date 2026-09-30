import { useEffect, useRef, useState } from "react";
import L from "leaflet";
import { FeatureGroup, GeoJSON } from "react-leaflet";
import { EditControl } from "react-leaflet-draw";
import "leaflet-draw/dist/leaflet.draw.css";
import MapView from "../../components/MapView.jsx";
import { api } from "../../api/client.js";

/**
 * Módulo Zonas Operativas (dueño: P3): ABM dibujando sobre el mapa.
 *
 * Cómo funciona:
 *  - "geom" siempre es GeoJSON en lon/lat (EPSG:4326). El backend lo convierte al SRID de la base.
 *  - Hay un FeatureGroup "editable" que contiene, a lo sumo, UNA geometría: el polígono recién
 *    dibujado o el de la zona seleccionada. Las demás zonas se muestran de fondo, solo lectura.
 *  - Sin zona seleccionada = modo "nueva zona". Con zona seleccionada = modo "editar".
 */

const FORM_VACIO = { nombre: "", descripcion: "", nivelPrioridad: 3, responsable: "", observaciones: "" };

// Más prioridad (1) = más intenso. Mismos colores que geoserver/styles/zonas_atractivo.sld
// (pendiente de renombrar a zonas_prioridad.sld -- tarea de P1).
const COLOR_NIVEL = { 1: "#c0392b", 2: "#d9754f", 3: "#e6a95f", 4: "#9db08f", 5: "#c7d0c3" };

export default function ZonasPage() {
  const [zonas, setZonas] = useState([]);
  const [version, setVersion] = useState(0); // fuerza a <GeoJSON> a redibujarse cuando cambian los datos
  const [seleccionada, setSeleccionada] = useState(null);
  const [form, setForm] = useState(FORM_VACIO);
  const [geom, setGeom] = useState(null);
  const [error, setError] = useState(null);
  const [mensaje, setMensaje] = useState(null);
  const grupoRef = useRef(null);

  const cargar = () =>
    api
      .get("/zonas")
      .then((data) => {
        setZonas(data);
        setVersion((v) => v + 1);
      })
      .catch((e) => setError(e.message));

  useEffect(() => {
    cargar();
  }, []);

  // Cada vez que cambia la zona seleccionada, se carga su polígono en el grupo editable.
  useEffect(() => {
    const grupo = grupoRef.current;
    if (!grupo) return;
    grupo.clearLayers();
    if (seleccionada) {
      L.geoJSON(JSON.parse(seleccionada.geom)).eachLayer((capa) => grupo.addLayer(capa));
    }
  }, [seleccionada]);

  const nueva = () => {
    // Si no había zona seleccionada, el efecto de arriba no se dispara: se vacía el grupo a mano
    // para no dejar el polígono recién dibujado (ya guardado) duplicado sobre el mapa.
    grupoRef.current?.clearLayers();
    setSeleccionada(null);
    setForm(FORM_VACIO);
    setGeom(null);
    setError(null);
  };

  const seleccionar = (zona) => {
    setSeleccionada(zona);
    setForm({
      nombre: zona.nombre,
      descripcion: zona.descripcion ?? "",
      nivelPrioridad: zona.nivelPrioridad,
      responsable: zona.responsable ?? "",
      observaciones: zona.observaciones ?? "",
    });
    setGeom(JSON.parse(zona.geom));
    setError(null);
    setMensaje(null);
  };

  // --- eventos del control de dibujo ---
  const alCrear = (e) => {
    // Una sola geometría a la vez: se descarta cualquier otra que hubiera en el grupo.
    grupoRef.current.eachLayer((capa) => {
      if (capa !== e.layer) grupoRef.current.removeLayer(capa);
    });
    setGeom(e.layer.toGeoJSON().geometry);
    setError(null);
  };
  const alEditar = (e) => {
    e.layers.eachLayer((capa) => setGeom(capa.toGeoJSON().geometry));
  };
  const alBorrar = () => setGeom(null);

  const guardar = async (ev) => {
    ev.preventDefault();
    setError(null);
    setMensaje(null);
    if (!geom) {
      setError("Dibujá el polígono de la zona en el mapa antes de guardar.");
      return;
    }
    const cuerpo = {
      ...form,
      nivelPrioridad: Number(form.nivelPrioridad),
      geomGeoJson: JSON.stringify(geom), // el backend espera la geometría como texto
    };
    try {
      if (seleccionada) {
        await api.put(`/zonas/${seleccionada.id}`, cuerpo);
      } else {
        await api.post("/zonas", cuerpo);
      }
      setMensaje(seleccionada ? "Zona actualizada." : "Zona creada.");
      nueva();
      cargar();
    } catch (e) {
      setError(e.message); // p. ej. La zona se superpone con "Centro"
    }
  };

  const eliminar = async () => {
    if (!window.confirm(`¿Eliminar la zona "${seleccionada.nombre}"?`)) return;
    try {
      await api.del(`/zonas/${seleccionada.id}`);
      setMensaje("Zona eliminada.");
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

  // Las demás zonas, de fondo (la seleccionada va en el grupo editable, no acá).
  const fondo = {
    type: "FeatureCollection",
    features: zonas
      .filter((z) => z.id !== seleccionada?.id)
      .map((z) => ({
        type: "Feature",
        properties: { id: z.id, nombre: z.nombre, nivel: z.nivelPrioridad },
        geometry: JSON.parse(z.geom),
      })),
  };

  return (
    <div>
      <h2>Zonas operativas</h2>

      <MapView>
        <GeoJSON
          key={`${version}-${seleccionada?.id ?? "nueva"}`}
          data={fondo}
          style={(f) => ({ color: "#5b6b52", weight: 1, fillColor: COLOR_NIVEL[f.properties.nivel], fillOpacity: 0.45 })}
          onEachFeature={(f, capa) => {
            capa.bindTooltip(f.properties.nombre);
            capa.on("click", () => seleccionar(zonas.find((z) => z.id === f.properties.id)));
          }}
        />
        <FeatureGroup ref={grupoRef}>
          <EditControl
            position="topright"
            onCreated={alCrear}
            onEdited={alEditar}
            onDeleted={alBorrar}
            draw={{
              polygon: { allowIntersection: false, showArea: false },
              rectangle: false,
              polyline: false,
              circle: false,
              marker: false,
              circlemarker: false,
            }}
          />
        </FeatureGroup>
      </MapView>

      <form onSubmit={guardar} style={{ display: "grid", gap: 8, maxWidth: 480, marginTop: 16 }}>
        <h3>{seleccionada ? `Editando: ${seleccionada.nombre}` : "Nueva zona"}</h3>
        <p style={{ margin: 0, color: "#555" }}>
          {seleccionada
            ? "Movés los vértices con el botón de edición del mapa (lápiz) y guardás."
            : "Dibujá el polígono con la herramienta del mapa (arriba a la derecha) y completá los datos."}
        </p>

        <label>
          Nombre <input required {...campo("nombre")} />
        </label>
        <label>
          Descripción <textarea rows={2} {...campo("descripcion")} />
        </label>
        <label>
          Nivel de prioridad (1 = máxima, 5 = mínima)
          <select {...campo("nivelPrioridad")}>
            {[1, 2, 3, 4, 5].map((n) => (
              <option key={n} value={n}>
                {n}
              </option>
            ))}
          </select>
        </label>
        <label>
          Responsable <input {...campo("responsable")} />
        </label>
        <label>
          Observaciones <textarea rows={2} {...campo("observaciones")} />
        </label>

        {error && (
          <p role="alert" style={{ color: "crimson", margin: 0 }}>
            {error}
          </p>
        )}
        {mensaje && <p style={{ color: "seagreen", margin: 0 }}>{mensaje}</p>}

        <div style={{ display: "flex", gap: 8 }}>
          <button type="submit">{seleccionada ? "Guardar cambios" : "Crear zona"}</button>
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

      <h3>Zonas existentes</h3>
      <ul>
        {zonas.map((z) => (
          <li key={z.id}>
            <button type="button" onClick={() => seleccionar(z)}>
              {z.nombre}
            </button>{" "}
            — prioridad {z.nivelPrioridad}
          </li>
        ))}
      </ul>
    </div>
  );
}
