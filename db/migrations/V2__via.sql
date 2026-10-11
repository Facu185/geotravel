-- V2__via.sql
-- Red vial de Montevideo (ejes de calle del curso, v_sig_vias): capa de REFERENCIA, no se edita.
-- Sirve para ubicar una intersección de calles (consultas "búsqueda de incidente" y "búsqueda
-- de zona" por dirección). Cada fila es un tramo; una calle son varios tramos con el mismo nombre.
-- Los datos están en db/data/vias.sql.gz y los carga infra/init/seed.sh.

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE via (
    gid          serial PRIMARY KEY,
    nom_calle    varchar(36) NOT NULL,
    cod_depto    integer,
    cod_locali   double precision,
    gid_origen   numeric,
    cod_nombre   double precision,
    tipo         varchar(30),
    geom         geometry(LineString, 32721) NOT NULL
);

CREATE INDEX idx_via_geom ON via USING GIST (geom);
-- Busca el nombre mientras se escribe, en cualquier parte del texto (ILIKE '%18 de jul%').
CREATE INDEX idx_via_nombre_trgm ON via USING GIN (nom_calle gin_trgm_ops);
-- Une los tramos de una calle por nombre (ver /consultas/interseccion).
CREATE INDEX idx_via_nombre ON via (upper(nom_calle));
