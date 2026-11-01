-- Prueba de carga para la carga a demanda (zona visible + zoom). NO es parte del seed.
--
-- Agrega en Salto 700 zonas (grilla de cuadrados) y 3000 recursos sobre las calles, todos
-- con el prefijo "PRUEBA-CARGA-" para poder borrarlos después con carga-masiva-borrar.sql.
--
-- Uso (desde infra/):
--   docker compose exec -T db psql -U geotravel -d geotravel < ../db/pruebas/carga-masiva.sql
--
-- Qué mirar después en Zonas y Recursos:
--   - con Salto entero a la vista: "Mostrando 500 de N ... acercá el mapa"
--   - al alejarse por debajo del zoom mínimo: no se pide nada y dibuja GeoServer (WMS)
--   - en el navegador (Network) solo viajan los objetos del rectángulo visible
-- Si GeoServer no dibuja nada en Salto, recalcular la extensión de la capa: ver
-- docs/CARGA_POR_ZONA.md.
--
-- La grilla puede superponerse con zonas reales de Salto (las zonas pueden superponerse).
-- Borrar estos datos antes de cargar los definitivos.

BEGIN;

-- Zonas: 35 x 20 cuadrados de ~180 m con ~20 m de separación.
INSERT INTO zona_operativa (nombre, descripcion, nivel_prioridad, responsable, geom)
SELECT 'PRUEBA-CARGA-Z' || (i * 20 + j),
       'Zona generada para la prueba de carga',
       1 + (i + j) % 5,
       'Prueba de carga',
       ST_Transform(ST_MakeEnvelope(-57.995 + i * 0.002, -31.405 + j * 0.002,
                                    -57.995 + i * 0.002 + 0.0018, -31.405 + j * 0.002 + 0.0018, 4326), 32721)
FROM generate_series(0, 34) i, generate_series(0, 19) j;

-- Recursos: 3000 puntos repartidos por toda la ciudad a lo largo de sus calles (más donde hay más calles), solo en la
-- red de Salto: la tabla via también trae Concordia (Argentina), del otro lado del río. Semilla fija: siempre los mismos.
-- Necesita la tabla via cargada (la carga infra/init/seed.sh al levantar).
SELECT setseed(0.2026);
CREATE TEMP TABLE _calles_salto AS
WITH c AS (
    SELECT gid, geom, tipo, ST_ClusterDBSCAN(geom, 0, 1) OVER () AS red FROM via
)
SELECT gid, geom, sum(ST_Length(geom)) OVER (ORDER BY gid) AS acum
FROM c
WHERE red = (SELECT red FROM c ORDER BY geom <-> ST_Transform(ST_SetSRID(ST_MakePoint(-57.9606, -31.3857), 4326), 32721) LIMIT 1)
  AND tipo IN ('CALLE', 'AVENIDA');

INSERT INTO recurso (identificacion, tipo, estado_operativo, geom)
SELECT 'PRUEBA-CARGA-' || s.g,
       (ARRAY['ambulancia', 'bomberos', 'patrulla', 'centro_atencion', 'otro'])[1 + s.g % 5],
       (ARRAY['Disponible', 'En servicio', 'Fuera de servicio'])[1 + s.g % 3],
       ST_LineInterpolatePoint(c.geom, s.f)
FROM (SELECT g, random() * (SELECT max(acum) FROM _calles_salto) AS r, random() AS f FROM generate_series(1, 3000) g) s
CROSS JOIN LATERAL (SELECT geom FROM _calles_salto WHERE acum >= s.r ORDER BY acum LIMIT 1) c;

DROP TABLE _calles_salto;

COMMIT;

SELECT (SELECT count(*) FROM zona_operativa WHERE nombre LIKE 'PRUEBA-CARGA-%') AS zonas_prueba,
       (SELECT count(*) FROM recurso WHERE identificacion LIKE 'PRUEBA-CARGA-%') AS recursos_prueba;
