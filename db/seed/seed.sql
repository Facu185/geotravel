-- seed.sql — datos de prueba para Salto: unos pocos hechos a mano y, al final, un conjunto más grande
-- (zonas, recursos e incidentes de todos los tipos y formas) para recorrer las consultas, en Salto y en Montevideo.
-- Las geometrías se definen en lon/lat (EPSG:4326, coordenadas reales de Salto) y se
-- transforman a EPSG:32721, el SRID que usa la base.
-- Ejecutar después de la migración V1. 

-- Zonas operativas: rectángulos que no se superponen entre sí en Salto
INSERT INTO zona_operativa (nombre, descripcion, nivel_prioridad, responsable, observaciones, geom) VALUES
('Centro Salto', 'Zona operativa del centro de Salto', 1, 'Equipo Salto Centro', 'Alta circulación comercial',
 ST_Transform(ST_MakeEnvelope(-57.9700, -31.3900, -57.9550, -31.3800, 4326), 32721)),
('Cerro', 'Zona operativa del barrio El Cerro', 2, 'Equipo Cerro', NULL,
 ST_Transform(ST_MakeEnvelope(-57.9850, -31.4050, -57.9720, -31.3920, 4326), 32721)),
('Salto Nuevo', 'Zona operativa sur Salto Nuevo', 3, 'Equipo Sur', NULL,
 ST_Transform(ST_MakeEnvelope(-57.9650, -31.4200, -57.9500, -31.4080, 4326), 32721));

-- Recursos (ambulancias, bomberos, patrullas) con formato clásico y ubicados en Salto
INSERT INTO recurso (identificacion, nombre, tipo, estado_operativo, descripcion, geom) VALUES
('AMB-12', 'Ambulancia 12',      'ambulancia',      'Disponible',      'Base Centro Salto',
 ST_Transform(ST_SetSRID(ST_MakePoint(-57.9620, -31.3850), 4326), 32721)),
('BOM-05', 'Bomberos 05',        'bomberos',        'En servicio',     'Cuartel Salto',
 ST_Transform(ST_SetSRID(ST_MakePoint(-57.9780, -31.3980), 4326), 32721)),
('PAT-305','Patrulla 305',       'patrulla',        'Disponible',      'Recorrida Cerro',
 ST_Transform(ST_SetSRID(ST_MakePoint(-57.9580, -31.4120), 4326), 32721)),
('CAT-01', 'Centro de Atención', 'centro_atencion', 'Disponible',      'Hospital Regional Salto',
 ST_Transform(ST_SetSRID(ST_MakePoint(-57.9600, -31.3830), 4326), 32721));

-- Incidentes en Salto con lenguaje natural local
INSERT INTO incidente (titulo, descripcion, tipo_incidente, prioridad, equipo_responsable, geom) VALUES
('Choque en Av. Uruguay', 'Accidente de tránsito en avenida principal', 'accidente_transito', 1, 'Equipo Salto Centro',
 ST_Transform(ST_SetSRID(ST_MakePoint(-57.9610, -31.3845), 4326), 32721)),
('Fuego en comercio', 'Incendio en local comercial', 'incendio', 1, 'Equipo Salto Centro',
 ST_Transform(ST_SetSRID(ST_MakePoint(-57.9635, -31.3860), 4326), 32721)),
('Falta de luz', 'Corte en red eléctrica de El Cerro', 'corte_servicio', 3, 'Equipo Cerro',
 ST_Transform(ST_SetSRID(ST_MakePoint(-57.9800, -31.4000), 4326), 32721)),
('Inundación en zona baja', 'Acumulación de agua tras la lluvia en Salto Nuevo', 'inundacion', 2, 'Equipo Sur',
 ST_Transform(ST_SetSRID(ST_MakePoint(-57.9570, -31.4100), 4326), 32721));

-- Asignación de recursos a incidentes (incidente_recurso)
INSERT INTO incidente_recurso (incidente_id, recurso_id) VALUES
(1, 1),           -- Choque en Av. Uruguay -> Ambulancia 12
(2, 2),           -- Fuego en comercio -> Bomberos 05
(3, 3),           -- Falta de luz -> Patrulla 305
(4, 3);           -- Inundación en zona baja -> Patrulla 305 (ya resuelto)

-- Avances de estado simulados:
-- Incidente 1: Registrado -> En atención
UPDATE incidente SET estado = 'En atención' WHERE id = 1;
INSERT INTO historial_estado (incidente_id, estado, fecha_hora, usuario)
VALUES (1, 'En atención', now() + interval '1 minute', 'ana.rios');

