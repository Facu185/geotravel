-- seed.sql — datos de prueba: zonas operativas y recursos REALES de Salto y de Montevideo (db/seed/datos_reales.sql), más
-- incidentes de todos los tipos y formas repartidos por las calles de cada ciudad (y por las localidades del interior de
-- Salto) y algunas unidades móviles en recorrida, para recorrer las consultas.
-- Las geometrías se definen en lon/lat (EPSG:4326) y se transforman a EPSG:32721, el SRID que usa la base.
-- Ejecutar después de la migración V1 y de cargar las calles de Salto (tabla via; seed.sh lo hace en ese orden). La red del
-- país entero la carga después el servicio red-vial: por eso nada de acá depende de calles de fuera de Salto.

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
--     de bomberos, jefatura y seccionales de policía, ambulancias) más 31 unidades móviles (10 ambulancias, 16 patrullas y 2 camiones
--     de bomberos en la ciudad, y 3 ambulancias en el interior), y 114 incidentes. La ciudad tiene la
--     mayoría, a lo largo de sus calles reales; el resto está en las localidades del departamento (Daymán, Belén, Constitución,
--     Termas del Arapey, Pueblo Lavalleja...).
--   * Montevideo: 33 zonas reales (25 seccionales y, superpuestos, 8 municipios), 225 recursos reales (servicios de salud,
--     bomberos, seccionales y comisarías móviles, ambulancias) más 46 unidades móviles (16 ambulancias y 30 patrullas) y 83
--     incidentes sobre calles (el sistema atiende todo el país).
-- Zonas y recursos son de la Intendencia de Montevideo, del Ministerio del Interior (UNASEV) y de OpenStreetMap (ODbL):
-- ver el encabezado de datos_reales.sql. Los incidentes y las unidades móviles son inventados y deterministas (semilla fija).
-- Va después de la carga de las calles de Salto (seed.sh la carga antes).
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

-- Móviles de la ciudad: 28 (10 ambulancias, 16 patrullas y 2 camiones de bomberos) en recorrida por toda la ciudad, fuera de las
-- sedes. Se sortea una calle (más probable cuanto más larga) y un punto sobre ella; si hay otro recurso a menos de 350 m se
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
            FROM (VALUES ('ambulancia', 10), ('patrulla', 16), ('bomberos', 2)) AS v(tipo, cantidad)
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
                SELECT 1 FROM recurso r JOIN _gen_recurso g ON g.id = r.id WHERE ST_DWithin(r.geom, punto, 350));
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


-- Incidentes puntuales de la ciudad: 80, sobre calles reales y repartidos por toda la red (no solo en el centro).
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
        FROM generate_series(1, 80) g
    ) s
    CROSS JOIN LATERAL (SELECT geom FROM _calles_salto WHERE acum >= s.r ORDER BY acum LIMIT 1) c
    RETURNING id
)
INSERT INTO _gen_incidente SELECT id FROM nuevos;

-- Calles cortadas de la ciudad: 10 incidentes de LÍNEA sobre calles reales (tramos de 80 a 300 m).
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
        LIMIT 10
    ) calles
    RETURNING id
)
INSERT INTO _gen_incidente SELECT id FROM nuevos;

-- Inundaciones de la ciudad: 6 incidentes de POLÍGONO (áreas de 60 a 140 m de radio) en la parte baja, cerca del río.
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
              WHERE ST_X(ST_Transform(ST_Centroid(geom), 4326)) < -57.965 ORDER BY random() LIMIT 6) bajas
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
-- Las zonas y los recursos reales de Montevideo ya se cargaron arriba (datos_reales.sql); acá van 46 unidades móviles (ambulancias y
-- patrullas) y 83 incidentes (puntos, líneas y polígonos) sobre las calles reales de la ciudad, con coordenadas fijas.
-- =====================================================================================================
CREATE TEMP TABLE _gen_incidente (id integer PRIMARY KEY);

-- Unidades móviles y incidentes de Montevideo, con las coordenadas escritas acá (no se sortean): cuando corre el seed la tabla
-- via solo tiene las calles de Salto, porque la red del país la carga después el servicio red-vial. Las coordenadas salieron de
-- sortear puntos sobre la red de calles de Montevideo (la conectada con la Plaza Independencia): quedan SOBRE una calle, así que
-- se puede calcular una ruta hasta cada una. Las líneas son calles reales cortadas (80 a 300 m) y los polígonos, áreas de
-- 60 a 140 m de radio en la zona baja de la costa. "minutos" es la antigüedad del incidente.

