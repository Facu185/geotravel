-- seed.sql — datos de prueba para Salto: unos pocos hechos a mano y, después, un conjunto moderado repartido por la
-- ciudad y por el departamento (zonas —algunas superpuestas—, recursos e incidentes de todos los tipos y formas) y otro
-- más chico en Montevideo, para recorrer las consultas.
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
-- Datos de prueba para recorrer el sistema, en cantidad moderada y repartidos como en la realidad:
--   * Departamento de Salto: 10 zonas operativas (5 en la ciudad, dos de ellas superpuestas con otras, y 5 en el
--     interior), 36 recursos y 43 incidentes. La ciudad tiene la mayoría, a lo largo de sus calles reales; el resto
--     está en las localidades del departamento (Daymán, Belén, Constitución, Termas del Arapey, Pueblo Lavalleja...).
--   * Montevideo: 7 zonas, 12 recursos y 25 incidentes (el sistema atiende todo el país).
-- Las localidades y las sedes del interior (policlínicas y seccionales policiales) son de OpenStreetMap (ODbL).
-- Es determinista (semilla fija). Va después de la carga de la red vial (seed.sh la carga antes).
-- =====================================================================================================
SELECT setseed(0.2027);

CREATE TEMP TABLE _gen_incidente (id integer PRIMARY KEY);
CREATE TEMP TABLE _gen_recurso (id integer PRIMARY KEY);

-- Zonas de la ciudad: además de las tres de arriba, dos que SÍ se superponen con otras (las zonas operativas
-- pueden superponerse): un punto, un recurso o un incidente puede estar en más de una.
INSERT INTO zona_operativa (nombre, descripcion, nivel_prioridad, responsable, geom) VALUES
('Casco urbano Salto', 'Zona amplia que incluye el centro y varias zonas vecinas', 2, 'Coordinación Salto',
 ST_Transform(ST_MakeEnvelope(-57.985, -31.395, -57.945, -31.375, 4326), 32721)),
('Corredor Av. Uruguay', 'Franja a lo largo de la avenida, superpuesta con el centro', 1, 'Equipo Tránsito',
 ST_Transform(ST_MakeEnvelope(-57.975, -31.389, -57.950, -31.384, 4326), 32721));

-- Zonas del interior del departamento: una alrededor de cada localidad importante (círculo del radio indicado, en metros)
-- y una más grande en el este.
INSERT INTO zona_operativa (nombre, descripcion, nivel_prioridad, responsable, geom)
SELECT z.nombre, z.descripcion, z.prioridad, z.responsable,
       ST_Buffer(ST_Transform(ST_SetSRID(ST_MakePoint(z.lon, z.lat), 4326), 32721), z.radio, 16)
FROM (VALUES
    ('Daymán y Termas del Daymán', 'Zona sur: Daymán y sus termas', 3, 'Equipo Sur', -57.9084, -31.4525, 3500),
    ('Constitución', 'Villa Constitución y su entorno rural', 3, 'Equipo Norte', -57.8494, -31.0672, 4000),
    ('Belén', 'Belén y Chacras de Belén', 4, 'Equipo Norte', -57.7791, -30.7894, 4000),
    ('Termas del Arapey', 'Complejo termal del Arapey', 4, 'Equipo Norte', -57.5232, -30.9474, 5000)
) z(nombre, descripcion, prioridad, responsable, lon, lat, radio);

INSERT INTO zona_operativa (nombre, descripcion, nivel_prioridad, responsable, geom) VALUES
('Interior este (Pueblo Lavalleja y Biassini)', 'Zona rural del este del departamento', 5, 'Equipo Interior',
 ST_Transform(ST_MakeEnvelope(-57.20, -31.30, -56.95, -31.05, 4326), 32721));

