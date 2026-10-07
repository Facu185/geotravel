import { useEffect, useRef, useState } from "react";
import L from "leaflet";
import { FeatureGroup, GeoJSON } from "react-leaflet";
import { EditControl } from "react-leaflet-draw";
import "leaflet-draw/dist/leaflet.draw.css";
import PaginaMapa from "../../components/PaginaMapa.jsx";
import { Aviso, BotonVolver, IconoFlecha, IconoMas, Segmentado } from "../../components/ui.jsx";
import { COLOR_PRIORIDAD, OPCIONES_PRIORIDAD } from "../../components/colores.js";
import { api } from "../../api/client.js";

/**
 * Módulo Zonas Operativas (dueño: P3): ABM dibujando sobre el mapa.
 *
 * Cómo funciona:
 *  - "geom" siempre es GeoJSON en lon/lat (EPSG:4326). El backend lo convierte al SRID de la base.
 *  - Hay un FeatureGroup "editable" que contiene, a lo sumo, UNA geometría: el polígono recién
 *    dibujado o el de la zona seleccionada. Las demás zonas se muestran de fondo, solo lectura.
 *  - El panel tiene dos vistas: la lista de zonas y el formulario (nueva o en edición).
 *    Dibujar un polígono con la lista abierta ya abre el formulario de una zona nueva.
 *  - Al guardar, la geometría se lee directo de la capa del mapa (no del estado): así vale
 *    lo que se ve en pantalla aunque no se haya apretado "Save" en la barra de dibujo.
 */

const FORM_VACIO = { nombre: "", descripcion: "", nivelPrioridad: 3, responsable: "", observaciones: "" };

