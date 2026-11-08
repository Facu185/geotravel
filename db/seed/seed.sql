-- seed.sql — datos de prueba: zonas operativas y recursos REALES de Salto y de Montevideo (db/seed/datos_reales.sql), más
-- incidentes de todos los tipos y formas repartidos por las calles de cada ciudad (y por las localidades del interior de
-- Salto) y algunas unidades móviles en recorrida, para recorrer las consultas.
-- Las geometrías se definen en lon/lat (EPSG:4326) y se transforman a EPSG:32721, el SRID que usa la base.
-- Ejecutar después de la migración V1 y de cargar la red vial (seed.sh lo hace en ese orden).

-- Recursos reales (centros de atención, bomberos, seccionales, ambulancias) y zonas: ver datos_reales.sql. Los recursos
-- quedan anotados en _gen_recurso para asignarlos a los incidentes más abajo.
CREATE TEMP TABLE _gen_recurso (id integer PRIMARY KEY);
\ir datos_reales.sql

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
INSERT INTO incidente_recurso (incidente_id, recurso_id)
SELECT i.id, r.id
FROM (VALUES
    ('Choque en Av. Uruguay',       'Ambulancia UCMS'),                -- Choque en Av. Uruguay -> ambulancia de la UCMS
    ('Fuego en comercio',           'Estación de Bomberos de Salto'),  -- Fuego en comercio -> bomberos
    ('Falta de luz',                'Seccional 1ª de Salto'),          -- Falta de luz -> seccional primera
    ('Inundación en zona baja',     'Seccional 1ª de Salto')           -- Inundación en zona baja -> seccional primera (ya resuelto)
) v(titulo, recurso)
JOIN incidente i ON i.titulo = v.titulo
JOIN recurso r ON r.nombre = v.recurso;


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
-- Datos de prueba para recorrer el sistema, en cantidad moderada y repartidos como en la realidad:
--   * Salto: 18 zonas operativas reales (16 seccionales policiales, que no se superponen, y encima las localidades de Salto
--     y de Termas del Daymán), 21 recursos reales (hospital, centros médicos y mutualista, policlínicas del interior, estación
--     de bomberos, jefatura y seccionales de policía, ambulancias) más 9 unidades móviles, y 43 incidentes. La ciudad tiene la
--     mayoría, a lo largo de sus calles reales; el resto está en las localidades del departamento (Daymán, Belén, Constitución,
--     Termas del Arapey, Pueblo Lavalleja...).
--   * Montevideo: 33 zonas reales (25 seccionales y, superpuestos, 8 municipios), 225 recursos reales (servicios de salud,
--     bomberos, seccionales y comisarías móviles, ambulancias) y 25 incidentes sobre calles (el sistema atiende todo el país).
-- Zonas y recursos son de la Intendencia de Montevideo, del Ministerio del Interior (UNASEV) y de OpenStreetMap (ODbL):
-- ver el encabezado de datos_reales.sql. Los incidentes y las unidades móviles son inventados y deterministas (semilla fija).
-- Va después de la carga de la red vial (seed.sh la carga antes).
-- =====================================================================================================
SELECT setseed(0.2027);

CREATE TEMP TABLE _gen_incidente (id integer PRIMARY KEY);

-- Calles de Salto por las que anda un auto, solo de la red de la ciudad: la tabla via también trae Concordia (Argentina),
-- del otro lado del río, y por eso se toma solo la red de calles conectada con el centro de Salto. Sirve para ubicar
-- recursos e incidentes sobre una calle (acum = largo acumulado: un punto al azar sobre toda la red, más probable
-- cuanto más larga es la calle).
CREATE TEMP TABLE _calles_salto AS
WITH c AS (
    -- Solo el rectángulo de Salto: la tabla via puede traer las calles de todo el país (la carga el servicio red-vial).
    SELECT gid, geom, tipo, ST_ClusterDBSCAN(geom, 0, 1) OVER () AS red
    FROM via
    WHERE geom && ST_Transform(ST_MakeEnvelope(-58.06, -31.46, -57.86, -31.32, 4326), 32721)
)
SELECT gid, geom, ST_Length(geom) AS largo, sum(ST_Length(geom)) OVER (ORDER BY gid) AS acum
FROM c
WHERE red = (SELECT red FROM c ORDER BY geom <-> ST_Transform(ST_SetSRID(ST_MakePoint(-57.9606, -31.3857), 4326), 32721) LIMIT 1)
  AND tipo IN ('CALLE', 'AVENIDA');
