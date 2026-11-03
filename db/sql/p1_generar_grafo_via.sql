-- p1_generar_grafo_via.sql
-- Genera el grafo vial de Salto desde la tabla via existente
-- Usa solo PostGIS (no requiere pgRouting instalado)

BEGIN;

-- Paso 1: Extraer todos los puntos únicos de inicio y fin de los tramos
-- Estos serán los vértices del grafo
WITH puntos AS (
    SELECT ST_StartPoint(geom) as geom FROM via
    UNION
    SELECT ST_EndPoint(geom) as geom FROM via
),
vertices_temp AS (
    SELECT ROW_NUMBER() OVER (ORDER BY geom) as id, geom
    FROM puntos
)
INSERT INTO red_vial_vertice (id, geom)
SELECT id, geom FROM vertices_temp
ON CONFLICT (id) DO NOTHING;

-- Paso 2: Agregar columnas temporales a via para source/target
ALTER TABLE via ADD COLUMN IF NOT EXISTS source_temp bigint;
ALTER TABLE via ADD COLUMN IF NOT EXISTS target_temp bigint;

-- Paso 3: Asignar source y target basándose en los puntos más cercanos
UPDATE via v
SET source_temp = vv.id
FROM red_vial_vertice vv
WHERE ST_Equals(ST_StartPoint(v.geom), vv.geom);

UPDATE via v
SET target_temp = vv.id
FROM red_vial_vertice vv
WHERE ST_Equals(ST_EndPoint(v.geom), vv.geom);

-- Paso 4: Calcular costos de distancia (metros)
ALTER TABLE via ADD COLUMN IF NOT EXISTS cost_m double precision;
ALTER TABLE via ADD COLUMN IF NOT EXISTS reverse_cost_m double precision;
UPDATE via SET cost_m = ST_Length(geom);
UPDATE via SET reverse_cost_m = ST_Length(geom); -- Bidireccional por defecto

-- Paso 5: Calcular costos de tiempo (segundos)
-- Asignar velocidades por tipo de calle
ALTER TABLE via ADD COLUMN IF NOT EXISTS velocidad_kmh double precision;
ALTER TABLE via ADD COLUMN IF NOT EXISTS cost_s double precision;
ALTER TABLE via ADD COLUMN IF NOT EXISTS reverse_cost_s double precision;

UPDATE via SET velocidad_kmh = 50 WHERE tipo = 'avenida';
UPDATE via SET velocidad_kmh = 40 WHERE tipo = 'calle';
UPDATE via SET velocidad_kmh = 30 WHERE tipo IS NULL OR velocidad_kmh IS NULL;
UPDATE via SET velocidad_kmh = 60 WHERE tipo LIKE '%ruta%';
-- Valor por defecto para evitar NULL
UPDATE via SET velocidad_kmh = 30 WHERE velocidad_kmh IS NULL OR velocidad_kmh = 0;

-- Calcular tiempo: (distancia_km / velocidad_kmh) * 3600 = segundos
UPDATE via SET cost_s = (cost_m / 1000.0) / (velocidad_kmh / 3600.0);
UPDATE via SET reverse_cost_s = cost_s; -- Bidireccional por defecto

-- Paso 6: Insertar arcos en red_vial_arco
INSERT INTO red_vial_arco (id, source, target, geom, cost_m, reverse_cost_m, cost_s, reverse_cost_s)
SELECT gid, source_temp, target_temp, geom, cost_m, reverse_cost_m, cost_s, reverse_cost_s
FROM via
ON CONFLICT (id) DO NOTHING;

-- Paso 7: Limpiar columnas temporales
ALTER TABLE via DROP COLUMN IF EXISTS source_temp;
ALTER TABLE via DROP COLUMN IF EXISTS target_temp;

COMMIT;

-- Verificación
SELECT 'Vértices:' as tipo, COUNT(*) as cantidad FROM red_vial_vertice
UNION ALL
SELECT 'Arcos:', COUNT(*) FROM red_vial_arco;