export default function ZonasPage() {
  const [zonas, setZonas] = useState([]);
  const [version, setVersion] = useState(0); // fuerza a <GeoJSON> a redibujarse cuando cambian los datos
  const [vista, setVista] = useState("lista"); // "lista" | "form"
  const [seleccionada, setSeleccionada] = useState(null);
  const [form, setForm] = useState(FORM_VACIO);
  const [geom, setGeom] = useState(null); // solo indica si hay un polígono listo; la forma se lee de la capa
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

  const reiniciar = () => {
    // Si no había zona seleccionada, el efecto de arriba no se dispara: se vacía el grupo a mano
    // para no dejar el polígono recién dibujado (ya guardado) duplicado sobre el mapa.
    grupoRef.current?.clearLayers();
    setSeleccionada(null);
    setForm(FORM_VACIO);
    setGeom(null);
    setError(null);
  };

  const volverALista = () => {
    reiniciar();
    setVista("lista");
  };

  const abrirNueva = () => {
    reiniciar();
    setMensaje(null);
    setVista("form");
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
    setVista("form");
  };

  // --- eventos del control de dibujo ---
  const alCrear = (e) => {
    // Una sola geometría a la vez: se descarta cualquier otra que hubiera en el grupo.
    grupoRef.current.eachLayer((capa) => {
      if (capa !== e.layer) grupoRef.current.removeLayer(capa);
    });
    setGeom(e.layer.toGeoJSON().geometry);
    setError(null);
    setMensaje(null);
    setVista("form"); // dibujar con la lista abierta empieza una zona nueva
  };
  const alEditar = (e) => {
    e.layers.eachLayer((capa) => setGeom(capa.toGeoJSON().geometry));
  };
  const alBorrar = () => setGeom(null);

  /** La forma que hay ahora en el mapa (con los vértices tal como están, guardados o no en la barra de dibujo). */
  const geometriaDelMapa = () => {
    const capas = grupoRef.current?.getLayers() ?? [];
    return capas.length > 0 ? capas[0].toGeoJSON().geometry : null;
  };

  const guardar = async (ev) => {
    ev.preventDefault();
    setError(null);
    setMensaje(null);
    const geometria = geometriaDelMapa();
    if (!geometria) {
      setError("Dibujá el polígono de la zona en el mapa antes de guardar.");
      return;
    }
    const cuerpo = {
      ...form,
      nivelPrioridad: Number(form.nivelPrioridad),
      geomGeoJson: JSON.stringify(geometria), // el backend espera la geometría como texto
    };
    try {
      if (seleccionada) {
        await api.put(`/zonas/${seleccionada.id}`, cuerpo);
      } else {
        await api.post("/zonas", cuerpo);
      }
      const texto = seleccionada ? "Zona actualizada." : "Zona creada.";
      volverALista();
      setMensaje(texto);
      cargar();
    } catch (e) {
      setError(e.message); // p. ej. La zona se superpone con "Centro"
    }
  };

  const eliminar = async () => {
    if (!window.confirm(`¿Eliminar la zona "${seleccionada.nombre}"?`)) return;
    try {
      await api.del(`/zonas/${seleccionada.id}`);
      volverALista();
      setMensaje("Zona eliminada.");
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

  const hijosMapa = (
    <>
      <GeoJSON
        key={`${version}-${seleccionada?.id ?? "nueva"}`}
        data={fondo}
        style={(f) => ({ color: "#5b6b52", weight: 1, fillColor: COLOR_PRIORIDAD[f.properties.nivel], fillOpacity: 0.5 })}
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
    </>
  );

  return (
    <PaginaMapa etiqueta="Administración" titulo="Zonas operativas" etiquetaBoton="Zonas" hijosMapa={hijosMapa}>
      {vista === "lista" ? (
        <>
          <div className="panel__seccion">
            {mensaje && <Aviso tipo="ok">{mensaje}</Aviso>}
            {error && <Aviso tipo="error">{error}</Aviso>}
            <button type="button" className="btn btn--primario btn--ancho" onClick={abrirNueva}>
              <IconoMas /> Nueva zona
            </button>
            <p className="ayuda">También podés dibujar el polígono directo en el mapa, o tocar una zona para editarla.</p>
          </div>
          <ul className="items">
            {zonas.map((z) => (
              <li key={z.id}>
                <button type="button" className="item" onClick={() => seleccionar(z)}>
                  <span className="item__marca item__marca--zona" style={{ "--color": COLOR_PRIORIDAD[z.nivelPrioridad] }} aria-hidden="true" />
                  <span className="item__texto">
                    <span className="item__titulo">{z.nombre}</span>
                    <span className="item__detalle">
                      Prioridad {z.nivelPrioridad}
                      {z.responsable ? ` · ${z.responsable}` : ""}
                    </span>
                  </span>
                  <IconoFlecha />
                </button>
              </li>
            ))}
          </ul>
          {zonas.length === 0 && <p className="vacio">Todavía no hay zonas operativas.</p>}
        </>
      ) : (
        <form className="panel__seccion formulario" onSubmit={guardar}>
          <BotonVolver onClick={volverALista}>Zonas</BotonVolver>
          <h3 className="formulario__titulo">{seleccionada ? seleccionada.nombre : "Nueva zona"}</h3>

          <p className={geom ? "paso paso--listo" : "paso"}>
            {seleccionada
              ? "Para cambiar la forma, usá el lápiz del mapa y mové los vértices."
              : geom
                ? "Polígono dibujado. Completá los datos y guardá."
                : "Dibujá el polígono con la herramienta ⬠ del mapa (arriba a la derecha)."}
          </p>

          <label className="campo">
            <span className="campo__etiqueta">Nombre</span>
            <input required {...campo("nombre")} />
          </label>
          <label className="campo">
            <span className="campo__etiqueta">Descripción</span>
            <textarea rows={2} {...campo("descripcion")} />
          </label>
          <Segmentado
            leyenda="Prioridad (1 = máxima, 5 = mínima)"
            nombre="nivelPrioridad"
            opciones={OPCIONES_PRIORIDAD}
            valor={Number(form.nivelPrioridad)}
            onChange={(n) => setForm({ ...form, nivelPrioridad: n })}
          />
          <label className="campo">
            <span className="campo__etiqueta">Responsable</span>
            <input {...campo("responsable")} />
          </label>
          <label className="campo">
            <span className="campo__etiqueta">Observaciones</span>
            <textarea rows={2} {...campo("observaciones")} />
          </label>

          {error && <Aviso tipo="error">{error}</Aviso>}

          <div className="acciones">
            <button type="submit" className="btn btn--primario">
              {seleccionada ? "Guardar cambios" : "Crear zona"}
            </button>
            <button type="button" className="btn btn--secundario" onClick={volverALista}>
              Cancelar
            </button>
            {seleccionada && (
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
