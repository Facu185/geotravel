import { useCallback, useEffect, useState } from "react";
import { Aviso } from "../../components/ui.jsx";
import { api } from "../../api/client.js";

/**
 * Módulo Consultas geográficas y reportes (dueño: P5).
 *
 * Cada consulta es una tarjeta que se ejecuta sola al abrir la página y se puede volver a
 * correr con "Actualizar". Los cálculos los hace PostGIS en el backend (ver
 * backend/.../consultas/ConsultaResource.java); acá solo se muestran.
 *
 * TODO (P5): faltan en pantalla las consultas que ya existen en la API --
 * incidentes por zona y recursos por zona (con la zona elegida en el mapa), recursos
 * cercanos a un incidente, incidente/zona más cercanos a una dirección o intersección,
 * incidentes por recurso, el reporte filtrable, y el rango de fechas de "zonas con más
 * incidentes" -- ver docs/api/openapi.yaml.
 */

/** Ejecuta una consulta GET y guarda su estado: cargando / ok / error. */
function useConsulta(ruta) {
  const [estado, setEstado] = useState({ fase: "cargando", datos: [], error: null });

  const ejecutar = useCallback(() => {
    setEstado((anterior) => ({ ...anterior, fase: "cargando", error: null }));
    api
      .get(ruta)
      .then((datos) => setEstado({ fase: "ok", datos, error: null }))
      .catch((e) => setEstado((anterior) => ({ ...anterior, fase: "error", error: e.message })));
  }, [ruta]);

  useEffect(() => {
    ejecutar();
  }, [ejecutar]);

  return { ...estado, ejecutar };
}

/** Ranking de zonas: una barra por zona, proporcional a su valor, con el mayor primero. */
function TarjetaRanking({ titulo, descripcion, ruta, campo, unidad, nota }) {
  const { fase, datos, error, ejecutar } = useConsulta(ruta);
  const maximo = Math.max(0, ...datos.map((d) => Number(d[campo])));

  return (
    <article className="tarjeta">
      <header className="tarjeta__cabecera">
        <div>
          <h3 className="tarjeta__titulo">{titulo}</h3>
          <p className="tarjeta__descripcion">{descripcion}</p>
        </div>
        <button type="button" className="btn btn--secundario" onClick={ejecutar} disabled={fase === "cargando"}>
          {fase === "cargando" ? "Calculando…" : "Actualizar"}
        </button>
      </header>

      {fase === "error" && <Aviso tipo="error">{error}</Aviso>}

      {fase === "cargando" && datos.length === 0 && (
        <ul className="ranking ranking--cargando" aria-label="Cargando resultados">
          {[0, 1, 2].map((i) => (
            <li key={i} className="ranking__fila">
              <span className="ranking__esqueleto" />
            </li>
          ))}
        </ul>
      )}

      {datos.length > 0 && (
        <ol className="ranking">
          {datos.map((d, i) => {
            const valor = Number(d[campo]);
            const porcentaje = maximo > 0 ? Math.max((valor / maximo) * 100, valor > 0 ? 3 : 0) : 0;
            return (
              <li key={d.id} className={i === 0 && valor > 0 ? "ranking__fila ranking__fila--primero" : "ranking__fila"}>
                <span className="ranking__nombre">{d.nombre}</span>
                <span className="ranking__barra" aria-hidden="true">
                  <span style={{ width: `${porcentaje}%` }} />
                </span>
                <span className="ranking__valor">
                  {valor}
                  <small>{Array.isArray(unidad) ? ` ${valor === 1 ? unidad[0] : unidad[1]}` : unidad}</small>
                </span>
              </li>
            );
          })}
        </ol>
      )}

      {fase === "ok" && datos.length === 0 && <p className="vacio">No hay datos para mostrar.</p>}

      <p className="tarjeta__nota">{nota}</p>
    </article>
  );
}

export default function ConsultasPage() {
  return (
    <>
      <header className="pagina__cabecera">
        <p className="pagina__etiqueta">Análisis espacial</p>
        <h2 className="pagina__titulo">Consultas geográficas</h2>
        <p className="pagina__intro">Resultados calculados por PostGIS sobre los datos actuales de la base.</p>
      </header>

      <div className="tarjetas">
        <TarjetaRanking
          titulo="Zonas con más incidentes"
          descripcion="Cantidad de incidentes que cayeron dentro de cada zona operativa."
          ruta="/consultas/zonas-mas-incidentes"
          campo="cantidadIncidentes"
          unidad={["incidente", "incidentes"]}
          nota="ST_Contains + COUNT, agrupado por zona"
        />
        <TarjetaRanking
          titulo="Zonas con mayor concentración"
          descripcion="Incidentes por kilómetro cuadrado: una zona chica con pocos incidentes puede estar más cargada que una grande."
          ruta="/consultas/zonas-mayor-concentracion"
          campo="incidentesPorKm2"
          unidad=" / km²"
          nota="ST_Contains + ST_Area, normalizado por superficie"
        />
      </div>
    </>
  );
}
