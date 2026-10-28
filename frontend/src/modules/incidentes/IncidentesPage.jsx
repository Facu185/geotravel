import { useEffect, useRef, useState } from "react";
import L from "leaflet";
import { GeoJSON } from "react-leaflet";
import PaginaMapa from "../../components/PaginaMapa.jsx";
import CargaPorZona, { AvisoCarga, SIN_CARGAR } from "../../components/CargaPorZona.jsx";
import Enfocar from "../../components/Enfocar.jsx";
import EditorGeometria, { cargarGeometria, formaDe, geometriaDelGrupo } from "../../components/EditorGeometria.jsx";
import { Aviso, BotonVolver, IconoFlecha, IconoMas, Insignia, Segmentado } from "../../components/ui.jsx";
import { COLOR_ESTADO_INCIDENTE, OPCIONES_PRIORIDAD, TIPOS_INCIDENTE, nombreTipoIncidente } from "../../components/colores.js";
import { IconoIncidente, iconoIncidente } from "../../components/iconos.jsx";
import { api } from "../../api/client.js";
import { CARGA_POR_ZONA } from "../../components/region.js";

/**
 * Módulo Incidentes (dueño: P4): ABM + avanzar estado (con ramas) + histórico.
 * Reemplaza al módulo "Recorridos" de GeoTravel -- ya no hay estacionalidad, y "avanzar"
 * ahora elige un estado destino entre varios posibles, no un único botón.
 *
 * TRANSICIONES espeja la del backend (IncidenteResource.java) solo para decidir qué
 * opciones mostrar; el backend es quien valida de verdad (409 si no es válida) -- si
 * alguna vez se desincronizan, el mensaje de error del backend manda.
 *
 * La ubicación de un incidente es un PUNTO (un lugar: un choque), una LÍNEA (un tramo: una calle
 * cortada) o un POLÍGONO (un área: una inundación). "geom" siempre es GeoJSON en lon/lat y el
 * backend lo convierte al SRID de la base. Se dibuja con EditorGeometria (componente compartido).
 *
 * El panel tiene tres vistas: la lista, el detalle de un incidente (con su historial, las
 * transiciones posibles y los botones Editar y Eliminar) y el formulario (nuevo o en edición).
 * Dibujar una forma con la lista abierta ya abre el formulario de un incidente nuevo.
 *
 * Carga a demanda (CargaPorZona): solo se traen los incidentes del rectángulo visible, hasta un
 * límite. Con el mapa alejado no se carga nada editable y los incidentes los dibuja GeoServer como
 * imagen (capa WMS), así el navegador nunca tiene miles de objetos en memoria.
 */

const TRANSICIONES = {
  Registrado: ["En atención", "Derivado", "Cancelado"],
  "En atención": ["Resuelto", "Derivado", "Cancelado"],
  Derivado: ["En atención", "Cancelado"],
  Resuelto: [],
  Cancelado: [],
};

const FORM_VACIO = { titulo: "", descripcion: "", tipoIncidente: "otro", prioridad: 3, equipoResponsable: "" };

const FORMAS = [
  { valor: "Point", etiqueta: "Punto", color: "#13202c" },
  { valor: "LineString", etiqueta: "Línea", color: "#13202c" },
  { valor: "Polygon", etiqueta: "Polígono", color: "#13202c" },
];
const NOMBRE_FORMA = { Point: "punto", LineString: "línea", Polygon: "polígono" };
const CON_ARTICULO = { Point: "el punto", LineString: "la línea", Polygon: "el polígono" };
const CON_ARTICULO_INDEFINIDO = { Point: "un punto", LineString: "una línea", Polygon: "un polígono" };
const AYUDA_FORMA = {
  Point: "un lugar (un choque, un incendio). Hacé clic en el mapa.",
  LineString: "un tramo (una calle cortada). Un clic por vértice; el último, otra vez para terminar.",
  Polygon: "un área (una inundación). Un clic por vértice; cerrá tocando el primero.",
};
const MARCA_FORMA = { Point: "circulo", LineString: "linea", Polygon: "zona" };


