-- p1_generar_grafo_via.sql
-- Genera el grafo vial de Salto para pgRouting a partir de la tabla via. Usa solo PostGIS.
--
-- Por qué hay que cortar las calles: cada fila de via es una calle de OpenStreetMap entera, que puede cruzar muchas
-- esquinas sin terminar en ellas. Si cada fila fuera un arco, dos calles solo quedarían conectadas cuando una
-- termina justo donde empieza la otra, y casi ninguna ruta tendría solución. Acá se parte cada calle en cada cruce
-- (ST_Node), de modo que cada arco va de esquina a esquina.
--
-- Qué entra en el grafo:
--   * solo calles por donde pasa un auto: se dejan afuera las sendas peatonales y las calles proyectadas;
--   * solo la red de Salto: la tabla también trae Concordia (Argentina), del otro lado del río, y los tramos
--     sueltos que no se conectan con el centro de Salto no sirven para rutear;
--   * velocidades por tipo de vía (AVENIDA 50 km/h, RUTA NACIONAL 60, CALLE 40, CAMINO 30), que son las que hacen
--     que "más rápida" no sea lo mismo que "más corta".
-- Limitaciones: la tabla via no trae sentidos de circulación, así que todas las calles son de doble mano, y no se
-- modelan giros prohibidos.
--
-- Se puede volver a ejecutar: vacía el grafo y lo regenera.

BEGIN;

TRUNCATE red_vial_arco, red_vial_vertice;

-- Paso 1: calles transitables por vehículos.
CREATE TEMP TABLE _via_auto ON COMMIT DROP AS
SELECT gid, tipo, geom FROM via
WHERE tipo IS DISTINCT FROM 'PEATONAL' AND tipo IS DISTINCT FROM 'PROYECTADA';

-- Paso 2: partir todas las calles en cada cruce (el resultado son tramos de esquina a esquina).
CREATE TEMP TABLE _tramos ON COMMIT DROP AS
SELECT row_number() OVER () AS id, d.geom AS geom
FROM (SELECT (ST_Dump(ST_Node(ST_Collect(geom)))).geom AS geom FROM _via_auto) d
WHERE ST_GeometryType(d.geom) = 'ST_LineString' AND ST_Length(d.geom) > 0.01;

-- Paso 3: quedarse con la red conectada con el centro de Salto (dos tramos están conectados si se tocan).
CREATE TEMP TABLE _tramos_red ON COMMIT DROP AS
WITH c AS (
    SELECT id, geom, ST_ClusterDBSCAN(geom, 0, 1) OVER () AS red FROM _tramos
)
SELECT id, geom FROM c
WHERE red = (SELECT red FROM c
             ORDER BY geom <-> ST_Transform(ST_SetSRID(ST_MakePoint(-57.9606, -31.3857), 4326), 32721)
             LIMIT 1);

-- Paso 4: vértices = las esquinas (extremos de los tramos).
INSERT INTO red_vial_vertice (id, geom)
SELECT row_number() OVER (ORDER BY geom), geom
FROM (SELECT ST_StartPoint(geom) AS geom FROM _tramos_red
      UNION
      SELECT ST_EndPoint(geom) FROM _tramos_red) p;

-- Paso 5: arcos, con su tipo de vía (el de la calle original más cercana al medio del tramo), distancia en metros
-- y tiempo en segundos. Sin datos de sentido único, los dos sentidos cuestan lo mismo.
INSERT INTO red_vial_arco (id, source, target, geom, cost_m, reverse_cost_m, cost_s, reverse_cost_s)
SELECT t.id, s.id, e.id, t.geom, ST_Length(t.geom), ST_Length(t.geom),
       ST_Length(t.geom) / (v.kmh / 3.6), ST_Length(t.geom) / (v.kmh / 3.6)
FROM _tramos_red t
JOIN red_vial_vertice s ON s.geom = ST_StartPoint(t.geom)
JOIN red_vial_vertice e ON e.geom = ST_EndPoint(t.geom)
CROSS JOIN LATERAL (
    SELECT CASE a.tipo WHEN 'AVENIDA' THEN 50.0
                       WHEN 'RUTA NACIONAL' THEN 60.0
                       WHEN 'CAMINO' THEN 30.0
                       ELSE 40.0 END AS kmh
    FROM _via_auto a
    ORDER BY a.geom <-> ST_LineInterpolatePoint(t.geom, 0.5)
    LIMIT 1
) v;

ANALYZE red_vial_vertice;
ANALYZE red_vial_arco;

COMMIT;

-- Verificación
SELECT 'Vértices:' AS tipo, COUNT(*) AS cantidad FROM red_vial_vertice
UNION ALL
SELECT 'Arcos:', COUNT(*) FROM red_vial_arco;