CREATE INDEX ON _calles_salto USING gist (geom);
ANALYZE _calles_salto;

-- Móviles de la ciudad: 6 (ambulancias, patrullas y un camión de bomberos) en recorrida por toda la ciudad, fuera de las
-- sedes. Se sortea una calle (más probable cuanto más larga) y un punto sobre ella; si hay otro recurso a menos de 500 m se
-- vuelve a sortear. Estados: 55 % disponible, 30 % en servicio, 15 % fuera de servicio.
DO $$
DECLARE
    unidad record;
    punto geometry;
    total double precision := (SELECT max(acum) FROM _calles_salto);
    sorteo double precision;
    intentos integer;
    nuevo_id integer;
BEGIN
    FOR unidad IN
        SELECT t.tipo, row_number() OVER (PARTITION BY t.tipo) AS n
        FROM (
            SELECT tipo, generate_series(1, cantidad) AS g
            FROM (VALUES ('ambulancia', 2), ('patrulla', 3), ('bomberos', 1)) AS v(tipo, cantidad)
        ) t
        ORDER BY random()
    LOOP
        intentos := 0;
        LOOP
            intentos := intentos + 1;
            sorteo := random() * total;
            SELECT ST_LineInterpolatePoint(c.geom, random()) INTO punto
            FROM _calles_salto c WHERE c.acum >= sorteo ORDER BY c.acum LIMIT 1;
            EXIT WHEN intentos >= 200 OR NOT EXISTS (
                SELECT 1 FROM recurso r JOIN _gen_recurso g ON g.id = r.id WHERE ST_DWithin(r.geom, punto, 500));
        END LOOP;
        sorteo := random();
        INSERT INTO recurso (identificacion, nombre, tipo, estado_operativo, descripcion, geom)
        VALUES (upper(left(unidad.tipo, 3)) || '-S' || (100 + unidad.n),
                initcap(replace(unidad.tipo, '_', ' ')) || ' móvil ' || unidad.n,
                unidad.tipo,
                CASE WHEN sorteo < 0.55 THEN 'Disponible' WHEN sorteo < 0.85 THEN 'En servicio' ELSE 'Fuera de servicio' END,
                'Móvil en recorrida por Salto (simulado)',
                punto)
        RETURNING id INTO nuevo_id;
        INSERT INTO _gen_recurso VALUES (nuevo_id);
    END LOOP;
END $$;

-- Unidades móviles del interior (simuladas, en el centro de cada localidad: no hay base registrada).
-- No hay calles del interior en la base de calles de Salto, así que van en las coordenadas exactas.
WITH nuevos AS (
    INSERT INTO recurso (identificacion, nombre, tipo, estado_operativo, descripcion, geom) VALUES
    ('AMB-S201', 'Ambulancia Belén',              'ambulancia', 'Disponible',  'Unidad móvil en Belén (simulada)',
     ST_Transform(ST_SetSRID(ST_MakePoint(-57.7791, -30.7894), 4326), 32721)),
    ('AMB-S202', 'Ambulancia Constitución',       'ambulancia', 'Disponible',  'Unidad móvil en Constitución (simulada)',
     ST_Transform(ST_SetSRID(ST_MakePoint(-57.8494, -31.0672), 4326), 32721)),
    ('AMB-S203', 'Ambulancia Termas del Daymán',  'ambulancia', 'En servicio', 'Unidad móvil en Termas del Daymán (simulada)',
     ST_Transform(ST_SetSRID(ST_MakePoint(-57.9084, -31.4525), 4326), 32721))
    RETURNING id
)
INSERT INTO _gen_recurso SELECT id FROM nuevos;


