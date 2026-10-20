-- seed.sql — datos de prueba mínimos para Salto.
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