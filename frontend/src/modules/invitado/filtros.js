/**
 * Filtros del mapa público. Se traducen a CQL_FILTER de GeoServer y se aplican igual al mapa
 * (WMS), a los conteos (WFS) y al detalle (GetFeatureInfo): filtra GeoServer, no datos que el
 * navegador tenga en memoria. Las zonas no tienen filtros (solo se consulta su información).
 */

export const FILTROS_VACIOS = {
  incidentes: { tipo: "", estado: "", prioridad: "", desde: "", hasta: "" },
  recursos: { tipo: "", estado: "" },
};

/** Literal de texto para CQL: entre comillas simples, duplicando las que haya adentro. */
const texto = (valor) => `'${String(valor).replace(/'/g, "''")}'`;

/** Medianoche (hora local) del día "AAAA-MM-DD", sumando n días, como instante en UTC. */
const inicioDelDia = (fecha, sumarDias = 0) => {
  const [a, m, d] = fecha.split("-").map(Number);
  return new Date(a, m - 1, d + sumarDias).toISOString().replace(/\.\d{3}Z$/, "Z");
};

const CLAUSULAS = {
  incidentes: (f) => [
    f.tipo && `tipo_incidente = ${texto(f.tipo)}`,
    f.estado && `estado = ${texto(f.estado)}`,
    f.prioridad && `prioridad = ${Number(f.prioridad)}`,
    f.desde && `fecha_hora_registro >= '${inicioDelDia(f.desde)}'`,
    // "hasta" incluye el día completo: se filtra por "antes de la medianoche siguiente".
    f.hasta && `fecha_hora_registro < '${inicioDelDia(f.hasta, 1)}'`,
  ],
  recursos: (f) => [f.tipo && `tipo = ${texto(f.tipo)}`, f.estado && `estado_operativo = ${texto(f.estado)}`],
};

/** Filtro CQL de una capa ("INCLUDE" = sin filtro). */
export function cqlDeCapa(capaId, filtros) {
  const clausulas = (CLAUSULAS[capaId]?.(filtros[capaId]) ?? []).filter(Boolean);
  return clausulas.length ? clausulas.join(" AND ") : "INCLUDE";
}

/**
 * CQL_FILTER para un pedido con varias capas: uno por capa, separados por ";" y en el mismo
 * orden que las capas. Si ninguna tiene filtro devuelve "" (no hace falta mandar el parámetro).
 */
export function cqlParaCapas(capasVisibles, filtros) {
  const filtrosPorCapa = capasVisibles.map((c) => cqlDeCapa(c.id, filtros));
  return filtrosPorCapa.every((f) => f === "INCLUDE") ? "" : filtrosPorCapa.join(";");
}
