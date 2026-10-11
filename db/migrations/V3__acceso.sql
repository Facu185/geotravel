-- V3__acceso.sql
-- Números de puerta de Montevideo (capa mdg_accesos del WFS de la Intendencia de Montevideo,
-- con el nombre de la calle traído de v_mdg_vias_montevideo): capa de REFERENCIA, no se edita.
-- Sirve para ubicar una dirección "calle número" (consultas "búsqueda de incidente" y "búsqueda
-- de zona", ver /consultas/geocodificar). Cada fila es una puerta (un acceso a un padrón).
-- Los datos están en db/data/accesos.csv.gz y los carga infra/init/seed.sh.

CREATE TABLE acceso (
    id          serial PRIMARY KEY,
    num_puerta  integer NOT NULL,
    letra       varchar(5),
    nom_calle   varchar(60) NOT NULL,
    cod_nombre  integer,
    x           double precision NOT NULL,
    y           double precision NOT NULL,
    geom        geometry(Point, 32721) GENERATED ALWAYS AS (ST_SetSRID(ST_MakePoint(x, y), 32721)) STORED
);

CREATE INDEX idx_acceso_geom ON acceso USING GIST (geom);
-- Una puerta exacta: calle + número.
CREATE INDEX idx_acceso_calle_numero ON acceso (upper(nom_calle), num_puerta);
-- Calles escritas con errores o con el nombre incompleto (similitud por trigramas).
CREATE INDEX idx_acceso_nombre_trgm ON acceso USING GIN (upper(nom_calle) gin_trgm_ops);
