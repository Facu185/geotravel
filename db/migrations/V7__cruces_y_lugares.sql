-- V7: los cruces de calles de todo el país (ver /consultas/interseccion y docs/RED_VIAL.md).
--
--   * normalizar_calle(texto): el nombre de una calle en mayúsculas, sin tildes ni puntuación y con los espacios simples, para
--     comparar "Convención" con "CONVENCION" y "Gral. Rivera" con "GRAL RIVERA" (OpenStreetMap trae tildes y la gente no las escribe).
--   * red_vial_arco.nombre_norm: el nombre de cada tramo ya normalizado, con índices para buscar un cruce y para el autocompletado.
--   * lugar_osm: ciudades, pueblos y barrios de OpenStreetMap, para decir "cerca de X" cuando dos calles se cruzan en varios
--     lugares del país (la carga el servicio red-vial).

CREATE OR REPLACE FUNCTION public.normalizar_calle(texto text) RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
AS $$ SELECT btrim(regexp_replace(regexp_replace(translate(upper(texto), 'ÁÉÍÓÚÜÑÀÈÌÒÙ', 'AEIOUUNAEIOU'), '[^A-Z0-9 ]', ' ', 'g'), ' +', ' ', 'g')) $$;

ALTER TABLE public.red_vial_arco ADD COLUMN IF NOT EXISTS nombre_norm text;

CREATE INDEX IF NOT EXISTS idx_red_vial_arco_nombre_norm ON public.red_vial_arco (nombre_norm);
CREATE INDEX IF NOT EXISTS idx_red_vial_arco_nombre_trgm ON public.red_vial_arco USING GIN (nombre_norm gin_trgm_ops);

CREATE TABLE IF NOT EXISTS public.lugar_osm (
    id        serial PRIMARY KEY,
    nombre    text NOT NULL,
    tipo      text NOT NULL,                 -- city, town, village, hamlet, suburb, neighbourhood
    poblacion integer,
    lon       double precision NOT NULL,
    lat       double precision NOT NULL,
    geom      geometry(Point, 32721)
);

CREATE INDEX IF NOT EXISTS idx_lugar_osm_geom ON public.lugar_osm USING GIST (geom);
COMMENT ON TABLE public.lugar_osm IS 'Ciudades, pueblos y barrios de OpenStreetMap (nodos place=*), para ubicar los cruces de calles';