-- Incidentes puntuales de la ciudad: 18, sobre calles reales y repartidos por toda la red (no solo en el centro).
WITH nuevos AS (
    INSERT INTO incidente (titulo, descripcion, tipo_incidente, prioridad, estado, fecha_hora_registro, equipo_responsable, geom)
    SELECT initcap(replace(s.tipo, '_', ' ')) || ' ' || s.g,
           'Incidente en Salto',
           s.tipo,
           1 + floor(random() * random() * 5)::int,
           (ARRAY['Registrado', 'Registrado', 'Registrado', 'En atención', 'En atención', 'En atención',
                  'Derivado', 'Resuelto', 'Resuelto', 'Cancelado'])[1 + floor(random() * 10)::int],
           now() - random() * interval '90 days',
           'Equipo ' || (1 + s.g % 4),
           ST_LineInterpolatePoint(c.geom, s.f)
    FROM (
        SELECT g,
               (ARRAY['accidente_transito', 'accidente_transito', 'incendio', 'corte_servicio', 'inundacion', 'otro'])[1 + floor(random() * 6)::int] AS tipo,
               random() * (SELECT max(acum) FROM _calles_salto) AS r,
               random() AS f
        FROM generate_series(1, 18) g
    ) s
    CROSS JOIN LATERAL (SELECT geom FROM _calles_salto WHERE acum >= s.r ORDER BY acum LIMIT 1) c
    RETURNING id
)
INSERT INTO _gen_incidente SELECT id FROM nuevos;

-- Calles cortadas de la ciudad: 4 incidentes de LÍNEA sobre calles reales (tramos de 80 a 300 m).
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
          AND gid IN (SELECT gid FROM _calles_salto)
          AND ST_Length(geom) BETWEEN 80 AND 300
        ORDER BY random()
        LIMIT 4
    ) calles
    RETURNING id
)
INSERT INTO _gen_incidente SELECT id FROM nuevos;

-- Inundaciones de la ciudad: 3 incidentes de POLÍGONO (áreas de 60 a 140 m de radio) en la parte baja, cerca del río.
WITH nuevos AS (
    INSERT INTO incidente (titulo, descripcion, tipo_incidente, prioridad, estado, fecha_hora_registro, equipo_responsable, geom)
    SELECT 'Área inundada ' || z.g,
           'Área afectada por la lluvia',
           'inundacion',
           1 + floor(random() * 3)::int,
           (ARRAY['Registrado', 'En atención', 'Resuelto', 'Cancelado'])[1 + floor(random() * 4)::int],
           now() - random() * interval '45 days',
           'Equipo ' || (1 + z.g % 4),
           ST_Buffer(ST_LineInterpolatePoint(z.geom, 0.5), 60 + random() * 80, 8)
    FROM (
        SELECT row_number() OVER () AS g, geom
        FROM (SELECT geom FROM _calles_salto
              WHERE ST_X(ST_Transform(ST_Centroid(geom), 4326)) < -57.965 ORDER BY random() LIMIT 3) bajas
    ) z
    RETURNING id
)
INSERT INTO _gen_incidente SELECT id FROM nuevos;
DROP TABLE _calles_salto;

-- Incidentes del interior del departamento: uno en cada una de 12 localidades, con el tipo de incidente que es más común en
-- cada lugar, y dos áreas inundadas. Van SOBRE una calle de OpenStreetMap, la más cercana al centro del pueblo (a menos de
-- 100 m): son las coordenadas que dio esa búsqueda sobre la red vial (el seed corre antes de que se cargue la red, así que
-- quedan escritas acá). Un incidente a más de 500 m de una calle no tiene ruta (ver docs/RED_VIAL.md).
WITH nuevos AS (
    INSERT INTO incidente (titulo, descripcion, tipo_incidente, prioridad, estado, fecha_hora_registro, equipo_responsable, geom)
    SELECT initcap(replace(l.tipo, '_', ' ')) || ' en ' || l.nombre,
           'Incidente en el interior del departamento de Salto',
           l.tipo,
           1 + floor(random() * random() * 5)::int,
           (ARRAY['Registrado', 'Registrado', 'En atención', 'En atención', 'Derivado', 'Resuelto', 'Resuelto', 'Cancelado'])[1 + floor(random() * 8)::int],
           now() - random() * interval '90 days',
           'Equipo Interior',
           ST_Transform(ST_SetSRID(ST_MakePoint(l.lon, l.lat), 4326), 32721)
    FROM (VALUES
        ('Termas del Daymán', 'incendio',           -57.90846, -31.45249),
        ('Belén',             'accidente_transito', -57.77958, -30.78926),
        ('Constitución',      'corte_servicio',     -57.84949, -31.06747),
        ('Termas del Arapey', 'accidente_transito', -57.52326, -30.94699),
        ('Colonia 18 de Julio', 'incendio',         -57.87359, -31.35596),
        ('Garibaldi',         'otro',               -57.82880, -31.33924),
        ('San Antonio',       'accidente_transito', -57.76720, -31.35771),
        ('Pueblo Lavalleja',  'incendio',           -57.02503, -31.09567),
        ('Biassini',          'corte_servicio',     -57.12620, -31.27740),
        ('Rincón de Valentín', 'accidente_transito', -57.19929, -31.28202),
        ('Campo de Todos',    'otro',               -57.61392, -31.55935),
        ('Laureles',          'incendio',           -57.52638, -31.49875)
    ) l(nombre, tipo, lon, lat)
    RETURNING id
)
INSERT INTO _gen_incidente SELECT id FROM nuevos;

