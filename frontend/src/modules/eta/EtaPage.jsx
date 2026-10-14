import { useEffect, useRef, useState } from "react";
import PaginaMapa from "../../components/PaginaMapa.jsx";
import RutaEtaEnMapa from "../../components/RutaEtaEnMapa.jsx";
import { Aviso } from "../../components/ui.jsx";
import { nombreTipoRecurso } from "../../components/colores.js";
import { api } from "../../api/client.js";

const numero = new Intl.NumberFormat("es-UY");

export default function EtaPage() {
  const [recursos, setRecursos] = useState([]);
  const [incidentes, setIncidentes] = useState([]);
  const [recursoId, setRecursoId] = useState("");
  const [incidenteId, setIncidenteId] = useState("");
  const [eta, setEta] = useState(null);
  const [cargandoDatos, setCargandoDatos] = useState(true);
  const [calculando, setCalculando] = useState(false);
  const [error, setError] = useState(null);
  const solicitudEta = useRef(0);

  useEffect(() => {
    let activa = true;
    Promise.all([api.get("/recursos"), api.get("/incidentes")])
      .then(([listaRecursos, listaIncidentes]) => {
        if (!activa) return;
        setRecursos(listaRecursos);
        setIncidentes(listaIncidentes.filter((incidente) => !["Resuelto", "Cancelado"].includes(incidente.estado)));
      })
      .catch((e) => {
        if (activa) setError(e.message);
      })
      .finally(() => {
        if (activa) setCargandoDatos(false);
      });
    return () => {
      activa = false;
      solicitudEta.current += 1;
    };
  }, []);

  const calcular = async () => {
    if (!recursoId || !incidenteId) return;
    const solicitud = ++solicitudEta.current;
    setCalculando(true);
    setEta(null);
    setError(null);
    try {
      const resultado = await api.get(`/eta/recursos/${recursoId}/incidentes/${incidenteId}`);
      if (solicitudEta.current === solicitud) setEta(resultado);
    } catch (e) {
      if (solicitudEta.current === solicitud) setError(e.message);
    } finally {
      if (solicitudEta.current === solicitud) setCalculando(false);
    }
  };

  const cambiarRecurso = (e) => {
    solicitudEta.current += 1;
    setCalculando(false);
    setRecursoId(e.target.value);
    setEta(null);
    setError(null);
  };

  const cambiarIncidente = (e) => {
    solicitudEta.current += 1;
    setCalculando(false);
    setIncidenteId(e.target.value);
    setEta(null);
    setError(null);
  };

  const incidenteSeleccionado = incidentes.find((incidente) => String(incidente.id) === incidenteId);
  const recursoSeleccionado = recursos.find((recurso) => String(recurso.id) === recursoId);

  const hijosMapa = eta?.ruta ? <RutaEtaEnMapa key={`${eta.recursoId}-${eta.incidenteId}`} ruta={eta.ruta} /> : null;

  return (
    <PaginaMapa etiqueta="Operaciones" titulo="ETA por ruta" etiquetaBoton="ETA" hijosMapa={hijosMapa}>
      <div className="panel__seccion">
        {error && <Aviso tipo="error">{error}</Aviso>}
        {cargandoDatos ? (
          <Aviso> Cargando recursos e incidentes…</Aviso>
        ) : (
          <>
            <label className="campo">
              <span className="campo__etiqueta">Incidente activo</span>
              <select value={incidenteId} onChange={cambiarIncidente} disabled={incidentes.length === 0}>
                <option value="">Elegí un incidente…</option>
                {incidentes.map((incidente) => (
                  <option key={incidente.id} value={incidente.id}>
                    {incidente.titulo} · {incidente.estado} · prioridad {incidente.prioridad}
                  </option>
                ))}
              </select>
            </label>
            <label className="campo">
              <span className="campo__etiqueta">Recurso</span>
              <select value={recursoId} onChange={cambiarRecurso} disabled={recursos.length === 0}>
                <option value="">Elegí un recurso…</option>
                {recursos.map((recurso) => (
                  <option key={recurso.id} value={recurso.id}>
                    {recurso.identificacion} · {nombreTipoRecurso(recurso.tipo)} · {recurso.estadoOperativo}
                  </option>
                ))}
              </select>
            </label>
            {incidentes.length === 0 && <Aviso>No hay incidentes activos para calcular.</Aviso>}
            {recursos.length === 0 && <Aviso>No hay recursos registrados.</Aviso>}
            <button
              type="button"
              className="btn btn--primario"
              onClick={calcular}
              disabled={!incidenteId || !recursoId || calculando}
            >
              {calculando ? "Calculando…" : "Calcular ETA"}
            </button>
          </>
        )}
        {eta && (
          <section className="bloque">
            <h3 className="bloque__titulo">Resultado</h3>
            <p className="ayuda">
              {recursoSeleccionado?.identificacion} → {incidenteSeleccionado?.titulo}
            </p>
            <dl className="datos">
              <div>
                <dt>Tiempo estimado</dt>
                <dd>{eta.tiempoEstimadoMinutos} min</dd>
              </div>
              <div>
                <dt>Distancia vial</dt>
                <dd>{numero.format(eta.distanciaMetros)} m</dd>
              </div>
              <div>
                <dt>Duración calculada</dt>
                <dd>{numero.format(eta.duracionSegundos)} s</dd>
              </div>
            </dl>
            <p className="ayuda">{eta.aclaracion}</p>
          </section>
        )}
      </div>
    </PaginaMapa>
  );
}