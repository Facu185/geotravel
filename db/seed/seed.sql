-- seed.sql — datos de prueba mínimos para tener algo visualizable desde el día uno.
-- Coordenadas aproximadas en Montevideo, EPSG:32721 (mismo SRID que los Prácticos del curso).
-- Ejecutar después de V1__init.sql: psql -d geotravel -f seed.sql

-- Zonas (polígonos ~400x400m, sin superponerse entre sí)
INSERT INTO zona_turistica (nombre, descripcion, nivel_atractivo, observaciones, geom) VALUES
('Ciudad Vieja', 'Casco histórico de Montevideo', 1, 'Alta concentración de patrimonio',
 ST_GeomFromText('POLYGON((565800 6136300, 566200 6136300, 566200 6136700, 565800 6136700, 565800 6136300))', 32721)),
('Parque Rodó', 'Parque y zona cultural sobre la rambla', 2, NULL,
 ST_GeomFromText('POLYGON((569300 6135600, 569700 6135600, 569700 6136000, 569300 6136000, 569300 6135600))', 32721)),
('Pocitos', 'Barrio residencial y de playa', 3, NULL,
 ST_GeomFromText('POLYGON((572800 6134300, 573200 6134300, 573200 6134700, 572800 6134700, 572800 6134300))', 32721));

-- Atracciones (puntos dentro o cerca de cada zona)
INSERT INTO atraccion (nombre, descripcion, clasificacion, geom) VALUES
('Mercado del Puerto', 'Mercado gastronómico histórico', 'gastronomica',
 ST_GeomFromText('POINT(565950 6136500)', 32721)),
('Plaza Independencia', 'Plaza principal, límite de Ciudad Vieja', 'historica',
 ST_GeomFromText('POINT(566100 6136350)', 32721)),
('Teatro Solís', 'Teatro histórico', 'cultural',
 ST_GeomFromText('POINT(566050 6136400)', 32721)),
('Museo Zorrilla', 'Casa museo en Parque Rodó', 'cultural',
 ST_GeomFromText('POINT(569500 6135800)', 32721)),
('Playa Pocitos', 'Playa urbana', 'natural',
 ST_GeomFromText('POINT(573000 6134500)', 32721)),
('Rambla de Pocitos', 'Paseo costero', 'natural',
 ST_GeomFromText('POINT(572950 6134550)', 32721));

-- Recorridos
INSERT INTO recorrido (nombre, descripcion, duracion_min, guia_responsable, tipo_experiencia, mes_inicio, mes_fin, estado) VALUES
('Centro histórico',   'Recorrido a pie por Ciudad Vieja',       120, 'Ana Ríos',      'historica',     1, 12, 'Disponible'),
('Sabores de Montevideo', 'Recorrido gastronómico',                90,  'Bruno Silva',   'gastronomica',  3, 11, 'Disponible'),
('Costa y cultura',    'Parque Rodó + rambla de Pocitos',         150, 'Carla Núñez',   'cultural',      11, 2, 'Pendiente');

-- Itinerarios (recorrido_atraccion)
INSERT INTO recorrido_atraccion (recorrido_id, atraccion_id, orden) VALUES
(1, 2, 1), (1, 3, 2), (1, 1, 3),   -- Centro histórico: Plaza Independencia -> Teatro Solís -> Mercado del Puerto
(2, 1, 1),                         -- Sabores de Montevideo: Mercado del Puerto
(3, 4, 1), (3, 5, 2), (3, 6, 3);   -- Costa y cultura: Museo Zorrilla -> Playa Pocitos -> Rambla de Pocitos