WITH nuevos AS (
    INSERT INTO incidente (titulo, descripcion, tipo_incidente, prioridad, estado, fecha_hora_registro, equipo_responsable, geom)
    SELECT 'Área inundada en ' || a.nombre,
           'Área afectada por la crecida',
           'inundacion',
           1 + floor(random() * 3)::int,
           (ARRAY['Registrado', 'En atención', 'Resuelto'])[1 + floor(random() * 3)::int],
           now() - random() * interval '45 days',
           'Equipo Interior',
           ST_Buffer(ST_Transform(ST_SetSRID(ST_MakePoint(a.lon, a.lat), 4326), 32721), 150 + random() * 100, 8)
    FROM (VALUES ('Belén', -57.78588, -30.79048), ('Constitución', -57.86212, -31.07368)) a(nombre, lon, lat)
    RETURNING id
)
INSERT INTO _gen_incidente SELECT id FROM nuevos;

-- Recursos asignados: los incidentes que no están "Registrado" ni "Cancelado" tienen de 1 a 3 recursos disponibles o en
-- servicio, los más cercanos y a menos de 30 km (un incidente lejos de todo no tiene recurso asignado).
INSERT INTO incidente_recurso (incidente_id, recurso_id, fecha_asignacion)
SELECT i.id, r.id, i.fecha_hora_registro + interval '6 minutes'
FROM incidente i
JOIN _gen_incidente g ON g.id = i.id
CROSS JOIN LATERAL (
    SELECT rec.id FROM recurso rec JOIN _gen_recurso gr ON gr.id = rec.id
    WHERE rec.estado_operativo <> 'Fuera de servicio' AND ST_DWithin(rec.geom, i.geom, 30000)
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
ANALYZE zona_operativa;
ANALYZE recurso;
ANALYZE incidente;

-- =====================================================================================================
-- Montevideo: el sistema atiende todo el país, y la defensa es en Salto, pero también tiene que haber datos en otro lugar.
-- Las zonas y los recursos reales de Montevideo ya se cargaron arriba (datos_reales.sql); acá van 25 incidentes (puntos, líneas
-- y polígonos) repartidos sobre las calles reales de la ciudad (tabla via, que trae el país entero): la red conectada con
-- la Plaza Independencia. Las líneas son calles reales cortadas, no tramos rectos.
-- =====================================================================================================
SELECT setseed(0.2028);

CREATE TEMP TABLE _gen_incidente (id integer PRIMARY KEY);

-- Calles de Montevideo por las que anda un auto (solo la red conectada con el centro), con el largo acumulado para sortear
-- un punto al azar sobre toda la red, más probable cuanto más larga es la calle.
CREATE TEMP TABLE _calles_mvd AS
WITH c AS (
    SELECT gid, geom, tipo, nom_calle, ST_ClusterDBSCAN(geom, 0, 1) OVER () AS red
    FROM via
    WHERE geom && ST_Transform(ST_MakeEnvelope(-56.27, -34.94, -56.05, -34.80, 4326), 32721)
)
SELECT gid, geom, nom_calle, ST_Length(geom) AS largo, sum(ST_Length(geom)) OVER (ORDER BY gid) AS acum
FROM c
WHERE red = (SELECT red FROM c ORDER BY geom <-> ST_Transform(ST_SetSRID(ST_MakePoint(-56.2013, -34.9059), 4326), 32721) LIMIT 1)
  AND tipo IN ('CALLE', 'AVENIDA');
CREATE INDEX ON _calles_mvd USING gist (geom);
ANALYZE _calles_mvd;

-- Incidentes puntuales: 20, sobre calles reales y repartidos por toda la red.
WITH nuevos AS (
    INSERT INTO incidente (titulo, descripcion, tipo_incidente, prioridad, estado, fecha_hora_registro, equipo_responsable, geom)
    SELECT initcap(replace(s.tipo, '_', ' ')) || ' ' || s.g || ' (Montevideo)',
           'Incidente en Montevideo',
           s.tipo,
           1 + floor(random() * random() * 5)::int,
           (ARRAY['Registrado', 'Registrado', 'Registrado', 'En atención', 'En atención', 'En atención',
                  'Derivado', 'Resuelto', 'Resuelto', 'Cancelado'])[1 + floor(random() * 10)::int],
           now() - random() * interval '90 days',
           'Equipo MVD ' || (1 + s.g % 4),
           ST_LineInterpolatePoint(c.geom, s.f)
    FROM (
        SELECT g,
               (ARRAY['accidente_transito', 'incendio', 'corte_servicio', 'inundacion', 'otro'])[1 + floor(random() * 5)::int] AS tipo,
               random() * (SELECT max(acum) FROM _calles_mvd) AS r,
               random() AS f
        FROM generate_series(1, 20) g
    ) s
    CROSS JOIN LATERAL (SELECT geom FROM _calles_mvd WHERE acum >= s.r ORDER BY acum LIMIT 1) c
    RETURNING id
)
INSERT INTO _gen_incidente SELECT id FROM nuevos;

-- Calles cortadas: 3 incidentes de LÍNEA sobre calles reales (tramos de 80 a 300 m).
WITH nuevos AS (
    INSERT INTO incidente (titulo, descripcion, tipo_incidente, prioridad, estado, fecha_hora_registro, equipo_responsable, geom)
    SELECT 'Calle cortada: ' || calles.nom_calle,
           'Tramo de calle cortado (Montevideo)',
           'calle_cortada',
           1 + floor(random() * 4)::int,
           (ARRAY['Registrado', 'En atención', 'En atención', 'Resuelto', 'Derivado'])[1 + floor(random() * 5)::int],
           now() - random() * interval '60 days',
           'Equipo MVD ' || (1 + calles.n % 4),
           calles.geom
    FROM (
        SELECT row_number() OVER () AS n, nom_calle, geom
        FROM (SELECT nom_calle, geom FROM _calles_mvd
              WHERE largo BETWEEN 80 AND 300 AND nom_calle IS NOT NULL ORDER BY random() LIMIT 3) elegidas
    ) calles
    RETURNING id
)
INSERT INTO _gen_incidente SELECT id FROM nuevos;

-- Inundaciones: 2 incidentes de POLÍGONO (áreas de 60 a 140 m de radio) sobre calles de la zona baja de la costa.
WITH nuevos AS (
    INSERT INTO incidente (titulo, descripcion, tipo_incidente, prioridad, estado, fecha_hora_registro, equipo_responsable, geom)
    SELECT 'Área inundada ' || z.g || ' (Montevideo)',
           'Incidente en Montevideo',
           'inundacion',
           1 + floor(random() * 3)::int,
           (ARRAY['Registrado', 'En atención', 'Resuelto', 'Cancelado'])[1 + floor(random() * 4)::int],
           now() - random() * interval '45 days',
           'Equipo MVD ' || (1 + z.g % 4),
           ST_Buffer(ST_LineInterpolatePoint(z.geom, 0.5), 60 + random() * 80, 8)
    FROM (
        SELECT row_number() OVER () AS g, geom
        FROM (SELECT geom FROM _calles_mvd
              WHERE ST_Y(ST_Transform(ST_Centroid(geom), 4326)) < -34.90 ORDER BY random() LIMIT 2) bajas
    ) z
    RETURNING id
)
INSERT INTO _gen_incidente SELECT id FROM nuevos;
DROP TABLE _calles_mvd;

-- Recursos asignados e historial, como en Salto.
INSERT INTO incidente_recurso (incidente_id, recurso_id, fecha_asignacion)
SELECT i.id, r.id, i.fecha_hora_registro + interval '6 minutes'
FROM incidente i
JOIN _gen_incidente g ON g.id = i.id
CROSS JOIN LATERAL (
    SELECT rec.id FROM recurso rec JOIN _gen_recurso gr ON gr.id = rec.id
    WHERE rec.estado_operativo <> 'Fuera de servicio' AND ST_DWithin(rec.geom, i.geom, 30000)
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