-- Calles de Salto por las que anda un auto, solo de la red de la ciudad: la tabla via también trae Concordia (Argentina),
-- del otro lado del río, y por eso se toma solo la red de calles conectada con el centro de Salto. Sirve para ubicar
-- recursos e incidentes sobre una calle (acum = largo acumulado: un punto al azar sobre toda la red, más probable
-- cuanto más larga es la calle).
CREATE TEMP TABLE _calles_salto AS
WITH c AS (
    SELECT gid, geom, tipo, ST_ClusterDBSCAN(geom, 0, 1) OVER () AS red FROM via
)
SELECT gid, geom, ST_Length(geom) AS largo, sum(ST_Length(geom)) OVER (ORDER BY gid) AS acum
FROM c
WHERE red = (SELECT red FROM c ORDER BY geom <-> ST_Transform(ST_SetSRID(ST_MakePoint(-57.9606, -31.3857), 4326), 32721) LIMIT 1)
  AND tipo IN ('CALLE', 'AVENIDA');
CREATE INDEX ON _calles_salto USING gist (geom);
ANALYZE _calles_salto;

-- Recursos de la ciudad: 12 en sedes reales (OpenStreetMap: hospital y centros de salud, estación de bomberos, jefatura y
-- seccional de policía, base de ambulancias y Policía Caminera), cada una en el punto de calle más cercano.
WITH sedes (identificacion, nombre, tipo, estado, descripcion, lon, lat) AS (VALUES
    ('CEN-001', 'Hospital Departamental de Salto',  'centro_atencion', 'Disponible',  'Hospital (sede real)',                 -57.96117, -31.39228),
    ('CEN-002', 'Centro de Asistencia Médica',      'centro_atencion', 'Disponible',  'Centro de salud (sede real)',          -57.96359, -31.38893),
    ('CEN-003', 'Centro Médico Pediátrico',         'centro_atencion', 'En servicio', 'Centro de salud (sede real)',          -57.95339, -31.38884),
    ('CEN-004', 'Centro Médico de Salto',           'centro_atencion', 'Disponible',  'Centro de salud (sede real)',          -57.94953, -31.40363),
    ('BOM-001', 'Bomberos Salto 1',                 'bomberos',        'Disponible',  'Estación de Bomberos (sede real)',     -57.97012, -31.38923),
    ('BOM-002', 'Bomberos Salto 2',                 'bomberos',        'En servicio', 'Estación de Bomberos (sede real)',     -57.96940, -31.38890),
    ('PAT-001', 'Patrulla Jefatura 1',              'patrulla',        'Disponible',  'Jefatura Departamental (sede real)',   -57.97044, -31.38834),
    ('PAT-002', 'Patrulla Seccional Primera',       'patrulla',        'Disponible',  'Seccional Primera (sede real)',        -57.97087, -31.38915),
    ('PAT-003', 'Patrulla Jefatura 2',              'patrulla',        'En servicio', 'Jefatura Departamental (sede real)',   -57.96980, -31.38800),
    ('PAT-004', 'Patrulla Caminera',                'patrulla',        'Disponible',  'Policía Caminera (sede real)',         -57.88446, -31.38356),
    ('AMB-001', 'Ambulancia UCMS',                  'ambulancia',      'Disponible',  'Base de ambulancias UCMS (sede real)', -57.94448, -31.38464),
    ('AMB-002', 'Ambulancia Hospital Departamental','ambulancia',      'Fuera de servicio', 'Base en el hospital (sede real)', -57.96050, -31.39300)
), nuevos AS (
    INSERT INTO recurso (identificacion, nombre, tipo, estado_operativo, descripcion, geom)
    SELECT s.identificacion, s.nombre, s.tipo, s.estado, s.descripcion,
           (SELECT ST_ClosestPoint(c.geom, p.g) FROM _calles_salto c ORDER BY c.geom <-> p.g LIMIT 1)
    FROM sedes s
    CROSS JOIN LATERAL (SELECT ST_Transform(ST_SetSRID(ST_MakePoint(s.lon, s.lat), 4326), 32721) AS g) p
    RETURNING id
)
INSERT INTO _gen_recurso SELECT id FROM nuevos;

