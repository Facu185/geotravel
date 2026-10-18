-- Borra los datos de db/pruebas/carga-masiva.sql (todo lo que empieza con "PRUEBA-CARGA-").
--   docker compose exec -T db psql -U geotravel -d geotravel < ../db/pruebas/carga-masiva-borrar.sql
DELETE FROM recurso WHERE identificacion LIKE 'PRUEBA-CARGA-%';
DELETE FROM zona_operativa WHERE nombre LIKE 'PRUEBA-CARGA-%';
