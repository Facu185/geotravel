-- seed.sql — datos de prueba mínimos para tener algo visualizable desde el día uno.
-- Las geometrías se definen en lon/lat (EPSG:4326, coordenadas reales de Montevideo) y se
-- transforman a EPSG:32721, el SRID que usa la base (mismo que los Prácticos del curso).
-- Ejecutar después de las migraciones (V1, V2).

-- Zonas: rectángulos que no se superponen entre sí
INSERT INTO zona_turistica (nombre, descripcion, nivel_atractivo, observaciones, geom) VALUES
('Ciudad Vieja', 'Casco histórico de Montevideo', 1, 'Alta concentración de patrimonio',
 ST_Transform(ST_MakeEnvelope(-56.2170, -34.9130, -56.1990, -34.9040, 4326), 32721)),
('Parque Rodó', 'Parque y zona cultural sobre la rambla', 2, NULL,
 ST_Transform(ST_MakeEnvelope(-56.1720, -34.9180, -56.1650, -34.9120, 4326), 32721)),
('Pocitos', 'Barrio residencial y de playa', 3, NULL,
 ST_Transform(ST_MakeEnvelope(-56.1560, -34.9180, -56.1440, -34.9070, 4326), 32721));

-- Atracciones (cada una cae dentro de su zona)
INSERT INTO atraccion (nombre, descripcion, clasificacion, geom) VALUES
('Mercado del Puerto', 'Mercado gastronómico histórico', 'gastronomica',
 ST_Transform(ST_SetSRID(ST_MakePoint(-56.2137, -34.9075), 4326), 32721)),
('Plaza Independencia', 'Plaza principal, límite de Ciudad Vieja', 'historica',
 ST_Transform(ST_SetSRID(ST_MakePoint(-56.2010, -34.9066), 4326), 32721)),
('Teatro Solís', 'Teatro histórico', 'cultural',
 ST_Transform(ST_SetSRID(ST_MakePoint(-56.2034, -34.9069), 4326), 32721)),
('Museo Nacional de Artes Visuales', 'Museo dentro del Parque Rodó', 'cultural',
 ST_Transform(ST_SetSRID(ST_MakePoint(-56.1685, -34.9158), 4326), 32721)),
('Playa Pocitos', 'Playa urbana', 'natural',
 ST_Transform(ST_SetSRID(ST_MakePoint(-56.1495, -34.9128), 4326), 32721)),
('Rambla de Pocitos', 'Paseo costero', 'natural',
 ST_Transform(ST_SetSRID(ST_MakePoint(-56.1510, -34.9118), 4326), 32721));

-- Recorridos
INSERT INTO recorrido (nombre, descripcion, duracion_min, guia_responsable, tipo_experiencia, mes_inicio, mes_fin, estado) VALUES
('Centro histórico',      'Recorrido a pie por Ciudad Vieja', 120, 'Ana Ríos',    'historica',    1, 12, 'Disponible'),
('Sabores de Montevideo', 'Recorrido gastronómico',            90, 'Bruno Silva', 'gastronomica', 3, 11, 'Disponible'),
('Costa y cultura',       'Parque Rodó + rambla de Pocitos',  150, 'Carla Núñez', 'cultural',    11, 2, 'Pendiente');

-- Itinerarios (recorrido_atraccion)
INSERT INTO recorrido_atraccion (recorrido_id, atraccion_id, orden) VALUES
(1, 2, 1), (1, 3, 2), (1, 1, 3),   -- Centro histórico: Plaza Independencia -> Teatro Solís -> Mercado del Puerto
(2, 1, 1),                         -- Sabores de Montevideo: Mercado del Puerto
(3, 4, 1), (3, 5, 2), (3, 6, 3);   -- Costa y cultura: MNAV -> Playa Pocitos -> Rambla de Pocitos