-- Móviles de la ciudad: 6 (ambulancias, patrullas y un camión de bomberos) en recorrida por toda la ciudad. Se sortea una
-- calle (más probable cuanto más larga) y un punto sobre ella; si hay otro recurso a menos de 500 m se vuelve a sortear.
-- Estados: 55 % disponible, 30 % en servicio, 15 % fuera de servicio.
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
        SELECT t.tipo, t.base + row_number() OVER (PARTITION BY t.tipo) AS n
        FROM (
            SELECT tipo, base, generate_series(1, cantidad) AS g
            FROM (VALUES ('ambulancia', 2, 2), ('patrulla', 3, 4), ('bomberos', 1, 2)) AS v(tipo, cantidad, base)
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
        VALUES (upper(left(unidad.tipo, 3)) || '-' || lpad(unidad.n::text, 3, '0'),
                initcap(replace(unidad.tipo, '_', ' ')) || ' ' || unidad.n,
                unidad.tipo,
                CASE WHEN sorteo < 0.55 THEN 'Disponible' WHEN sorteo < 0.85 THEN 'En servicio' ELSE 'Fuera de servicio' END,
                'Móvil en recorrida por Salto',
                punto)
        RETURNING id INTO nuevo_id;
        INSERT INTO _gen_recurso VALUES (nuevo_id);
    END LOOP;
END $$;

-- Recursos del interior del departamento: 9 sedes reales de OpenStreetMap (policlínicas y seccionales policiales de
-- las localidades) y 4 unidades en las localidades más grandes, que no tienen sede registrada. No hay calles del interior
-- en la base, así que van en las coordenadas exactas.
WITH interior (identificacion, nombre, tipo, estado, descripcion, lon, lat) AS (VALUES
    ('CEN-D01', 'Policlínica Rural Barrio Albisu',         'centro_atencion', 'Disponible',        'Policlínica (sede real)',           -57.8142, -31.3833),
    ('CEN-D02', 'Policlínica de Garibaldi',                'centro_atencion', 'Disponible',        'Policlínica (sede real)',           -57.8285, -31.3385),
    ('CEN-D03', 'Policlínica MSP de Pueblo Lavalleja',     'centro_atencion', 'En servicio',       'Policlínica (sede real)',           -57.0240, -31.0963),
    ('CEN-D04', 'Policlínica Cuchilla de Guaviyú',         'centro_atencion', 'Disponible',        'Policlínica (sede real)',           -56.6346, -31.0358),
    ('PAT-D01', 'Seccional 10ª Pueblo Lavalleja',          'patrulla',        'Disponible',        'Seccional policial (sede real)',    -57.0245, -31.0957),
    ('PAT-D02', 'Seccional 11ª Sarandí del Arapey',        'patrulla',        'Disponible',        'Seccional policial (sede real)',    -56.2149, -30.9884),
    ('PAT-D03', 'Seccional 16ª Laureles',                  'patrulla',        'Fuera de servicio', 'Seccional policial (sede real)',    -57.5227, -31.5004),
    ('PAT-D04', 'Seccional 12ª Quintana',                  'patrulla',        'Disponible',        'Seccional policial (sede real)',    -56.3940, -31.3503),
    ('PAT-D05', 'Puesto policial de ruta',                 'patrulla',        'En servicio',       'Puesto policial (sede real)',       -57.7045, -31.2863),
    ('AMB-D01', 'Ambulancia Belén',                        'ambulancia',      'Disponible',        'Unidad móvil en Belén',             -57.7791, -30.7894),
    ('AMB-D02', 'Ambulancia Constitución',                 'ambulancia',      'Disponible',        'Unidad móvil en Constitución',      -57.8494, -31.0672),
    ('AMB-D03', 'Ambulancia Termas del Daymán',            'ambulancia',      'En servicio',       'Unidad móvil en Termas del Daymán', -57.9084, -31.4525),
    ('OTR-D01', 'Equipo de apoyo Termas del Arapey',       'otro',            'Disponible',        'Equipo de apoyo en las termas',     -57.5232, -30.9474)
), nuevos AS (
    INSERT INTO recurso (identificacion, nombre, tipo, estado_operativo, descripcion, geom)
    SELECT identificacion, nombre, tipo, estado, descripcion,
           ST_Transform(ST_SetSRID(ST_MakePoint(lon, lat), 4326), 32721)
    FROM interior
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

-- Incidentes del interior del departamento: uno en cada una de 12 localidades (a menos de 1,5 km del centro del pueblo),
-- con el tipo de incidente que es más común en cada lugar, y dos áreas inundadas junto al río.
WITH nuevos AS (
    INSERT INTO incidente (titulo, descripcion, tipo_incidente, prioridad, estado, fecha_hora_registro, equipo_responsable, geom)
    SELECT initcap(replace(l.tipo, '_', ' ')) || ' en ' || l.nombre,
           'Incidente en el interior del departamento de Salto',
           l.tipo,
           1 + floor(random() * random() * 5)::int,
           (ARRAY['Registrado', 'Registrado', 'En atención', 'En atención', 'Derivado', 'Resuelto', 'Resuelto', 'Cancelado'])[1 + floor(random() * 8)::int],
           now() - random() * interval '90 days',
           'Equipo Interior',
           ST_Transform(ST_SetSRID(ST_MakePoint(l.lon + (random() - 0.5) * 0.03, l.lat + (random() - 0.5) * 0.03), 4326), 32721)
    FROM (VALUES
        ('Termas del Daymán', 'incendio',           -57.9084, -31.4525),
        ('Belén',             'accidente_transito', -57.7791, -30.7894),
        ('Constitución',      'corte_servicio',     -57.8494, -31.0672),
        ('Termas del Arapey', 'accidente_transito', -57.5232, -30.9474),
        ('Colonia 18 de Julio', 'incendio',         -57.8740, -31.3563),
        ('Garibaldi',         'otro',               -57.8289, -31.3394),
        ('San Antonio',       'accidente_transito', -57.7669, -31.3574),
        ('Pueblo Lavalleja',  'incendio',           -57.0250, -31.0958),
        ('Biassini',          'corte_servicio',     -57.1263, -31.2776),
        ('Rincón de Valentín', 'accidente_transito', -57.1992, -31.2822),
        ('Campo de Todos',    'otro',               -57.6146, -31.5593),
        ('Laureles',          'incendio',           -57.5260, -31.4988)
    ) l(nombre, tipo, lon, lat)
    RETURNING id
)
INSERT INTO _gen_incidente SELECT id FROM nuevos;

WITH nuevos AS (
    INSERT INTO incidente (titulo, descripcion, tipo_incidente, prioridad, estado, fecha_hora_registro, equipo_responsable, geom)
    SELECT 'Área inundada en ' || a.nombre,
           'Área afectada por la crecida del río Uruguay',
           'inundacion',
           1 + floor(random() * 3)::int,
           (ARRAY['Registrado', 'En atención', 'Resuelto'])[1 + floor(random() * 3)::int],
           now() - random() * interval '45 days',
           'Equipo Interior',
           ST_Buffer(ST_Transform(ST_SetSRID(ST_MakePoint(a.lon, a.lat), 4326), 32721), 150 + random() * 100, 8)
    FROM (VALUES ('Belén', -57.8050, -30.7900), ('Constitución', -57.8900, -31.0700)) a(nombre, lon, lat)
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
DROP TABLE _gen_recurso;
ANALYZE zona_operativa;
ANALYZE recurso;
ANALYZE incidente;

-- =====================================================================================================
-- Montevideo: el sistema atiende todo el país, y la defensa es en Salto, pero también tiene que haber datos en
-- otro lugar. 7 zonas, 12 recursos y 25 incidentes (puntos, líneas y polígonos) repartidos entre Ciudad Vieja y
-- Pocitos / Cordón / Tres Cruces. No hay calles ni puertas propias de Montevideo (las direcciones de ahí las resuelve
-- la IDE), así que las líneas son tramos rectos de ~200 m, no están sobre calles reales.
-- =====================================================================================================
SELECT setseed(0.2028);

CREATE TEMP TABLE _gen_incidente (id integer PRIMARY KEY);
CREATE TEMP TABLE _gen_recurso (id integer PRIMARY KEY);

-- Zonas: grilla de 3 x 2 celdas de ~2,3 x 2,1 km.
INSERT INTO zona_operativa (nombre, descripcion, nivel_prioridad, responsable, geom)
SELECT 'Montevideo Zona ' || chr(65 + j) || (i + 1),
       'Zona operativa de Montevideo',
       1 + (i * 2 + j * 3) % 5,
       'Equipo MVD ' || (1 + (i + j) % 4),
       ST_Transform(ST_MakeEnvelope(-56.195 + i * 0.0250, -34.900 + j * 0.0200,
                                    -56.195 + i * 0.0250 + 0.0240, -34.900 + j * 0.0200 + 0.0190, 4326), 32721)
FROM generate_series(0, 2) i, generate_series(0, 1) j;

-- Una zona que se superpone con varias de la grilla.
INSERT INTO zona_operativa (nombre, descripcion, nivel_prioridad, responsable, geom) VALUES
('Montevideo Ciudad Vieja y Centro', 'Zona amplia superpuesta con varias zonas vecinas', 2, 'Coordinación MVD',
 ST_Transform(ST_MakeEnvelope(-56.200, -34.900, -56.165, -34.885, 4326), 32721));

-- Recursos: 12 puntos al azar sobre la misma área, de todos los tipos y estados.
WITH nuevos AS (
    INSERT INTO recurso (identificacion, nombre, tipo, estado_operativo, descripcion, geom)
    SELECT upper(left(tipo, 3)) || '-M' || lpad(g::text, 3, '0'),
           initcap(replace(tipo, '_', ' ')) || ' MVD ' || g,
           tipo,
           (ARRAY['Disponible', 'Disponible', 'En servicio', 'Fuera de servicio'])[1 + g % 4],
           'Recurso de emergencia en Montevideo',
           ST_Transform(ST_SetSRID(ST_MakePoint(-56.195 + random() * 0.075, -34.900 + random() * 0.04), 4326), 32721)
    FROM (
        SELECT g, (ARRAY['ambulancia', 'bomberos', 'patrulla', 'centro_atencion', 'otro'])[1 + g % 5] AS tipo
        FROM generate_series(1, 12) g
    ) r
    RETURNING id
)
INSERT INTO _gen_recurso SELECT id FROM nuevos;

-- Incidentes puntuales: 20, repartidos por toda el área.
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
           ST_Transform(ST_SetSRID(ST_MakePoint(-56.195 + random() * 0.075, -34.900 + random() * 0.040), 4326), 32721)
    FROM (
        SELECT g, (ARRAY['accidente_transito', 'incendio', 'corte_servicio', 'inundacion', 'otro'])[1 + floor(random() * 5)::int] AS tipo
        FROM generate_series(1, 20) g
    ) i
    RETURNING id
)
INSERT INTO _gen_incidente SELECT id FROM nuevos;

-- Calles cortadas: 3 incidentes de LÍNEA (tramos rectos de ~200 m).
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
        FROM generate_series(1, 3) g
    ) tramos
    RETURNING id
)
INSERT INTO _gen_incidente SELECT id FROM nuevos;

-- Inundaciones: 2 incidentes de POLÍGONO (áreas de 60 a 140 m de radio).
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
    FROM generate_series(1, 2) g
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
    WHERE rec.estado_operativo <> 'Fuera de servicio'
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
