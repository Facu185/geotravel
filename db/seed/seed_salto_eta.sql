-- Escenario de demostracion ETA P2 en Salto, Uruguay.
-- Coordenadas lon/lat EPSG:4326, convertidas al SRID 32721 de PostGIS.
-- Idempotente: respeta los registros creados antes desde el frontend.
-- Los IDs son serial; NO tienen por que ser 5 en otra computadora.
BEGIN;

INSERT INTO recurso (identificacion, nombre, tipo, estado_operativo, descripcion, geom)
SELECT 'TEST-ETA-SALTO-01', 'Ambulancia de prueba Salto', 'ambulancia',
       'Disponible', 'Escenario reproducible ETA P2 en Salto',
       ST_Transform(ST_SetSRID(ST_MakePoint(-57.96215, -31.39029), 4326), 32721)
WHERE NOT EXISTS (
  SELECT 1 FROM recurso WHERE identificacion = 'TEST-ETA-SALTO-01'
);

INSERT INTO incidente (titulo, descripcion, tipo_incidente, prioridad, equipo_responsable, geom)
SELECT 'TEST ETA Salto', 'Incidente simulado para recorrer calles con OSRM',
       'accidente_transito', 3, 'Prueba P2',
       ST_Transform(ST_SetSRID(ST_MakePoint(-57.95340, -31.38927), 4326), 32721)
WHERE NOT EXISTS (
  SELECT 1 FROM incidente WHERE titulo = 'TEST ETA Salto'
);

COMMIT;
