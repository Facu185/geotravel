-- Prueba de carga para la carga a demanda (zona visible + zoom). NO es parte del seed.
--
-- Agrega en Salto 700 zonas (grilla de cuadrados que no se superponen) y 3000 recursos, todos
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
-- La grilla puede superponerse con zonas reales de Salto: la regla de no superposición la
-- controla la API, no la base. Borrar estos datos antes de cargar los definitivos.

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

-- Recursos: 3000 puntos al azar en el mismo rectángulo (semilla fija: siempre los mismos).
SELECT setseed(0.2026);
INSERT INTO recurso (identificacion, tipo, estado_operativo, geom)
SELECT 'PRUEBA-CARGA-' || g,
       (ARRAY['ambulancia', 'bomberos', 'patrulla', 'centro_atencion', 'otro'])[1 + g % 5],
       (ARRAY['Disponible', 'En servicio', 'Fuera de servicio'])[1 + g % 3],
       ST_Transform(ST_SetSRID(ST_MakePoint(-57.995 + random() * 0.07, -31.405 + random() * 0.04), 4326), 32721)
FROM generate_series(1, 3000) g;

COMMIT;

SELECT (SELECT count(*) FROM zona_operativa WHERE nombre LIKE 'PRUEBA-CARGA-%') AS zonas_prueba,
       (SELECT count(*) FROM recurso WHERE identificacion LIKE 'PRUEBA-CARGA-%') AS recursos_prueba;