-- Móviles: 46 (16 ambulancias y 30 patrullas), que se suman a los servicios reales. Simulados.
WITH nuevos AS (
    INSERT INTO recurso (identificacion, nombre, tipo, estado_operativo, descripcion, geom)
    SELECT v.identificacion, v.nombre, v.tipo, v.estado, 'Móvil en recorrida por Montevideo (simulado)',
           ST_Transform(ST_SetSRID(ST_GeomFromText(v.wkt), 4326), 32721)
    FROM (VALUES
    ('AMB-M101', 'Ambulancia móvil 1 (Montevideo)', 'ambulancia', 'En servicio', 'POINT(-56.249471 -34.820773)'),
    ('AMB-M102', 'Ambulancia móvil 2 (Montevideo)', 'ambulancia', 'En servicio', 'POINT(-56.069951 -34.884577)'),
    ('AMB-M103', 'Ambulancia móvil 3 (Montevideo)', 'ambulancia', 'Disponible', 'POINT(-56.170727 -34.863074)'),
    ('AMB-M104', 'Ambulancia móvil 4 (Montevideo)', 'ambulancia', 'Disponible', 'POINT(-56.168013 -34.814295)'),
    ('AMB-M105', 'Ambulancia móvil 5 (Montevideo)', 'ambulancia', 'Disponible', 'POINT(-56.249934 -34.828125)'),
    ('AMB-M106', 'Ambulancia móvil 6 (Montevideo)', 'ambulancia', 'Disponible', 'POINT(-56.225368 -34.811015)'),
    ('AMB-M107', 'Ambulancia móvil 7 (Montevideo)', 'ambulancia', 'Fuera de servicio', 'POINT(-56.210324 -34.87033)'),
    ('AMB-M108', 'Ambulancia móvil 8 (Montevideo)', 'ambulancia', 'Fuera de servicio', 'POINT(-56.101745 -34.817362)'),
    ('AMB-M109', 'Ambulancia móvil 9 (Montevideo)', 'ambulancia', 'Disponible', 'POINT(-56.143443 -34.900798)'),
    ('AMB-M110', 'Ambulancia móvil 10 (Montevideo)', 'ambulancia', 'Disponible', 'POINT(-56.255612 -34.856189)'),
    ('AMB-M111', 'Ambulancia móvil 11 (Montevideo)', 'ambulancia', 'En servicio', 'POINT(-56.14992 -34.900571)'),
    ('AMB-M112', 'Ambulancia móvil 12 (Montevideo)', 'ambulancia', 'Disponible', 'POINT(-56.147428 -34.806843)'),
    ('AMB-M113', 'Ambulancia móvil 13 (Montevideo)', 'ambulancia', 'Disponible', 'POINT(-56.119434 -34.85899)'),
    ('AMB-M114', 'Ambulancia móvil 14 (Montevideo)', 'ambulancia', 'Disponible', 'POINT(-56.112658 -34.821495)'),
    ('AMB-M115', 'Ambulancia móvil 15 (Montevideo)', 'ambulancia', 'Disponible', 'POINT(-56.050794 -34.852184)'),
    ('AMB-M116', 'Ambulancia móvil 16 (Montevideo)', 'ambulancia', 'Disponible', 'POINT(-56.134837 -34.821987)'),
    ('PAT-M101', 'Patrulla móvil 1 (Montevideo)', 'patrulla', 'Disponible', 'POINT(-56.147354 -34.876674)'),
    ('PAT-M102', 'Patrulla móvil 2 (Montevideo)', 'patrulla', 'Disponible', 'POINT(-56.195233 -34.881519)'),
    ('PAT-M103', 'Patrulla móvil 3 (Montevideo)', 'patrulla', 'Disponible', 'POINT(-56.152475 -34.919745)'),
    ('PAT-M104', 'Patrulla móvil 4 (Montevideo)', 'patrulla', 'Disponible', 'POINT(-56.258209 -34.876906)'),
    ('PAT-M105', 'Patrulla móvil 5 (Montevideo)', 'patrulla', 'Disponible', 'POINT(-56.198994 -34.908353)'),
    ('PAT-M106', 'Patrulla móvil 6 (Montevideo)', 'patrulla', 'En servicio', 'POINT(-56.117774 -34.854861)'),
    ('PAT-M107', 'Patrulla móvil 7 (Montevideo)', 'patrulla', 'En servicio', 'POINT(-56.118097 -34.863314)'),
    ('PAT-M108', 'Patrulla móvil 8 (Montevideo)', 'patrulla', 'En servicio', 'POINT(-56.079515 -34.869986)'),
    ('PAT-M109', 'Patrulla móvil 9 (Montevideo)', 'patrulla', 'Fuera de servicio', 'POINT(-56.067015 -34.882733)'),
    ('PAT-M110', 'Patrulla móvil 10 (Montevideo)', 'patrulla', 'Disponible', 'POINT(-56.177899 -34.802908)'),
    ('PAT-M111', 'Patrulla móvil 11 (Montevideo)', 'patrulla', 'En servicio', 'POINT(-56.045599 -34.885863)'),
    ('PAT-M112', 'Patrulla móvil 12 (Montevideo)', 'patrulla', 'En servicio', 'POINT(-56.195178 -34.902382)'),
    ('PAT-M113', 'Patrulla móvil 13 (Montevideo)', 'patrulla', 'Disponible', 'POINT(-56.079644 -34.898778)'),
    ('PAT-M114', 'Patrulla móvil 14 (Montevideo)', 'patrulla', 'Disponible', 'POINT(-56.128192 -34.872846)'),
    ('PAT-M115', 'Patrulla móvil 15 (Montevideo)', 'patrulla', 'Disponible', 'POINT(-56.110947 -34.843081)'),
    ('PAT-M116', 'Patrulla móvil 16 (Montevideo)', 'patrulla', 'Disponible', 'POINT(-56.26326 -34.807869)'),
    ('PAT-M117', 'Patrulla móvil 17 (Montevideo)', 'patrulla', 'Disponible', 'POINT(-56.132388 -34.884276)'),
    ('PAT-M118', 'Patrulla móvil 18 (Montevideo)', 'patrulla', 'Disponible', 'POINT(-56.130764 -34.816535)'),
    ('PAT-M119', 'Patrulla móvil 19 (Montevideo)', 'patrulla', 'Fuera de servicio', 'POINT(-56.170972 -34.858114)'),
    ('PAT-M120', 'Patrulla móvil 20 (Montevideo)', 'patrulla', 'Disponible', 'POINT(-56.208497 -34.904085)'),
    ('PAT-M121', 'Patrulla móvil 21 (Montevideo)', 'patrulla', 'Disponible', 'POINT(-56.095115 -34.875159)'),
    ('PAT-M122', 'Patrulla móvil 22 (Montevideo)', 'patrulla', 'Disponible', 'POINT(-56.178871 -34.865964)'),
    ('PAT-M123', 'Patrulla móvil 23 (Montevideo)', 'patrulla', 'En servicio', 'POINT(-56.097293 -34.885271)'),
    ('PAT-M124', 'Patrulla móvil 24 (Montevideo)', 'patrulla', 'Disponible', 'POINT(-56.049135 -34.882971)'),
    ('PAT-M125', 'Patrulla móvil 25 (Montevideo)', 'patrulla', 'Fuera de servicio', 'POINT(-56.097155 -34.878894)'),
    ('PAT-M126', 'Patrulla móvil 26 (Montevideo)', 'patrulla', 'En servicio', 'POINT(-56.187341 -34.836267)'),
    ('PAT-M127', 'Patrulla móvil 27 (Montevideo)', 'patrulla', 'En servicio', 'POINT(-56.252542 -34.80188)'),
    ('PAT-M128', 'Patrulla móvil 28 (Montevideo)', 'patrulla', 'Fuera de servicio', 'POINT(-56.170305 -34.845366)'),
    ('PAT-M129', 'Patrulla móvil 29 (Montevideo)', 'patrulla', 'En servicio', 'POINT(-56.235103 -34.852977)'),
    ('PAT-M130', 'Patrulla móvil 30 (Montevideo)', 'patrulla', 'Disponible', 'POINT(-56.128508 -34.829847)')
    ) AS v(identificacion, nombre, tipo, estado, wkt)
    RETURNING id
)
INSERT INTO _gen_recurso SELECT id FROM nuevos;