-- Incidente 3: Registrado -> Derivado
UPDATE incidente SET estado = 'Derivado' WHERE id = 3;
INSERT INTO historial_estado (incidente_id, estado, fecha_hora, usuario)
VALUES (3, 'Derivado', now() + interval '1 minute', 'bruno.silva');

-- Incidente 4: Registrado -> En atención -> Resuelto
-- Timestamps explícitos: dos filas en el mismo INSERT comparten el now() de la
-- transacción, así que sin esto no se podría saber cuál fue la más reciente.
UPDATE incidente SET estado = 'Resuelto' WHERE id = 4;
INSERT INTO historial_estado (incidente_id, estado, fecha_hora, usuario) VALUES
(4, 'En atención', now() + interval '1 minute', 'carla.nunez'),
(4, 'Resuelto',    now() + interval '2 minutes', 'carla.nunez');

-- =====================================================================================================
-- Conjunto grande para recorrer las consultas: 23 zonas, 60 recursos y 152 incidentes de Salto, con
-- puntos, líneas (calles cortadas, sobre las calles reales de la tabla via) y polígonos (áreas
-- inundadas), de todos los estados, tipos y prioridades, con recursos asignados e historial de estados.
-- Es determinista (semilla fija). Va después de la carga de la red vial (seed.sh la carga antes).
-- =====================================================================================================
SELECT setseed(0.2027);

CREATE TEMP TABLE _gen_incidente (id integer PRIMARY KEY);
CREATE TEMP TABLE _gen_recurso (id integer PRIMARY KEY);

-- Zonas: grilla de 7 x 5 celdas de ~950 x 890 m sobre Salto, salvo las que tocan una zona de arriba.
INSERT INTO zona_operativa (nombre, descripcion, nivel_prioridad, responsable, geom)
SELECT 'Zona ' || chr(65 + j) || (i + 1),
       'Zona operativa de Salto',
       1 + (i * 3 + j * 2) % 5,
       'Equipo ' || (1 + (i + j) % 4),
       celda
FROM (
    SELECT i, j,
           ST_Transform(ST_MakeEnvelope(-57.995 + i * 0.01, -31.405 + j * 0.008,
                                        -57.995 + i * 0.01 + 0.0094, -31.405 + j * 0.008 + 0.0076, 4326), 32721) AS celda
    FROM generate_series(0, 6) i, generate_series(0, 4) j
) celdas
WHERE NOT EXISTS (SELECT 1 FROM zona_operativa z WHERE z.geom && celda AND ST_Intersects(z.geom, celda));

-- Recursos: 60 puntos al azar sobre Salto, de todos los tipos y estados.
WITH nuevos AS (
    INSERT INTO recurso (identificacion, nombre, tipo, estado_operativo, descripcion, geom)
    SELECT upper(left(tipo, 3)) || '-' || lpad(g::text, 3, '0'),
           initcap(replace(tipo, '_', ' ')) || ' ' || g,
           tipo,
           (ARRAY['Disponible', 'Disponible', 'En servicio', 'Fuera de servicio'])[1 + g % 4],
           'Recurso de emergencia en Salto',
           ST_Transform(ST_SetSRID(ST_MakePoint(-57.995 + random() * 0.07, -31.405 + random() * 0.04), 4326), 32721)
    FROM (
        SELECT g, (ARRAY['ambulancia', 'bomberos', 'patrulla', 'centro_atencion', 'otro'])[1 + g % 5] AS tipo
        FROM generate_series(1, 60) g
    ) r
    RETURNING id
)
INSERT INTO _gen_recurso SELECT id FROM nuevos;

-- Incidentes puntuales: 120. La mitad cae en el centro (Centro Salto), la otra mitad en toda la ciudad.
WITH nuevos AS (
    INSERT INTO incidente (titulo, descripcion, tipo_incidente, prioridad, estado, fecha_hora_registro, equipo_responsable, geom)
    SELECT initcap(replace(tipo, '_', ' ')) || ' ' || g,
           'Incidente en Salto',
           tipo,
           1 + floor(random() * random() * 5)::int,
           (ARRAY['Registrado', 'Registrado', 'Registrado', 'En atención', 'En atención', 'En atención',
                  'Derivado', 'Resuelto', 'Resuelto', 'Cancelado'])[1 + floor(random() * 10)::int],
           now() - random() * interval '90 days',
           'Equipo ' || (1 + g % 4),
           ST_Transform(ST_SetSRID(ST_MakePoint(
               CASE WHEN g % 2 = 0 THEN -57.970 + random() * 0.015 ELSE -57.995 + random() * 0.07 END,
               CASE WHEN g % 2 = 0 THEN -31.390 + random() * 0.010 ELSE -31.405 + random() * 0.04 END), 4326), 32721)
    FROM (
        SELECT g, (ARRAY['accidente_transito', 'incendio', 'corte_servicio', 'inundacion', 'otro'])[1 + floor(random() * 5)::int] AS tipo
        FROM generate_series(1, 120) g
    ) i
    RETURNING id
)
INSERT INTO _gen_incidente SELECT id FROM nuevos;

