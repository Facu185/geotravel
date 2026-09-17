-- V1__init.sql
-- Esquema inicial de GeoTravel. Ver docs/diagramas/arquitectura.md para el modelo completo.
-- Aplicar con Flyway, o a mano: psql -d geotravel -f V1__init.sql

CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE zona_turistica (
    id               serial PRIMARY KEY,
    nombre           text NOT NULL,
    descripcion      text,
    nivel_atractivo  smallint NOT NULL CHECK (nivel_atractivo BETWEEN 1 AND 5), -- 1 = mayor atractivo
    observaciones    text,
    geom             geometry(Polygon, 32721) NOT NULL
);
CREATE INDEX idx_zona_turistica_geom ON zona_turistica USING GIST (geom);

CREATE TABLE atraccion (
    id              serial PRIMARY KEY,
    nombre          text NOT NULL,
    descripcion     text,
    clasificacion   text NOT NULL,
    foto_url        text,
    geom            geometry(Point, 32721) NOT NULL
);
CREATE INDEX idx_atraccion_geom ON atraccion USING GIST (geom);

CREATE TABLE recorrido (
    id               serial PRIMARY KEY,
    nombre           text NOT NULL,
    descripcion      text,
    duracion_min     integer,
    guia_responsable text,
    tipo_experiencia text NOT NULL, -- cultural | gastronomica | natural | historica
    mes_inicio       smallint NOT NULL CHECK (mes_inicio BETWEEN 1 AND 12),
    mes_fin          smallint NOT NULL CHECK (mes_fin BETWEEN 1 AND 12),
    estado           text NOT NULL DEFAULT 'Pendiente'
                       CHECK (estado IN ('Pendiente', 'Disponible', 'Fuera de estacion', 'Cancelado'))
);

CREATE TABLE recorrido_atraccion (
    recorrido_id  integer NOT NULL REFERENCES recorrido(id) ON DELETE CASCADE,
    atraccion_id  integer NOT NULL REFERENCES atraccion(id) ON DELETE CASCADE,
    orden         smallint NOT NULL,
    PRIMARY KEY (recorrido_id, orden),
    UNIQUE (recorrido_id, atraccion_id)
);

CREATE TABLE historial_estado (
    id            serial PRIMARY KEY,
    recorrido_id  integer NOT NULL REFERENCES recorrido(id) ON DELETE CASCADE,
    estado        text NOT NULL,
    fecha_desde   timestamp NOT NULL DEFAULT now()
);

-- Deja un primer registro de historial cuando se crea un recorrido.
CREATE OR REPLACE FUNCTION fn_recorrido_historial_inicial() RETURNS trigger AS $$
BEGIN
    INSERT INTO historial_estado (recorrido_id, estado) VALUES (NEW.id, NEW.estado);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_recorrido_historial_inicial
    AFTER INSERT ON recorrido
    FOR EACH ROW EXECUTE FUNCTION fn_recorrido_historial_inicial();

-- Opcional "control de solapamiento de zonas" (dueño: P1, junto con P3):
-- descomentar cuando el ABM de zonas esté listo para depender de esta validación en DB
-- además de (o en lugar de) validarlo en el backend.
--
-- CREATE OR REPLACE FUNCTION fn_zona_sin_solapamiento() RETURNS trigger AS $$
-- BEGIN
--     IF EXISTS (
--         SELECT 1 FROM zona_turistica
--         WHERE id <> COALESCE(NEW.id, -1)
--           AND geom && NEW.geom
--           AND ST_Overlaps(geom, NEW.geom)
--     ) THEN
--         RAISE EXCEPTION 'La zona se superpone con una zona existente';
--     END IF;
--     RETURN NEW;
-- END;
-- $$ LANGUAGE plpgsql;
--
-- CREATE TRIGGER trg_zona_sin_solapamiento
--     BEFORE INSERT OR UPDATE ON zona_turistica
--     FOR EACH ROW EXECUTE FUNCTION fn_zona_sin_solapamiento();
