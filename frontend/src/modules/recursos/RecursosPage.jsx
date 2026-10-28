import { useMemo, useState } from "react";
import { Marker, Tooltip, useMapEvents } from "react-leaflet";
import PaginaMapa from "../../components/PaginaMapa.jsx";
import CargaPorZona, { AvisoCarga, SIN_CARGAR } from "../../components/CargaPorZona.jsx";
import Enfocar from "../../components/Enfocar.jsx";
import CapaAgrupada from "../../components/CapaAgrupada.jsx";
import { IconoRecurso, iconoRecurso } from "../../components/iconos.jsx";
import { Aviso, BotonVolver, IconoFlecha, IconoMas, Segmentado } from "../../components/ui.jsx";
import { COLOR_ESTADO_RECURSO, TIPOS_RECURSO, nombreTipoRecurso } from "../../components/colores.js";
import { api } from "../../api/client.js";

/**
 * Módulo Recursos de emergencia (dueño: P3): ABM de ambulancias, bomberos, patrullas, etc.
 *
 * Reemplaza al módulo "Atracciones" de GeoTravel: mismo patrón (clic en el mapa para
 * ubicar un punto), pero sin foto -- UrbanSafe no la pide.
 *
 * El "tipo" se elige de una lista cerrada (TIPOS_RECURSO): son los únicos que reconoce el
 * estilo de GeoServer, y el backend rechaza cualquier otro (ver RecursoResource.java).
 *
 * Igual que en Atracciones: Leaflet trabaja con [lat, lng] pero GeoJSON exige [lng, lat];
 * la conversión está aislada en "geometria" (al guardar) y "posicionDe" (al leer).
 *
 * El panel tiene dos vistas: la lista de recursos y el formulario (nuevo o en edición).
 * El mapa solo acepta clics de ubicación cuando el formulario está abierto.
 *
 * Carga a demanda (CargaPorZona): solo se traen los recursos del rectángulo visible, hasta un
 * límite. Con el mapa alejado no se carga nada editable y los recursos los dibuja GeoServer
 * como imagen (capa WMS).
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
  const [carga, setCarga] = useState(SIN_CARGAR); // recursos de la vista actual (ver CargaPorZona)
  const [recarga, setRecarga] = useState(0); // cambiarlo vuelve a pedir la vista (después de guardar o borrar)
  const recursos = carga.items;
  const lejos = carga.estado === "lejos";
  const [enfoque, setEnfoque] = useState(null); // recurso elegido en la lista: el mapa va hasta él
  const [vista, setVista] = useState("lista"); // "lista" | "form"
  const [seleccionado, setSeleccionado] = useState(null);
  const [form, setForm] = useState(FORM_VACIO);
  const [punto, setPunto] = useState(null); // { lat, lng } del recurso que se está creando/editando
  const [error, setError] = useState(null);
  const [mensaje, setMensaje] = useState(null);

  const cargar = () => setRecarga((n) => n + 1);

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
    // Borrar un recurso lo quita de las asignaciones de incidentes (ON DELETE CASCADE): se avisa cuántas son.
    let aviso = "";
    try {
      const { total } = await api.get(`/consultas/incidentes-por-recurso/${seleccionado.id}?limit=1`);
      if (total > 0) {
        aviso = `\n\nEstá asignado a ${total} ${total === 1 ? "incidente" : "incidentes"}: se quitará de ${total === 1 ? "esa asignación" : "esas asignaciones"} y se perderá ese registro.`;
      }
    } catch {
      // si no se pudo consultar, se pregunta igual
    }
    if (!window.confirm(`¿Eliminar "${seleccionado.identificacion}"?${aviso}`)) return;
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

  // Los demás recursos, de fondo: se agrupan con un número al alejar el mapa (CapaAgrupada).
  const agrupables = useMemo(
    () =>
      recursos
        .filter((r) => r.id !== seleccionado?.id)
        .map((r) => {
          const { lat, lng } = posicionDe(r);
          return {
            id: r.id,
            pos: [lat, lng],
            icon: iconoRecurso(r.tipo, r.estadoOperativo),
            etiqueta: `${r.identificacion} — ${nombreTipoRecurso(r.tipo)}`,
            alClick: () => seleccionar(r),
          };
        }),
    // seleccionar solo usa estado de la página que no cambia lo que se dibuja
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [recursos, seleccionado],
  );

  const hijosMapa = (
    <>
      <CargaPorZona ruta="/recursos" recarga={recarga} alCambiar={setCarga} />
      <Enfocar objetivo={enfoque} />
      <ClickEnMapa alClick={(ubicacion) => vista === "form" && setPunto(ubicacion)} />

      {/* Los demás recursos, de fondo: la forma del ícono es el tipo y el color es el estado
          (ver components/iconos.jsx). Un clic sobre un marcador no cuenta como clic en el mapa
          (no mueve la ubicación en edición). */}
      <CapaAgrupada items={agrupables} color="#0f766e" />

      {/* La ubicación que se está eligiendo (nueva o en edición): el mismo ícono, resaltado. */}
      {vista === "form" && punto && (
        <Marker position={[punto.lat, punto.lng]} icon={iconoRecurso(form.tipo, form.estadoOperativo, { resaltado: true })}>
          <Tooltip permanent>{form.identificacion || "Nuevo recurso"}</Tooltip>
        </Marker>
      )}
    </>
  );

  return (
    <PaginaMapa
      etiqueta="Administración"
      titulo="Recursos de emergencia"
      etiquetaBoton="Recursos"
      hijosMapa={hijosMapa}
      // Alejado, los recursos se ven igual: los dibuja GeoServer (imagen, no objetos en memoria).
      mapaProps={{ layers: lejos ? ["geotravel:recurso"] : [], wmsExtra: { actualizado: recarga } }}
      aviso={<AvisoCarga carga={carga} nombre="recursos" />}
    >
      {vista === "lista" ? (
        <>
          <div className="panel__seccion">
            {mensaje && <Aviso tipo="ok">{mensaje}</Aviso>}
            {error && <Aviso tipo="error">{error}</Aviso>}
            <button type="button" className="btn btn--primario btn--ancho" onClick={abrirNuevo}>
              <IconoMas /> Nuevo recurso
            </button>
            <p className="ayuda">También podés tocar un recurso en el mapa para editarlo.</p>
            {!lejos && recursos.length > 0 && (
              <p className="ayuda">
                {carga.truncado ? `Recursos en esta vista: ${recursos.length} de ${carga.total}` : `Recursos en esta vista: ${recursos.length}`}
              </p>
            )}
            {/* Leyenda: la forma es el tipo; el color, el estado operativo. */}
            <ul className="leyenda-iconos" aria-label="Tipos de recurso">
              {TIPOS_RECURSO.map((t) => (
                <li key={t}>
                  <IconoRecurso tipo={t} estado="" chico /> {nombreTipoRecurso(t)}
                </li>
              ))}
            </ul>
            <ul className="leyenda-iconos" aria-label="Estados operativos">
              {ESTADOS_OPERATIVOS.map((e) => (
                <li key={e.valor}>
                  <span className="item__marca" style={{ "--color": e.color, borderRadius: "50%" }} aria-hidden="true" /> {e.etiqueta}
                </li>
              ))}
            </ul>
          </div>
          <ul className="items">
            {recursos.map((r) => (
              <li key={r.id}>
                <button
                  type="button"
                  className="item"
                  onClick={() => {
                    seleccionar(r);
                    setEnfoque({ geom: JSON.parse(r.geom) });
                  }}
                >
                  <IconoRecurso tipo={r.tipo} estado={r.estadoOperativo} chico />
                  <span className="item__texto">
                    <span className="item__titulo">{r.identificacion}</span>
                    <span className="item__detalle">
                      {nombreTipoRecurso(r.tipo)} · {r.estadoOperativo}
                    </span>
                  </span>
                  <IconoFlecha />
                </button>
              </li>
            ))}
          </ul>
          {lejos && <p className="vacio">Acercá el mapa para listar y editar los recursos de esa área.</p>}
          {carga.estado === "listo" && recursos.length === 0 && <p className="vacio">No hay recursos en esta parte del mapa.</p>}
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
            <select required {...campo("tipo")}>
              <option value="" disabled>
                Elegí un tipo…
              </option>
              {TIPOS_RECURSO.map((t) => (
                <option key={t} value={t}>
                  {nombreTipoRecurso(t)}
                </option>
              ))}
              {/* Un recurso viejo con un tipo fuera de la lista: se muestra para no cambiarlo en
                  silencio, y el backend pedirá elegir uno válido al guardar. */}
              {form.tipo && !TIPOS_RECURSO.includes(form.tipo) && (
                <option value={form.tipo}>{form.tipo} (no válido)</option>
              )}
            </select>
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