-- Calles cortadas: 20 incidentes de LÍNEA sobre calles reales de Salto (tramos de 80 a 300 m).
WITH nuevos AS (
    INSERT INTO incidente (titulo, descripcion, tipo_incidente, prioridad, estado, fecha_hora_registro, equipo_responsable, geom)
    SELECT 'Calle cortada: ' || nom_calle,
           'Tramo de calle cortado',
           'calle_cortada',
           1 + floor(random() * 4)::int,
           (ARRAY['Registrado', 'En atención', 'En atención', 'Resuelto', 'Derivado'])[1 + floor(random() * 5)::int],
           now() - random() * interval '60 days',
           'Equipo ' || (1 + floor(random() * 4)::int),
           geom
    FROM (
        SELECT nom_calle, geom
        FROM via
        WHERE tipo = 'CALLE'
          AND ST_Length(geom) BETWEEN 80 AND 300
          AND geom && ST_Transform(ST_MakeEnvelope(-57.995, -31.405, -57.925, -31.365, 4326), 32721)
        ORDER BY random()
        LIMIT 20
    ) calles
    RETURNING id
)
INSERT INTO _gen_incidente SELECT id FROM nuevos;

-- Inundaciones: 12 incidentes de POLÍGONO (áreas de 60 a 140 m de radio).
WITH nuevos AS (
    INSERT INTO incidente (titulo, descripcion, tipo_incidente, prioridad, estado, fecha_hora_registro, equipo_responsable, geom)
    SELECT 'Área inundada ' || g,
           'Área afectada por la lluvia',
           'inundacion',
           1 + floor(random() * 3)::int,
           (ARRAY['Registrado', 'En atención', 'Resuelto', 'Cancelado'])[1 + floor(random() * 4)::int],
           now() - random() * interval '45 days',
           'Equipo ' || (1 + g % 4),
           ST_Buffer(ST_Transform(ST_SetSRID(ST_MakePoint(-57.990 + random() * 0.06, -31.400 + random() * 0.03), 4326), 32721),
                     60 + random() * 80, 8)
    FROM generate_series(1, 12) g
    RETURNING id
)
INSERT INTO _gen_incidente SELECT id FROM nuevos;

-- Recursos asignados: los incidentes que no están "Registrado" ni "Cancelado" tienen de 1 a 3 recursos, los más cercanos.
INSERT INTO incidente_recurso (incidente_id, recurso_id, fecha_asignacion)
SELECT i.id, r.id, i.fecha_hora_registro + interval '6 minutes'
FROM incidente i
JOIN _gen_incidente g ON g.id = i.id
CROSS JOIN LATERAL (
    SELECT rec.id FROM recurso rec JOIN _gen_recurso gr ON gr.id = rec.id
    ORDER BY rec.geom <-> i.geom LIMIT 1 + (i.id % 3)
) r
WHERE i.estado IN ('En atención', 'Derivado', 'Resuelto');

-- Historial: el trigger deja una sola fila con el estado actual y la fecha de hoy; se rehace con el camino completo
-- (Registrado, y de ahí En atención / Resuelto / Derivado / Cancelado) a partir de la fecha de cada incidente.
DELETE FROM historial_estado WHERE incidente_id IN (SELECT id FROM _gen_incidente);

INSERT INTO historial_estado (incidente_id, estado, fecha_hora, usuario)
SELECT i.id, 'Registrado', i.fecha_hora_registro, 'sistema'
FROM incidente i JOIN _gen_incidente g ON g.id = i.id
UNION ALL
SELECT i.id, 'En atención', i.fecha_hora_registro + interval '5 minutes', 'operador' || (1 + i.id % 3)
FROM incidente i JOIN _gen_incidente g ON g.id = i.id WHERE i.estado IN ('En atención', 'Resuelto')
UNION ALL
SELECT i.id, 'Resuelto', i.fecha_hora_registro + interval '2 hours', 'operador' || (1 + i.id % 3)
FROM incidente i JOIN _gen_incidente g ON g.id = i.id WHERE i.estado = 'Resuelto'
UNION ALL
SELECT i.id, 'Derivado', i.fecha_hora_registro + interval '8 minutes', 'operador' || (1 + i.id % 3)
FROM incidente i JOIN _gen_incidente g ON g.id = i.id WHERE i.estado = 'Derivado'
UNION ALL
SELECT i.id, 'Cancelado', i.fecha_hora_registro + interval '3 minutes', 'operador' || (1 + i.id % 3)
FROM incidente i JOIN _gen_incidente g ON g.id = i.id WHERE i.estado = 'Cancelado';