const formatoFecha = (iso) =>
  new Date(iso).toLocaleString("es-UY", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit", hour12: false });

/** Cómo se dibuja un incidente en el mapa: color del estado; punto en círculo, línea gruesa o área con relleno. */
const estiloIncidente = (estado, tipo, resaltado) => {
  const color = COLOR_ESTADO_INCIDENTE[estado] ?? "#555";
  const forma = tipo.replace("Multi", "");
  if (forma === "Point") return { color: resaltado ? "#13202c" : "#ffffff", weight: resaltado ? 4 : 1.5, fillColor: color, fillOpacity: 0.9 };
  if (forma === "LineString") return { color: resaltado ? "#13202c" : color, weight: resaltado ? 8 : 5, opacity: 0.9 };
  return { color: resaltado ? "#13202c" : color, weight: resaltado ? 4 : 2, fillColor: color, fillOpacity: resaltado ? 0.45 : 0.3 };
};

const comoFeature = (incidente) => ({
  type: "Feature",
  properties: { id: incidente.id, titulo: incidente.titulo, estado: incidente.estado, tipoIncidente: incidente.tipoIncidente },
  geometry: JSON.parse(incidente.geom),
});

/** Un incidente puntual se dibuja con el ícono compartido (components/iconos.jsx): el color es el estado. */
const marcador = (resaltado) => (f, latlng) => L.marker(latlng, { icon: iconoIncidente(f.properties.tipoIncidente, f.properties.estado, { resaltado }) });

export default function IncidentesPage() {
  const [carga, setCarga] = useState(SIN_CARGAR); // incidentes de la vista actual (ver CargaPorZona)
  const [recarga, setRecarga] = useState(0); // cambiarlo vuelve a pedir la vista (después de guardar, borrar o cambiar de estado)
  const [version, setVersion] = useState(0); // fuerza a <GeoJSON> a redibujarse cuando cambian los datos
  const incidentes = carga.items;
  const [enfoque, setEnfoque] = useState(null); // incidente elegido en la lista: el mapa va hasta él
  const [vista, setVista] = useState("lista"); // "lista" | "detalle" | "form"
  const [seleccionado, setSeleccionado] = useState(null);
  const [historial, setHistorial] = useState([]);
  const [estadoDestino, setEstadoDestino] = useState("");
  const [usuario, setUsuario] = useState("");
  const [form, setForm] = useState(FORM_VACIO);
  const [forma, setForma] = useState("Point"); // forma elegida en el formulario
  const [hayForma, setHayForma] = useState(false); // solo indica si hay algo dibujado; la forma se lee de la capa
  const [pedido, setPedido] = useState(null); // pide a EditorGeometria que empiece a dibujar
  const [error, setError] = useState(null);
  const [mensaje, setMensaje] = useState(null);
  const grupoRef = useRef(null);
  const dibujando = useRef(false);

  const alCargar = (nueva) => {
    setCarga(nueva);
    if (nueva.estado === "listo" || nueva.estado === "lejos") setVersion((v) => v + 1);
  };
  const cargar = () => setRecarga((n) => n + 1);

  // Al editar un incidente, su forma pasa al grupo editable (el resto de la vida del grupo la manejan
  // reiniciar() y el dibujo: acá no se vacía, para no borrar lo que se acaba de dibujar).
  useEffect(() => {
    if (vista === "form" && seleccionado && grupoRef.current) {
      cargarGeometria(grupoRef.current, JSON.parse(seleccionado.geom));
    }
  }, [vista, seleccionado]);

  const reiniciar = () => {
    // Se vacía el grupo a mano: una forma recién dibujada (ya guardada o cancelada) no debe quedar sobre el mapa.
    grupoRef.current?.clearLayers();
    setSeleccionado(null);
    setHistorial([]);
    setEstadoDestino("");
    setForm(FORM_VACIO);
    setHayForma(false);
    setPedido(null);
    setError(null);
  };

  const volverALista = () => {
    reiniciar();
    setVista("lista");
  };

  const abrirNuevo = () => {
    reiniciar();
    setMensaje(null);
    setForma("Point");
    setPedido({ forma: "Point" }); // el primer clic en el mapa ya ubica el incidente
    setVista("form");
  };

  const seleccionar = async (inc) => {
    if (dibujando.current) return; // un clic a mitad de un trazo no cambia de incidente
    reiniciar();
    setSeleccionado(inc);
    setMensaje(null);
    setVista("detalle");
    try {
      setHistorial(await api.get(`/incidentes/${inc.id}/historial`));
    } catch (e) {
      setError(e.message);
    }
  };

  const editar = () => {
    setForm({
      titulo: seleccionado.titulo,
      descripcion: seleccionado.descripcion ?? "",
      tipoIncidente: seleccionado.tipoIncidente,
      prioridad: seleccionado.prioridad,
      equipoResponsable: seleccionado.equipoResponsable ?? "",
    });
    setForma(formaDe(JSON.parse(seleccionado.geom)));
    setHayForma(true);
    setPedido(null);
    setError(null);
    setMensaje(null);
    setVista("form");
  };

  // --- eventos del editor de geometría ---
  const alDibujar = (geometria) => {
    // Dibujar con el detalle o la lista abiertos empieza un incidente nuevo.
    if (vista !== "form") {
      setSeleccionado(null);
      setHistorial([]);
      setEstadoDestino("");
      setForm(FORM_VACIO);
      setVista("form");
    }
    setForma(formaDe(geometria));
    setHayForma(true);
    setError(null);
    setMensaje(null);
  };
  const alEditar = (geometria) => setForma(formaDe(geometria));
  const alBorrar = () => setHayForma(false);

  const elegirForma = (nueva) => {
    setForma(nueva);
    setPedido({ forma: nueva });
  };

  const guardar = async (ev) => {
    ev.preventDefault();
    setError(null);
    setMensaje(null);
    const geometria = geometriaDelGrupo(grupoRef.current);
    if (!geometria) {
      setError("Dibujá la ubicación en el mapa antes de guardar: un punto, una línea o un polígono.");
      return;
    }
    const cuerpo = { ...form, prioridad: Number(form.prioridad), geomGeoJson: JSON.stringify(geometria) };
    const edicion = seleccionado !== null;
    try {
      if (edicion) await api.put(`/incidentes/${seleccionado.id}`, cuerpo);
      else await api.post("/incidentes", cuerpo);
      volverALista();
      setMensaje(edicion ? "Incidente actualizado." : "Incidente registrado.");
      cargar();
    } catch (e) {
      setError(e.message);
    }
  };

  const eliminar = async () => {
    if (!window.confirm(`¿Eliminar el incidente "${seleccionado.titulo}"?`)) return;
    try {
      await api.del(`/incidentes/${seleccionado.id}`);
      volverALista();
      setMensaje("Incidente eliminado.");
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

  // Los demás incidentes, de fondo (el que se edita va en el grupo editable, y el del detalle, resaltado).
  const fondo = {
    type: "FeatureCollection",
    features: incidentes.filter((i) => i.id !== seleccionado?.id).map(comoFeature),
  };
  const lejos = carga.estado === "lejos";
  const formaSeleccionado = seleccionado ? formaDe(JSON.parse(seleccionado.geom)) : null;

  const hijosMapa = (
    <>
      <CargaPorZona ruta="/incidentes" recarga={recarga} alCambiar={alCargar} />
      <Enfocar objetivo={enfoque} />
      <GeoJSON
        key={`${version}-${seleccionado?.id ?? "ninguno"}`}
        data={fondo}
        pointToLayer={marcador(false)}
        style={(f) => estiloIncidente(f.properties.estado, f.geometry.type, false)}
        onEachFeature={(f, capa) => {
          capa.bindTooltip(`${f.properties.titulo} — ${f.properties.estado}`);
          capa.on("click", () => seleccionar(incidentes.find((i) => i.id === f.properties.id)));
        }}
      />
      {vista === "detalle" && seleccionado && (
        <GeoJSON
          key={`resaltado-${seleccionado.id}-${seleccionado.estado}-${version}`}
          data={comoFeature(seleccionado)}
          pointToLayer={marcador(true)}
          style={(f) => estiloIncidente(f.properties.estado, f.geometry.type, true)}
          interactive={false}
        />
      )}
      <EditorGeometria grupoRef={grupoRef} pedido={pedido} dibujando={dibujando} alCrear={alDibujar} alEditar={alEditar} alBorrar={alBorrar} />
    </>
  );

  return (
    <PaginaMapa
      etiqueta="Administración"
      titulo="Incidentes"
      etiquetaBoton="Incidentes"
      hijosMapa={hijosMapa}
      // Alejado, los incidentes se ven igual: los dibuja GeoServer (imagen, no objetos en memoria).
      mapaProps={{ layers: lejos ? ["geotravel:incidente"] : [], wmsExtra: { actualizado: recarga }, mostrarZoom: true, zoomMinimo: CARGA_POR_ZONA.zoomMinimo }}
      aviso={<AvisoCarga carga={carga} nombre="incidentes" />}
    >
      {vista === "lista" && (
        <>
          <div className="panel__seccion">
            {mensaje && <Aviso tipo="ok">{mensaje}</Aviso>}
            {error && <Aviso tipo="error">{error}</Aviso>}
            <button type="button" className="btn btn--primario btn--ancho" onClick={abrirNuevo}>
              <IconoMas /> Registrar incidente
            </button>
            <p className="ayuda">
              Un incidente puede ser un punto, una línea (una calle cortada) o un polígono (un área afectada). También podés dibujarlo
              directo con las herramientas del mapa, o tocar uno para ver su detalle y cambiar su estado.
            </p>
            {!lejos && incidentes.length > 0 && (
              <p className="ayuda">
                {carga.truncado ? `Incidentes en esta vista: ${incidentes.length} de ${carga.total}` : `Incidentes en esta vista: ${incidentes.length}`}
              </p>
            )}
          </div>
          <ul className="items">
            {incidentes.map((i) => {
              const tipo = formaDe(JSON.parse(i.geom));
              return (
                <li key={i.id}>
                  <button
                    type="button"
                    className="item"
                    onClick={() => {
                      seleccionar(i);
                      setEnfoque({ geom: JSON.parse(i.geom) });
                    }}
                  >
                    {tipo === "Point" ? (
                      <IconoIncidente tipo={i.tipoIncidente} estado={i.estado} chico />
                    ) : (
                      <span className={`item__marca item__marca--${MARCA_FORMA[tipo]}`} style={{ "--color": COLOR_ESTADO_INCIDENTE[i.estado] }} aria-hidden="true" />
                    )}
                    <span className="item__texto">
                      <span className="item__titulo">{i.titulo}</span>
                      <span className="item__detalle">
                        {i.estado} · prioridad {i.prioridad} · {NOMBRE_FORMA[tipo]}
                      </span>
                    </span>
                    <IconoFlecha />
                  </button>
                </li>
              );
            })}
          </ul>
          {lejos && <p className="vacio">Acercá el mapa para listar y editar los incidentes de esa área.</p>}
          {carga.estado === "listo" && incidentes.length === 0 && <p className="vacio">No hay incidentes en esta parte del mapa.</p>}
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
              <dd>{nombreTipoIncidente(seleccionado.tipoIncidente)}</dd>
            </div>
            <div>
              <dt>Prioridad</dt>
              <dd>{seleccionado.prioridad}</dd>
            </div>
            <div>
              <dt>Ubicación</dt>
              <dd>{NOMBRE_FORMA[formaSeleccionado]}</dd>
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

          <div className="acciones">
            <button type="button" className="btn btn--secundario" onClick={editar}>
              Editar datos y ubicación
            </button>
            <button type="button" className="btn btn--peligro" onClick={eliminar}>
              Eliminar
            </button>
          </div>

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

      {vista === "form" && (
        <form className="panel__seccion formulario" onSubmit={guardar}>
          <BotonVolver onClick={volverALista}>Incidentes</BotonVolver>
          <h3 className="formulario__titulo">{seleccionado ? seleccionado.titulo : "Registrar incidente"}</h3>

          <Segmentado leyenda="Ubicación" nombre="forma" opciones={FORMAS} valor={forma} onChange={elegirForma} />
          <p className={hayForma ? "paso paso--listo" : "paso"}>
            {hayForma
              ? seleccionado
                ? `Para cambiar la forma, usá el lápiz del mapa y mové los vértices; o elegí una forma y dibujala de nuevo.`
                : `Ya dibujaste ${CON_ARTICULO_INDEFINIDO[forma]}. Podés ajustar su forma con el lápiz del mapa, o elegir otra forma y dibujarla de nuevo.`
              : `Dibujá ${CON_ARTICULO[forma]}: ${AYUDA_FORMA[forma]}`}
          </p>
          {hayForma && (
            <button type="button" className="btn btn--secundario" onClick={() => setPedido({ forma })}>
              Dibujar de nuevo
            </button>
          )}

          <label className="campo">
            <span className="campo__etiqueta">Título</span>
            <input required {...campo("titulo")} />
          </label>
          <label className="campo">
            <span className="campo__etiqueta">Descripción</span>
            <textarea rows={2} {...campo("descripcion")} />
          </label>
          <fieldset className="segmentado">
            <legend className="campo__etiqueta">Tipo (define el ícono del incidente)</legend>
            <div className="segmentado__opciones">
              {/* Un tipo que no está en la lista (datos viejos) se conserva y se dibuja como "otro". */}
              {(TIPOS_INCIDENTE.includes(form.tipoIncidente) ? TIPOS_INCIDENTE : [...TIPOS_INCIDENTE, form.tipoIncidente]).map((t) => (
                <label key={t} className={t === form.tipoIncidente ? "segmentado__opcion segmentado__opcion--activa" : "segmentado__opcion"}>
                  <input type="radio" name="tipoIncidente" value={t} checked={t === form.tipoIncidente} onChange={() => setForm({ ...form, tipoIncidente: t })} />
                  <IconoIncidente tipo={t} chico />
                  {nombreTipoIncidente(t)}
                </label>
              ))}
            </div>
          </fieldset>
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
              {seleccionado ? "Guardar cambios" : "Registrar incidente"}
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
