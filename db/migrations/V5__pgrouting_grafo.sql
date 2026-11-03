-- V5__pgrouting_grafo.sql
-- Migración para crear la estructura del grafo vial de Salto
-- Esta migración crea las tablas requeridas por el contrato de pgRouting

BEGIN;

-- Intentar instalar extensión pgRouting si está disponible
-- Si no está disponible, las tablas se crean de todas formas
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'pgrouting') THEN
        CREATE EXTENSION IF NOT EXISTS pgrouting;
        RAISE NOTICE 'pgRouting instalado correctamente';
    ELSE
        RAISE NOTICE 'pgRouting no está disponible en esta imagen. Las tablas se crearán de todas formas.';
    END IF;
END $$;

-- Verificar que PostGIS está instalado (debería estar por V1__init.sql)
SELECT postgis_version() AS postgis_version;

-- Crear tabla de vértices (nodos) del grafo vial
CREATE TABLE IF NOT EXISTS public.red_vial_vertice (
    id bigint PRIMARY KEY,
    geom geometry(Point,32721) NOT NULL
);

-- Crear tabla de arcos (aristas) del grafo vial
CREATE TABLE IF NOT EXISTS public.red_vial_arco (
    id bigint PRIMARY KEY,
    source bigint NOT NULL REFERENCES public.red_vial_vertice(id),
    target bigint NOT NULL REFERENCES public.red_vial_vertice(id),
    geom geometry(LineString,32721) NOT NULL,
    cost_m double precision NOT NULL,
    reverse_cost_m double precision NOT NULL,
    cost_s double precision NOT NULL,
    reverse_cost_s double precision NOT NULL
);

-- Índices espaciales para búsquedas rápidas
CREATE INDEX IF NOT EXISTS idx_red_vial_vertice_geom ON public.red_vial_vertice USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_red_vial_arco_geom ON public.red_vial_arco USING GIST (geom);

-- Índices para pgRouting (requeridos por pgr_dijkstra)
CREATE INDEX IF NOT EXISTS idx_red_vial_arco_source ON public.red_vial_arco (source);
CREATE INDEX IF NOT EXISTS idx_red_vial_arco_target ON public.red_vial_arco (target);

-- Comentario sobre las tablas
COMMENT ON TABLE public.red_vial_vertice IS 'Vértices del grafo vial de Salto para pgRouting (EPSG:32721)';
COMMENT ON TABLE public.red_vial_arco IS 'Arcos del grafo vial de Salto para pgRouting con costos de distancia y tiempo';

COMMIT;