DROP TABLE _gen_incidente;
DROP TABLE _gen_recurso;
ANALYZE zona_operativa;
ANALYZE recurso;
ANALYZE incidente;

-- =====================================================================================================
-- Montevideo: el sistema atiende todo el país, y la defensa es en Salto, pero también tiene que haber datos en
-- otro lugar. 30 zonas, 40 recursos y 114 incidentes (puntos, líneas y polígonos) en el centro de Montevideo.
-- No hay calles ni puertas propias de Montevideo (las direcciones de ahí las resuelve la IDE), así que las
-- líneas son tramos rectos de ~200 m, no están sobre calles reales.
-- =====================================================================================================
SELECT setseed(0.2028);

CREATE TEMP TABLE _gen_incidente (id integer PRIMARY KEY);
CREATE TEMP TABLE _gen_recurso (id integer PRIMARY KEY);

-- Zonas: grilla de 6 x 5 celdas de ~1,2 x 1,1 km entre Ciudad Vieja y Pocitos / Cordón / Tres Cruces.
INSERT INTO zona_operativa (nombre, descripcion, nivel_prioridad, responsable, geom)
SELECT 'Montevideo Zona ' || chr(65 + j) || (i + 1),
       'Zona operativa de Montevideo',
       1 + (i * 2 + j * 3) % 5,
       'Equipo MVD ' || (1 + (i + j) % 4),
       ST_Transform(ST_MakeEnvelope(-56.195 + i * 0.0125, -34.900 + j * 0.010,
                                    -56.195 + i * 0.0125 + 0.0118, -34.900 + j * 0.010 + 0.0094, 4326), 32721)
FROM generate_series(0, 5) i, generate_series(0, 4) j;

-- Recursos: 40 puntos al azar sobre la misma área, de todos los tipos y estados.
WITH nuevos AS (
    INSERT INTO recurso (identificacion, nombre, tipo, estado_operativo, descripcion, geom)
    SELECT upper(left(tipo, 3)) || '-M' || lpad(g::text, 3, '0'),
           initcap(replace(tipo, '_', ' ')) || ' MVD ' || g,
           tipo,
           (ARRAY['Disponible', 'Disponible', 'En servicio', 'Fuera de servicio'])[1 + g % 4],
           'Recurso de emergencia en Montevideo',
           ST_Transform(ST_SetSRID(ST_MakePoint(-56.195 + random() * 0.075, -34.900 + random() * 0.05), 4326), 32721)
    FROM (
        SELECT g, (ARRAY['ambulancia', 'bomberos', 'patrulla', 'centro_atencion', 'otro'])[1 + g % 5] AS tipo
        FROM generate_series(1, 40) g
    ) r
    RETURNING id
)
INSERT INTO _gen_recurso SELECT id FROM nuevos;

-- Incidentes puntuales: 100. La mitad cae en el centro, la otra mitad en toda el área.
WITH nuevos AS (
    INSERT INTO incidente (titulo, descripcion, tipo_incidente, prioridad, estado, fecha_hora_registro, equipo_responsable, geom)
    SELECT initcap(replace(tipo, '_', ' ')) || ' ' || g || ' (Montevideo)',
           'Incidente en Montevideo',
           tipo,
           1 + floor(random() * random() * 5)::int,
           (ARRAY['Registrado', 'Registrado', 'Registrado', 'En atención', 'En atención', 'En atención',
                  'Derivado', 'Resuelto', 'Resuelto', 'Cancelado'])[1 + floor(random() * 10)::int],
           now() - random() * interval '90 days',
           'Equipo MVD ' || (1 + g % 4),
           ST_Transform(ST_SetSRID(ST_MakePoint(
               CASE WHEN g % 2 = 0 THEN -56.160 + random() * 0.020 ELSE -56.195 + random() * 0.075 END,
               CASE WHEN g % 2 = 0 THEN -34.885 + random() * 0.015 ELSE -34.900 + random() * 0.05 END), 4326), 32721)
    FROM (
        SELECT g, (ARRAY['accidente_transito', 'incendio', 'corte_servicio', 'inundacion', 'otro'])[1 + floor(random() * 5)::int] AS tipo
        FROM generate_series(1, 100) g
    ) i
    RETURNING id
)
INSERT INTO _gen_incidente SELECT id FROM nuevos;

