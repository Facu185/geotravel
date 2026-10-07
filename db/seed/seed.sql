-- seed.sql — datos de prueba mínimos para tener algo visualizable desde el día uno.
-- Las geometrías se definen en lon/lat (EPSG:4326, coordenadas reales de Montevideo) y se
-- transforman a EPSG:32721, el SRID que usa la base.
-- Ejecutar después de la migración V1.

-- Zonas operativas: rectángulos que no se superponen entre sí
INSERT INTO zona_operativa (nombre, descripcion, nivel_prioridad, responsable, observaciones, geom) VALUES
('Centro',  'Zona operativa del centro y Ciudad Vieja', 1, 'Equipo Centro',  'Alta densidad de tránsito',
 ST_Transform(ST_MakeEnvelope(-56.2170, -34.9130, -56.1990, -34.9040, 4326), 32721)),
('Cordón',  'Zona operativa de Cordón y Parque Rodó',   2, 'Equipo Cordón',  NULL,
 ST_Transform(ST_MakeEnvelope(-56.1720, -34.9180, -56.1650, -34.9120, 4326), 32721)),
('Pocitos', 'Zona operativa costera de Pocitos',         3, 'Equipo Costa',   NULL,
 ST_Transform(ST_MakeEnvelope(-56.1560, -34.9180, -56.1440, -34.9070, 4326), 32721));

-- Recursos (ambulancias, bomberos, patrullas), uno por zona
INSERT INTO recurso (identificacion, nombre, tipo, estado_operativo, descripcion, geom) VALUES
('AMB-12', 'Ambulancia 12',      'ambulancia',      'Disponible',      'Base Centro',
 ST_Transform(ST_SetSRID(ST_MakePoint(-56.2060, -34.9080), 4326), 32721)),
('BOM-05', 'Bomberos 05',        'bomberos',        'En servicio',     'Cuartel Cordón',
 ST_Transform(ST_SetSRID(ST_MakePoint(-56.1690, -34.9155), 4326), 32721)),
('PAT-305','Patrulla 305',       'patrulla',        'Disponible',      'Recorrida Pocitos',
 ST_Transform(ST_SetSRID(ST_MakePoint(-56.1500, -34.9120), 4326), 32721)),
('CAT-01', 'Centro de Atención Norte', 'centro_atencion', 'Disponible', 'Centro fijo',
 ST_Transform(ST_SetSRID(ST_MakePoint(-56.2020, -34.9070), 4326), 32721));

-- Incidentes: se crean en 'Registrado' (el trigger deja ese primer registro en el
-- historial) y después se los hace avanzar "a mano" con UPDATE + INSERT en
-- historial_estado, simulando lo que haría la aplicación al usar /avanzar.
-- El incidente 2 se deja tal cual, recién registrado, sin avanzar.
INSERT INTO incidente (titulo, descripcion, tipo_incidente, prioridad, equipo_responsable, geom) VALUES
('Choque en Av. 18 de Julio',     'Accidente de tránsito con heridos leves', 'accidente_transito', 1, 'Equipo Centro',
 ST_Transform(ST_SetSRID(ST_MakePoint(-56.2010, -34.9066), 4326), 32721)),
('Incendio en local comercial',   'Foco de incendio en Ciudad Vieja',        'incendio',           1, 'Equipo Centro',
 ST_Transform(ST_SetSRID(ST_MakePoint(-56.2034, -34.9069), 4326), 32721)),
('Corte de suministro eléctrico', 'Corte en varias cuadras de Cordón',       'corte_servicio',     3, 'Equipo Cordón',
 ST_Transform(ST_SetSRID(ST_MakePoint(-56.1685, -34.9158), 4326), 32721)),
('Anegamiento en rambla',         'Acumulación de agua tras la lluvia',      'inundacion',         2, 'Equipo Costa',
 ST_Transform(ST_SetSRID(ST_MakePoint(-56.1510, -34.9118), 4326), 32721));

-- Asignación de recursos a incidentes (incidente_recurso)
INSERT INTO incidente_recurso (incidente_id, recurso_id) VALUES
(1, 1),           -- Choque en 18 de Julio -> Ambulancia 12
(2, 2),           -- Incendio -> Bomberos 05
(3, 3),           -- Corte de suministro -> Patrulla 305
(4, 3);           -- Anegamiento -> Patrulla 305 (ya resuelto)

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