-- Incidentes: 83 (70 puntuales, 8 calles cortadas y 5 áreas inundadas).
WITH nuevos AS (
    INSERT INTO incidente (titulo, descripcion, tipo_incidente, prioridad, estado, fecha_hora_registro, equipo_responsable, geom)
    SELECT v.titulo, v.descripcion, v.tipo, v.prioridad, v.estado, now() - v.minutos * interval '1 minute', v.equipo,
           ST_Transform(ST_SetSRID(ST_GeomFromText(v.wkt), 4326), 32721)
    FROM (VALUES
    ('Corte Servicio 1 (Montevideo)', 'Incidente en Montevideo', 'corte_servicio', 2, 'Registrado', 115448, 'Equipo MVD 2', 'POINT(-56.114217 -34.797315)'),
    ('Accidente Transito 2 (Montevideo)', 'Incidente en Montevideo', 'accidente_transito', 1, 'Derivado', 120140, 'Equipo MVD 3', 'POINT(-56.242084 -34.79643)'),
    ('Otro 3 (Montevideo)', 'Incidente en Montevideo', 'otro', 1, 'En atención', 13423, 'Equipo MVD 4', 'POINT(-56.209138 -34.848038)'),
    ('Otro 4 (Montevideo)', 'Incidente en Montevideo', 'otro', 1, 'Registrado', 94616, 'Equipo MVD 1', 'POINT(-56.212505 -34.83036)'),
    ('Corte Servicio 5 (Montevideo)', 'Incidente en Montevideo', 'corte_servicio', 3, 'Registrado', 108114, 'Equipo MVD 2', 'POINT(-56.128 -34.817777)'),
    ('Otro 6 (Montevideo)', 'Incidente en Montevideo', 'otro', 1, 'Registrado', 115354, 'Equipo MVD 3', 'POINT(-56.244716 -34.834169)'),
    ('Otro 7 (Montevideo)', 'Incidente en Montevideo', 'otro', 3, 'Resuelto', 117635, 'Equipo MVD 4', 'POINT(-56.180689 -34.858739)'),
    ('Otro 8 (Montevideo)', 'Incidente en Montevideo', 'otro', 2, 'Registrado', 96993, 'Equipo MVD 1', 'POINT(-56.207723 -34.866801)'),
    ('Corte Servicio 9 (Montevideo)', 'Incidente en Montevideo', 'corte_servicio', 2, 'Resuelto', 69806, 'Equipo MVD 2', 'POINT(-56.25108 -34.886393)'),
    ('Corte Servicio 10 (Montevideo)', 'Incidente en Montevideo', 'corte_servicio', 2, 'Derivado', 115341, 'Equipo MVD 3', 'POINT(-56.185779 -34.887726)'),
    ('Corte Servicio 11 (Montevideo)', 'Incidente en Montevideo', 'corte_servicio', 2, 'En atención', 66007, 'Equipo MVD 4', 'POINT(-56.19111 -34.868613)'),
    ('Accidente Transito 12 (Montevideo)', 'Incidente en Montevideo', 'accidente_transito', 1, 'Resuelto', 114793, 'Equipo MVD 1', 'POINT(-56.14924 -34.920308)'),
    ('Otro 13 (Montevideo)', 'Incidente en Montevideo', 'otro', 2, 'En atención', 107214, 'Equipo MVD 2', 'POINT(-56.138514 -34.806582)'),
    ('Accidente Transito 14 (Montevideo)', 'Incidente en Montevideo', 'accidente_transito', 2, 'Cancelado', 100950, 'Equipo MVD 3', 'POINT(-56.200566 -34.825732)'),
    ('Accidente Transito 15 (Montevideo)', 'Incidente en Montevideo', 'accidente_transito', 3, 'En atención', 47171, 'Equipo MVD 4', 'POINT(-56.157674 -34.839426)'),
    ('Incendio 16 (Montevideo)', 'Incidente en Montevideo', 'incendio', 1, 'En atención', 88136, 'Equipo MVD 1', 'POINT(-56.135026 -34.87038)'),
    ('Inundacion 17 (Montevideo)', 'Incidente en Montevideo', 'inundacion', 1, 'Resuelto', 2757, 'Equipo MVD 2', 'POINT(-56.083158 -34.888848)'),
    ('Corte Servicio 18 (Montevideo)', 'Incidente en Montevideo', 'corte_servicio', 1, 'Resuelto', 74500, 'Equipo MVD 3', 'POINT(-56.217923 -34.864077)'),
    ('Corte Servicio 19 (Montevideo)', 'Incidente en Montevideo', 'corte_servicio', 1, 'Resuelto', 87419, 'Equipo MVD 4', 'POINT(-56.145956 -34.884446)'),
    ('Otro 20 (Montevideo)', 'Incidente en Montevideo', 'otro', 1, 'Resuelto', 76075, 'Equipo MVD 1', 'POINT(-56.122226 -34.837518)'),
    ('Corte Servicio 21 (Montevideo)', 'Incidente en Montevideo', 'corte_servicio', 1, 'Resuelto', 30858, 'Equipo MVD 2', 'POINT(-56.114531 -34.895685)'),
    ('Corte Servicio 22 (Montevideo)', 'Incidente en Montevideo', 'corte_servicio', 2, 'Registrado', 53126, 'Equipo MVD 3', 'POINT(-56.162396 -34.917473)'),
    ('Corte Servicio 23 (Montevideo)', 'Incidente en Montevideo', 'corte_servicio', 4, 'En atención', 126269, 'Equipo MVD 4', 'POINT(-56.194849 -34.834813)'),
    ('Accidente Transito 24 (Montevideo)', 'Incidente en Montevideo', 'accidente_transito', 1, 'Registrado', 31056, 'Equipo MVD 1', 'POINT(-56.220618 -34.81254)'),
    ('Otro 25 (Montevideo)', 'Incidente en Montevideo', 'otro', 1, 'En atención', 84242, 'Equipo MVD 2', 'POINT(-56.129071 -34.82505)'),
    ('Incendio 26 (Montevideo)', 'Incidente en Montevideo', 'incendio', 1, 'Registrado', 88562, 'Equipo MVD 3', 'POINT(-56.138677 -34.895582)'),
    ('Corte Servicio 27 (Montevideo)', 'Incidente en Montevideo', 'corte_servicio', 1, 'Resuelto', 116303, 'Equipo MVD 4', 'POINT(-56.142673 -34.870888)'),
    ('Corte Servicio 28 (Montevideo)', 'Incidente en Montevideo', 'corte_servicio', 1, 'Resuelto', 102723, 'Equipo MVD 1', 'POINT(-56.119199 -34.859446)'),
    ('Incendio 29 (Montevideo)', 'Incidente en Montevideo', 'incendio', 1, 'En atención', 79143, 'Equipo MVD 2', 'POINT(-56.111895 -34.828179)'),
    ('Otro 30 (Montevideo)', 'Incidente en Montevideo', 'otro', 1, 'Derivado', 118664, 'Equipo MVD 3', 'POINT(-56.199841 -34.875981)'),
    ('Accidente Transito 31 (Montevideo)', 'Incidente en Montevideo', 'accidente_transito', 1, 'Resuelto', 96299, 'Equipo MVD 4', 'POINT(-56.101054 -34.896817)'),
    ('Accidente Transito 32 (Montevideo)', 'Incidente en Montevideo', 'accidente_transito', 1, 'En atención', 126255, 'Equipo MVD 1', 'POINT(-56.166457 -34.851139)'),
    ('Corte Servicio 33 (Montevideo)', 'Incidente en Montevideo', 'corte_servicio', 2, 'Registrado', 36414, 'Equipo MVD 2', 'POINT(-56.185843 -34.839209)'),
    ('Otro 34 (Montevideo)', 'Incidente en Montevideo', 'otro', 2, 'En atención', 116781, 'Equipo MVD 3', 'POINT(-56.149609 -34.893863)'),
    ('Inundacion 35 (Montevideo)', 'Incidente en Montevideo', 'inundacion', 1, 'Derivado', 105069, 'Equipo MVD 4', 'POINT(-56.193041 -34.884817)'),
    ('Inundacion 36 (Montevideo)', 'Incidente en Montevideo', 'inundacion', 4, 'Resuelto', 68663, 'Equipo MVD 1', 'POINT(-56.102538 -34.872504)'),
    ('Otro 37 (Montevideo)', 'Incidente en Montevideo', 'otro', 2, 'En atención', 110734, 'Equipo MVD 2', 'POINT(-56.092252 -34.871999)'),
    ('Inundacion 38 (Montevideo)', 'Incidente en Montevideo', 'inundacion', 1, 'Registrado', 120985, 'Equipo MVD 3', 'POINT(-56.074444 -34.895718)'),
    ('Accidente Transito 39 (Montevideo)', 'Incidente en Montevideo', 'accidente_transito', 2, 'Cancelado', 80633, 'Equipo MVD 4', 'POINT(-56.125515 -34.809041)'),
    ('Otro 40 (Montevideo)', 'Incidente en Montevideo', 'otro', 2, 'En atención', 30053, 'Equipo MVD 1', 'POINT(-56.145256 -34.895442)'),
    ('Incendio 41 (Montevideo)', 'Incidente en Montevideo', 'incendio', 1, 'Derivado', 127477, 'Equipo MVD 2', 'POINT(-56.164654 -34.841733)'),
    ('Incendio 42 (Montevideo)', 'Incidente en Montevideo', 'incendio', 1, 'Registrado', 73454, 'Equipo MVD 3', 'POINT(-56.14389 -34.90682)'),
    ('Inundacion 43 (Montevideo)', 'Incidente en Montevideo', 'inundacion', 2, 'Cancelado', 46572, 'Equipo MVD 4', 'POINT(-56.263879 -34.838414)'),
    ('Corte Servicio 44 (Montevideo)', 'Incidente en Montevideo', 'corte_servicio', 1, 'Registrado', 119411, 'Equipo MVD 1', 'POINT(-56.183473 -34.893499)'),
    ('Accidente Transito 45 (Montevideo)', 'Incidente en Montevideo', 'accidente_transito', 2, 'En atención', 125543, 'Equipo MVD 2', 'POINT(-56.223709 -34.850349)'),
    ('Inundacion 46 (Montevideo)', 'Incidente en Montevideo', 'inundacion', 2, 'Cancelado', 102765, 'Equipo MVD 3', 'POINT(-56.137038 -34.909604)'),
    ('Incendio 47 (Montevideo)', 'Incidente en Montevideo', 'incendio', 3, 'Derivado', 16813, 'Equipo MVD 4', 'POINT(-56.220418 -34.816833)'),
    ('Incendio 48 (Montevideo)', 'Incidente en Montevideo', 'incendio', 2, 'Resuelto', 58032, 'Equipo MVD 1', 'POINT(-56.224256 -34.859018)'),
    ('Corte Servicio 49 (Montevideo)', 'Incidente en Montevideo', 'corte_servicio', 3, 'Registrado', 91216, 'Equipo MVD 2', 'POINT(-56.123625 -34.89137)'),
    ('Corte Servicio 50 (Montevideo)', 'Incidente en Montevideo', 'corte_servicio', 1, 'Registrado', 52907, 'Equipo MVD 3', 'POINT(-56.222737 -34.838918)'),
    ('Otro 51 (Montevideo)', 'Incidente en Montevideo', 'otro', 3, 'Registrado', 52792, 'Equipo MVD 4', 'POINT(-56.243391 -34.843759)'),
    ('Incendio 52 (Montevideo)', 'Incidente en Montevideo', 'incendio', 1, 'Resuelto', 51218, 'Equipo MVD 1', 'POINT(-56.15077 -34.867638)'),
    ('Inundacion 53 (Montevideo)', 'Incidente en Montevideo', 'inundacion', 3, 'Registrado', 8397, 'Equipo MVD 2', 'POINT(-56.21837 -34.853619)'),
    ('Corte Servicio 54 (Montevideo)', 'Incidente en Montevideo', 'corte_servicio', 1, 'Registrado', 62562, 'Equipo MVD 3', 'POINT(-56.133966 -34.866152)'),
    ('Otro 55 (Montevideo)', 'Incidente en Montevideo', 'otro', 1, 'Cancelado', 49557, 'Equipo MVD 4', 'POINT(-56.229529 -34.812291)'),
    ('Corte Servicio 56 (Montevideo)', 'Incidente en Montevideo', 'corte_servicio', 2, 'Resuelto', 11030, 'Equipo MVD 1', 'POINT(-56.10628 -34.853731)'),
    ('Accidente Transito 57 (Montevideo)', 'Incidente en Montevideo', 'accidente_transito', 1, 'En atención', 18159, 'Equipo MVD 2', 'POINT(-56.252054 -34.815898)'),
    ('Corte Servicio 58 (Montevideo)', 'Incidente en Montevideo', 'corte_servicio', 1, 'En atención', 65394, 'Equipo MVD 3', 'POINT(-56.254632 -34.799143)'),
    ('Corte Servicio 59 (Montevideo)', 'Incidente en Montevideo', 'corte_servicio', 5, 'Derivado', 103645, 'Equipo MVD 4', 'POINT(-56.062593 -34.797999)'),
    ('Otro 60 (Montevideo)', 'Incidente en Montevideo', 'otro', 2, 'Resuelto', 30041, 'Equipo MVD 1', 'POINT(-56.189074 -34.883902)'),
    ('Incendio 61 (Montevideo)', 'Incidente en Montevideo', 'incendio', 2, 'Registrado', 77150, 'Equipo MVD 2', 'POINT(-56.236352 -34.838369)'),
    ('Corte Servicio 62 (Montevideo)', 'Incidente en Montevideo', 'corte_servicio', 1, 'Registrado', 125621, 'Equipo MVD 3', 'POINT(-56.092602 -34.886458)'),
    ('Corte Servicio 63 (Montevideo)', 'Incidente en Montevideo', 'corte_servicio', 1, 'En atención', 93703, 'Equipo MVD 4', 'POINT(-56.261579 -34.869262)'),
    ('Otro 64 (Montevideo)', 'Incidente en Montevideo', 'otro', 1, 'Registrado', 44834, 'Equipo MVD 1', 'POINT(-56.141498 -34.868324)'),
    ('Inundacion 65 (Montevideo)', 'Incidente en Montevideo', 'inundacion', 2, 'Registrado', 108621, 'Equipo MVD 2', 'POINT(-56.127976 -34.89667)'),
    ('Otro 66 (Montevideo)', 'Incidente en Montevideo', 'otro', 1, 'En atención', 88597, 'Equipo MVD 3', 'POINT(-56.140429 -34.892238)'),
    ('Incendio 67 (Montevideo)', 'Incidente en Montevideo', 'incendio', 1, 'Cancelado', 97686, 'Equipo MVD 4', 'POINT(-56.075165 -34.888182)'),
    ('Incendio 68 (Montevideo)', 'Incidente en Montevideo', 'incendio', 2, 'En atención', 61848, 'Equipo MVD 1', 'POINT(-56.238826 -34.856509)'),
    ('Accidente Transito 69 (Montevideo)', 'Incidente en Montevideo', 'accidente_transito', 4, 'Registrado', 48081, 'Equipo MVD 2', 'POINT(-56.151725 -34.828359)'),
    ('Otro 70 (Montevideo)', 'Incidente en Montevideo', 'otro', 1, 'Registrado', 97625, 'Equipo MVD 3', 'POINT(-56.124788 -34.846429)'),
    ('Calle cortada: AVENIDA MILLÁN', 'Tramo de calle cortado (Montevideo)', 'calle_cortada', 3, 'Resuelto', 50170, 'Equipo MVD 2', 'LINESTRING(-56.186845 -34.882931,-56.186938 -34.882762,-56.187046 -34.882568,-56.18726 -34.88217,-56.18741 -34.881913,-56.187495 -34.881749,-56.187546 -34.881651,-56.187563 -34.881596,-56.1876 -34.881352,-56.187618 -34.881223)'),
    ('Calle cortada: AVENIDA DE LA IGLESIA', 'Tramo de calle cortado (Montevideo)', 'calle_cortada', 3, 'En atención', 78174, 'Equipo MVD 3', 'LINESTRING(-56.069568 -34.858528,-56.069545 -34.85856,-56.069515 -34.858586,-56.069477 -34.858605,-56.069435 -34.858616,-56.069391 -34.858619,-56.069348 -34.858613,-56.069307 -34.858599,-56.069272 -34.858577,-56.069244 -34.858549,-56.069226 -34.858516,-56.069217 -34.85848,-56.069219 -34.858444,-56.069231 -34.85841,-56.069253 -34.858378,-56.069284 -34.858352,-56.069322 -34.858333,-56.069363 -34.858322,-56.069407 -34.858319,-56.069451 -34.858325,-56.069491 -34.858339,-56.069527 -34.858361,-56.069555 -34.858389,-56.069573 -34.858422,-56.069582 -34.858457,-56.06958 -34.858494,-56.069568 -34.858528)'),
    ('Calle cortada: AVENIDA CALCAGNO', 'Tramo de calle cortado (Montevideo)', 'calle_cortada', 1, 'En atención', 65025, 'Equipo MVD 4', 'LINESTRING(-56.054362 -34.856887,-56.053494 -34.857501,-56.052928 -34.857917,-56.052584 -34.85817)'),
    ('Calle cortada: AVENIDA LUIS ALBERTO DE HERRERA', 'Tramo de calle cortado (Montevideo)', 'calle_cortada', 3, 'Resuelto', 49392, 'Equipo MVD 1', 'LINESTRING(-56.166175 -34.869939,-56.165594 -34.870298,-56.164546 -34.870955)'),
    ('Calle cortada: URUGUAYANA', 'Tramo de calle cortado (Montevideo)', 'calle_cortada', 4, 'Derivado', 52248, 'Equipo MVD 2', 'LINESTRING(-56.214911 -34.864719,-56.21496 -34.864688,-56.21562 -34.864281,-56.215845 -34.864142)'),
    ('Calle cortada: JUAN RODRÍGUEZ CORREA', 'Tramo de calle cortado (Montevideo)', 'calle_cortada', 2, 'Registrado', 200, 'Equipo MVD 3', 'LINESTRING(-56.190944 -34.867694,-56.189868 -34.867962,-56.188797 -34.86823)'),
    ('Calle cortada: RAMBLA MAHATMA GANDHI', 'Tramo de calle cortado (Montevideo)', 'calle_cortada', 2, 'Derivado', 22892, 'Equipo MVD 4', 'LINESTRING(-56.155544 -34.925479,-56.154809 -34.924936,-56.1545 -34.924709)'),
    ('Calle cortada: WASHINGTON BELTRÁN', 'Tramo de calle cortado (Montevideo)', 'calle_cortada', 4, 'Resuelto', 39480, 'Equipo MVD 1', 'LINESTRING(-56.141636 -34.895122,-56.141891 -34.89408)'),
    ('Área inundada 1 (Montevideo)', 'Incidente en Montevideo', 'inundacion', 2, 'Resuelto', 21419, 'Equipo MVD 2', 'POLYGON((-56.131917 -34.903952,-56.131935 -34.904113,-56.13199 -34.904267,-56.132081 -34.90441,-56.132203 -34.904535,-56.132353 -34.904639,-56.132525 -34.904716,-56.132712 -34.904764,-56.132906 -34.904781,-56.133101 -34.904766,-56.133288 -34.904721,-56.133461 -34.904646,-56.133613 -34.904545,-56.133739 -34.904422,-56.133832 -34.90428,-56.133891 -34.904127,-56.133912 -34.903967,-56.133894 -34.903806,-56.133839 -34.903652,-56.133748 -34.903509,-56.133626 -34.903384,-56.133476 -34.90328,-56.133304 -34.903203,-56.133117 -34.903155,-56.132923 -34.903138,-56.132728 -34.903153,-56.132541 -34.903198,-56.132368 -34.903273,-56.132216 -34.903374,-56.13209 -34.903497,-56.131997 -34.903639,-56.131938 -34.903792,-56.131917 -34.903952))'),
    ('Área inundada 2 (Montevideo)', 'Incidente en Montevideo', 'inundacion', 3, 'Cancelado', 6273, 'Equipo MVD 3', 'POLYGON((-56.155936 -34.924516,-56.155949 -34.924634,-56.15599 -34.924748,-56.156056 -34.924853,-56.156147 -34.924945,-56.156257 -34.925021,-56.156383 -34.925077,-56.15652 -34.925113,-56.156663 -34.925125,-56.156806 -34.925115,-56.156944 -34.925081,-56.157072 -34.925026,-56.157184 -34.924952,-56.157276 -34.924861,-56.157345 -34.924757,-56.157387 -34.924644,-56.157403 -34.924527,-56.15739 -34.924409,-56.157349 -34.924295,-56.157283 -34.92419,-56.157192 -34.924098,-56.157082 -34.924022,-56.156956 -34.923966,-56.156819 -34.92393,-56.156676 -34.923918,-56.156533 -34.923928,-56.156395 -34.923962,-56.156267 -34.924017,-56.156155 -34.924091,-56.156063 -34.924182,-56.155994 -34.924286,-56.155952 -34.924399,-56.155936 -34.924516))'),
    ('Área inundada 3 (Montevideo)', 'Incidente en Montevideo', 'inundacion', 3, 'En atención', 54397, 'Equipo MVD 4', 'POLYGON((-56.197826 -34.911113,-56.197846 -34.911293,-56.197908 -34.911467,-56.19801 -34.911627,-56.198148 -34.911768,-56.198316 -34.911883,-56.198509 -34.91197,-56.198719 -34.912024,-56.198937 -34.912043,-56.199155 -34.912027,-56.199366 -34.911975,-56.19956 -34.911892,-56.199731 -34.911778,-56.199872 -34.911639,-56.199977 -34.91148,-56.200042 -34.911308,-56.200065 -34.911128,-56.200045 -34.910948,-56.199983 -34.910775,-56.199881 -34.910615,-56.199744 -34.910474,-56.199575 -34.910358,-56.199382 -34.910272,-56.199173 -34.910218,-56.198955 -34.910199,-56.198736 -34.910215,-56.198526 -34.910266,-56.198331 -34.91035,-56.198161 -34.910464,-56.19802 -34.910602,-56.197915 -34.910761,-56.19785 -34.910934,-56.197826 -34.911113))'),
    ('Área inundada 4 (Montevideo)', 'Incidente en Montevideo', 'inundacion', 2, 'Cancelado', 24414, 'Equipo MVD 1', 'POLYGON((-56.170292 -34.912948,-56.170312 -34.913124,-56.170372 -34.913293,-56.170471 -34.913449,-56.170606 -34.913586,-56.17077 -34.913699,-56.170958 -34.913783,-56.171162 -34.913835,-56.171374 -34.913854,-56.171587 -34.913838,-56.171793 -34.913789,-56.171982 -34.913707,-56.172149 -34.913596,-56.172286 -34.913461,-56.172388 -34.913306,-56.172452 -34.913138,-56.172475 -34.912963,-56.172455 -34.912787,-56.172395 -34.912618,-56.172296 -34.912462,-56.172161 -34.912325,-56.171997 -34.912212,-56.171809 -34.912128,-56.171605 -34.912076,-56.171393 -34.912057,-56.17118 -34.912073,-56.170974 -34.912122,-56.170785 -34.912204,-56.170618 -34.912315,-56.170481 -34.91245,-56.170379 -34.912605,-56.170315 -34.912773,-56.170292 -34.912948))'),
    ('Área inundada 5 (Montevideo)', 'Incidente en Montevideo', 'inundacion', 3, 'Cancelado', 42890, 'Equipo MVD 2', 'POLYGON((-56.160925 -34.918474,-56.16095 -34.918706,-56.16103 -34.918931,-56.161162 -34.919138,-56.16134 -34.91932,-56.161558 -34.91947,-56.161808 -34.919582,-56.162079 -34.919652,-56.162361 -34.919676,-56.162644 -34.919655,-56.162916 -34.919589,-56.163168 -34.919481,-56.163389 -34.919334,-56.16357 -34.919155,-56.163706 -34.918949,-56.163791 -34.918726,-56.163821 -34.918493,-56.163796 -34.918261,-56.163716 -34.918036,-56.163584 -34.917829,-56.163406 -34.917647,-56.163188 -34.917497,-56.162938 -34.917385,-56.162667 -34.917315,-56.162385 -34.917291,-56.162102 -34.917312,-56.16183 -34.917378,-56.161578 -34.917486,-56.161358 -34.917633,-56.161176 -34.917812,-56.16104 -34.918018,-56.160955 -34.918241,-56.160925 -34.918474))')
    ) AS v(titulo, descripcion, tipo, prioridad, estado, minutos, equipo, wkt)
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
