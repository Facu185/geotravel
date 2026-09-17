-- V2__vista_recorrido_geom.sql
-- 'recorrido' no tiene geometría propia (ver README): se arma con la secuencia
-- ordenada de sus atracciones. Esta vista la materializa como LineString para
-- poder publicarla en GeoServer y colorearla por estado (ver geoserver/styles/recorridos_estado.sld).
--
-- Solo incluye recorridos con 2+ atracciones (una línea necesita al menos 2 puntos);
-- los recorridos de un solo punto se ven a través de la capa 'atraccion'.

CREATE OR REPLACE VIEW v_recorrido_geom AS
SELECT
    r.id,
    r.nombre,
    r.estado,
    r.tipo_experiencia,
    r.mes_inicio,
    r.mes_fin,
    ST_MakeLine(a.geom ORDER BY ra.orden) AS geom
FROM recorrido r
JOIN recorrido_atraccion ra ON ra.recorrido_id = r.id
JOIN atraccion a           ON a.id = ra.atraccion_id
GROUP BY r.id, r.nombre, r.estado, r.tipo_experiencia, r.mes_inicio, r.mes_fin
HAVING count(*) >= 2;
