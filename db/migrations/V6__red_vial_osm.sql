-- V6: la red vial pasa a salir de OpenStreetMap completo (ver infra/red-vial y db/sql/red_vial_generar.sql).
-- Cada arco guarda ahora de qué calle es, su tipo, su velocidad, si es de mano única y a qué red conectada pertenece.
-- Se puede repetir sin problema (IF NOT EXISTS).

ALTER TABLE public.red_vial_arco
    ADD COLUMN IF NOT EXISTS osm_way_id        bigint,
    ADD COLUMN IF NOT EXISTS nombre            text,
    ADD COLUMN IF NOT EXISTS referencia        text,
    ADD COLUMN IF NOT EXISTS highway           text,
    ADD COLUMN IF NOT EXISTS velocidad_kmh     integer,
    ADD COLUMN IF NOT EXISTS mano_unica        boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS componente        bigint,
    ADD COLUMN IF NOT EXISTS componente_grande boolean NOT NULL DEFAULT false;

-- V5 los describió como la red de Salto (y no se edita una migración ya aplicada): desde acá son de todo Uruguay.
COMMENT ON TABLE public.red_vial_vertice IS 'Vértices (esquinas) de la red vial de OpenStreetMap de todo Uruguay para pgRouting (EPSG:32721)';
COMMENT ON TABLE public.red_vial_arco IS 'Arcos (tramos de calle de esquina a esquina) de la red vial de OpenStreetMap de todo Uruguay, con sentido, velocidad y costo en metros y segundos';

COMMENT ON COLUMN public.red_vial_arco.mano_unica IS 'true: solo se puede circular de source a target (reverse_cost negativo)';
COMMENT ON COLUMN public.red_vial_arco.componente IS 'Red conectada a la que pertenece el arco (pgr_connectedComponents)';
COMMENT ON COLUMN public.red_vial_arco.componente_grande IS 'La red conectada tiene 50 arcos o más: solo a ellas se ajustan los extremos de una ruta';

-- Para ajustar un punto a la calle más cercana sin mirar las islas de la red.
CREATE INDEX IF NOT EXISTS idx_red_vial_arco_grande_geom ON public.red_vial_arco USING GIST (geom) WHERE componente_grande;
