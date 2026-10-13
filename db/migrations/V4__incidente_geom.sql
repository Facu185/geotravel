-- V4__incidente_geom.sql: Permite que los incidentes acepten geometrías genéricas (puntos, líneas y polígonos)
ALTER TABLE incidente ALTER COLUMN geom TYPE geometry(Geometry, 32721);

