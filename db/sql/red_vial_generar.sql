-- red_vial_generar.sql: arma el grafo de pgRouting a partir de los arcos de OpenStreetMap.
--
-- Espera la tabla red_vial_carga, que carga infra/red-vial/cargar.sh con el CSV que produce red_vial_osm.py
-- (un arco por fila, de esquina a esquina, con geometría en WKT lon/lat). Se puede volver a ejecutar:
-- vacía el grafo y lo regenera.
--
-- Qué se calcula:
--   * Sentido: una vía de mano única va de source a target y la vuelta queda prohibida (costo negativo, que es
--     la convención de pgRouting). Si el CSV dice "inverso" se da vuelta el trazado, así todas quedan source -> target.
--   * Costo en metros: el largo del arco. Costo en segundos: largo / velocidad + una demora fija por esquina.
--   * Velocidad: la maxspeed de OpenStreetMap si la tiene; si no, un valor por tipo de vía (tabla de abajo).
--   * Redes conectadas: se marcan los arcos que forman una red de 50 arcos o más; los extremos de una ruta se ajustan solo
--     a esas (así un punto no se engancha a una calle aislada, a la que no llega nadie).

BEGIN;

TRUNCATE red_vial_arco, red_vial_vertice;

CREATE TEMP TABLE _arco ON COMMIT DROP AS
SELECT c.osm_way_id,
       CASE WHEN c.sentido = 'inverso' THEN c.destino ELSE c.origen END AS source,
       CASE WHEN c.sentido = 'inverso' THEN c.origen ELSE c.destino END AS target,
       CASE WHEN c.sentido = 'inverso' THEN ST_Reverse(c.g) ELSE c.g END AS geom,
       NULLIF(c.nombre, '') AS nombre, NULLIF(c.referencia, '') AS referencia, c.highway,
       c.velocidad_kmh, c.sentido <> 'doble' AS mano_unica
FROM (SELECT *, ST_Transform(ST_SetSRID(ST_GeomFromText(wkt), 4326), 32721) AS g FROM red_vial_carga) c
WHERE c.origen <> c.destino OR c.wkt LIKE '%,%,%';

DELETE FROM _arco WHERE ST_Length(geom) < 0.01;

-- Vértices: las esquinas (extremos de los arcos).
INSERT INTO red_vial_vertice (id, geom)
SELECT DISTINCT ON (id) id, geom
FROM (SELECT source AS id, ST_StartPoint(geom) AS geom FROM _arco
      UNION ALL
      SELECT target, ST_EndPoint(geom) FROM _arco) v
ORDER BY id;

-- Arcos con sus costos.
INSERT INTO red_vial_arco (id, source, target, geom, cost_m, reverse_cost_m, cost_s, reverse_cost_s,
                           osm_way_id, nombre, nombre_norm, referencia, highway, velocidad_kmh, mano_unica)
SELECT row_number() OVER (ORDER BY osm_way_id, source, target), source, target, geom,
       ST_Length(geom),
       CASE WHEN mano_unica THEN -1 ELSE ST_Length(geom) END,
       ST_Length(geom) / (v.kmh / 3.6) + 3,
       CASE WHEN mano_unica THEN -1 ELSE ST_Length(geom) / (v.kmh / 3.6) + 3 END,
       osm_way_id, nombre, public.normalizar_calle(nombre), referencia, highway, v.kmh::integer, mano_unica
FROM _arco a
CROSS JOIN LATERAL (
    SELECT COALESCE(a.velocidad_kmh,
                    CASE a.highway
                        WHEN 'motorway' THEN 90 WHEN 'motorway_link' THEN 60
                        WHEN 'trunk' THEN 90 WHEN 'trunk_link' THEN 60
                        WHEN 'primary' THEN 70 WHEN 'primary_link' THEN 50
                        WHEN 'secondary' THEN 55 WHEN 'secondary_link' THEN 40
                        WHEN 'tertiary' THEN 45 WHEN 'tertiary_link' THEN 35
                        WHEN 'living_street' THEN 20 WHEN 'service' THEN 20
                        ELSE 40 END)::double precision AS kmh
) v;

-- Redes conectadas.
UPDATE red_vial_arco a
SET componente = c.component
FROM pgr_connectedComponents('SELECT id, source, target, 1.0::float8 AS cost, 1.0::float8 AS reverse_cost FROM red_vial_arco') c
WHERE c.node = a.source;

UPDATE red_vial_arco a
SET componente_grande = true
WHERE a.componente IN (SELECT componente FROM red_vial_arco GROUP BY componente HAVING count(*) >= 50);

ANALYZE red_vial_vertice;
ANALYZE red_vial_arco;

COMMIT;

SELECT 'Vértices' AS dato, count(*) AS cantidad FROM red_vial_vertice
UNION ALL SELECT 'Arcos', count(*) FROM red_vial_arco
UNION ALL SELECT 'Arcos de mano única', count(*) FROM red_vial_arco WHERE mano_unica
UNION ALL SELECT 'Arcos en redes grandes', count(*) FROM red_vial_arco WHERE componente_grande
UNION ALL SELECT 'Redes conectadas', count(DISTINCT componente) FROM red_vial_arco;
