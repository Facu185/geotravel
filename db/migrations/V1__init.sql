-- V1__init.sql — Sistema de Gestión Geográfica de Emergencias Urbanas (UrbanSafe).
-- Ver docs/diagramas/arquitectura.md para el modelo completo.
-- Aplicar con Flyway, o a mano: psql -d geotravel -f V1__init.sql

CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================================ zona_operativa
CREATE TABLE zona_operativa (
    id              serial PRIMARY KEY,
    nombre          text NOT NULL,
    descripcion     text,
    nivel_prioridad smallint NOT NULL CHECK (nivel_prioridad BETWEEN 1 AND 5), -- 1 = máxima prioridad
    responsable     text,
    observaciones   text,
    geom            geometry(Polygon, 32721) NOT NULL
);
CREATE INDEX idx_zona_operativa_geom ON zona_operativa USING GIST (geom);

-- Opcional "Control de superposición entre zonas operativas" (comentado, ver nota
-- al final del archivo: la validación equivalente ya se hace en el backend).
-- CREATE OR REPLACE FUNCTION fn_zona_sin_solapamiento() RETURNS trigger AS $$
-- BEGIN
--     IF EXISTS (
--         SELECT 1 FROM zona_operativa
--         WHERE id <> COALESCE(NEW.id, -1)
--           AND geom && NEW.geom
--           AND ST_Intersects(geom, NEW.geom) AND NOT ST_Touches(geom, NEW.geom)
--     ) THEN
--         RAISE EXCEPTION 'La zona se superpone con una zona existente';
--     END IF;
--     RETURN NEW;
-- END;
-- $$ LANGUAGE plpgsql;
-- CREATE TRIGGER trg_zona_sin_solapamiento
--     BEFORE INSERT OR UPDATE ON zona_operativa
--     FOR EACH ROW EXECUTE FUNCTION fn_zona_sin_solapamiento();

-- =================================================================== recurso
CREATE TABLE recurso (
    id               serial PRIMARY KEY,
    identificacion   text NOT NULL,                 -- ej. "Ambulancia 12", "Patrulla 305"
    nombre           text,
    tipo             text NOT NULL,                 -- ambulancia | bomberos | patrulla | centro_atencion | otro
    estado_operativo text NOT NULL DEFAULT 'Disponible'
                       CHECK (estado_operativo IN ('Disponible', 'En servicio', 'Fuera de servicio')),
    descripcion      text,
    geom             geometry(Point, 32721) NOT NULL
);
CREATE INDEX idx_recurso_geom ON recurso USING GIST (geom);

-- ================================================================= incidente
CREATE TABLE incidente (
    id                 serial PRIMARY KEY,
    titulo             text NOT NULL,
    descripcion        text,
    tipo_incidente     text NOT NULL,                -- accidente_transito | incendio | corte_servicio | inundacion | otro
    prioridad          smallint NOT NULL CHECK (prioridad BETWEEN 1 AND 5),
    estado             text NOT NULL DEFAULT 'Registrado'
                          CHECK (estado IN ('Registrado', 'En atención', 'Derivado', 'Resuelto', 'Cancelado')),
    fecha_hora_registro timestamp NOT NULL DEFAULT now(),
    equipo_responsable text,
    geom               geometry(Point, 32721) NOT NULL
);
CREATE INDEX idx_incidente_geom ON incidente USING GIST (geom);
CREATE INDEX idx_incidente_estado ON incidente (estado);
CREATE INDEX idx_incidente_fecha ON incidente (fecha_hora_registro);

-- ====================================================== incidente_recurso
-- Asignación de recursos a un incidente ("recursos que atendieron/atienden el incidente").
-- SUPUESTO a confirmar con el tutor: se modela como N a N (un incidente puede tener
-- varios recursos asignados y un recurso puede haber atendido varios incidentes en
-- distintos momentos), con la fecha de asignación. Si la letra espera algo más simple
-- (un único recurso por incidente), cambiar por una columna incidente.recurso_id.
CREATE TABLE incidente_recurso (
    incidente_id      integer NOT NULL REFERENCES incidente(id) ON DELETE CASCADE,
    recurso_id        integer NOT NULL REFERENCES recurso(id)   ON DELETE CASCADE,
    fecha_asignacion  timestamp NOT NULL DEFAULT now(),
    PRIMARY KEY (incidente_id, recurso_id)
);

-- ============================================================ historial_estado
CREATE TABLE historial_estado (
    id            serial PRIMARY KEY,
    incidente_id  integer NOT NULL REFERENCES incidente(id) ON DELETE CASCADE,
    estado        text NOT NULL,
    fecha_hora    timestamp NOT NULL DEFAULT now(),
    usuario       text                              -- quién hizo el cambio (no hay login real: texto libre)
);

-- Deja un primer registro de historial cuando se crea un incidente.
CREATE OR REPLACE FUNCTION fn_incidente_historial_inicial() RETURNS trigger AS $$
BEGIN
    INSERT INTO historial_estado (incidente_id, estado, usuario) VALUES (NEW.id, NEW.estado, 'sistema');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_incidente_historial_inicial
    AFTER INSERT ON incidente
    FOR EACH ROW EXECUTE FUNCTION fn_incidente_historial_inicial();

-- Nota sobre "no deben superponerse" (zonas operativas): la validación real se hace
-- en el backend (ZonaResource.java) con ST_Intersects + NOT ST_Touches, no con
-- ST_Overlaps -- ST_Overlaps no detecta una zona idéntica a otra ni una contenida
-- dentro de otra. El trigger de arriba (comentado) es la misma regla, por si se
-- prefiere reforzarla también a nivel de base de datos.