-- Calles cortadas: 8 incidentes de LÍNEA (tramos rectos de ~200 m).
WITH nuevos AS (
    INSERT INTO incidente (titulo, descripcion, tipo_incidente, prioridad, estado, fecha_hora_registro, equipo_responsable, geom)
    SELECT 'Calle cortada: tramo ' || g || ' (Montevideo)',
           'Incidente en Montevideo',
           'calle_cortada',
           1 + floor(random() * 4)::int,
           (ARRAY['Registrado', 'En atención', 'En atención', 'Resuelto', 'Derivado'])[1 + floor(random() * 5)::int],
           now() - random() * interval '60 days',
           'Equipo MVD ' || (1 + g % 4),
           ST_MakeLine(inicio, ST_Translate(inicio, 150 + random() * 100, (random() - 0.5) * 200))
    FROM (
        SELECT g, ST_Transform(ST_SetSRID(ST_MakePoint(-56.190 + random() * 0.060, -34.895 + random() * 0.040), 4326), 32721) AS inicio
        FROM generate_series(1, 8) g
    ) tramos
    RETURNING id
)
INSERT INTO _gen_incidente SELECT id FROM nuevos;

-- Inundaciones: 6 incidentes de POLÍGONO (áreas de 60 a 140 m de radio).
WITH nuevos AS (
    INSERT INTO incidente (titulo, descripcion, tipo_incidente, prioridad, estado, fecha_hora_registro, equipo_responsable, geom)
    SELECT 'Área inundada ' || g || ' (Montevideo)',
           'Incidente en Montevideo',
           'inundacion',
           1 + floor(random() * 3)::int,
           (ARRAY['Registrado', 'En atención', 'Resuelto', 'Cancelado'])[1 + floor(random() * 4)::int],
           now() - random() * interval '45 days',
           'Equipo MVD ' || (1 + g % 4),
           ST_Buffer(ST_Transform(ST_SetSRID(ST_MakePoint(-56.190 + random() * 0.060, -34.895 + random() * 0.040), 4326), 32721),
                     60 + random() * 80, 8)
    FROM generate_series(1, 6) g
    RETURNING id
)
INSERT INTO _gen_incidente SELECT id FROM nuevos;

-- Recursos asignados e historial, como en Salto.
INSERT INTO incidente_recurso (incidente_id, recurso_id, fecha_asignacion)
SELECT i.id, r.id, i.fecha_hora_registro + interval '6 minutes'
FROM incidente i
JOIN _gen_incidente g ON g.id = i.id
CROSS JOIN LATERAL (
    SELECT rec.id FROM recurso rec JOIN _gen_recurso gr ON gr.id = rec.id
    ORDER BY rec.geom <-> i.geom LIMIT 1 + (i.id % 3)
) r
WHERE i.estado IN ('En atención', 'Derivado', 'Resuelto');

DELETE FROM historial_estado WHERE incidente_id IN (SELECT id FROM _gen_incidente);

INSERT INTO historial_estado (incidente_id, estado, fecha_hora, usuario)
SELECT i.id, 'Registrado', i.fecha_hora_registro, 'sistema'
FROM incidente i JOIN _gen_incidente g ON g.id = i.id
UNION ALL
SELECT i.id, 'En atención', i.fecha_hora_registro + interval '5 minutes', 'operador' || (1 + i.id % 3)
FROM incidente i JOIN _gen_incidente g ON g.id = i.id WHERE i.estado IN ('En atención', 'Resuelto')
UNION ALL
SELECT i.id, 'Resuelto', i.fecha_hora_registro + interval '2 hours', 'operador' || (1 + i.id % 3)
FROM incidente i JOIN _gen_incidente g ON g.id = i.id WHERE i.estado = 'Resuelto'
UNION ALL
SELECT i.id, 'Derivado', i.fecha_hora_registro + interval '8 minutes', 'operador' || (1 + i.id % 3)
FROM incidente i JOIN _gen_incidente g ON g.id = i.id WHERE i.estado = 'Derivado'
UNION ALL
SELECT i.id, 'Cancelado', i.fecha_hora_registro + interval '3 minutes', 'operador' || (1 + i.id % 3)
FROM incidente i JOIN _gen_incidente g ON g.id = i.id WHERE i.estado = 'Cancelado';

DROP TABLE _gen_incidente;
DROP TABLE _gen_recurso;
ANALYZE zona_operativa;
ANALYZE recurso;
ANALYZE incidente;
