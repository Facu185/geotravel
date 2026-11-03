-- P2: funciones de rutas en PostgreSQL/pgRouting.
-- NO es migracion Flyway: requiere que P1 haya instalado la extension y construido
-- el grafo vial. Ver docs/P2_PGROUTING.md antes de aplicar.
-- Tablas exigidas: red_vial_arco y red_vial_vertice (EPSG:32721).

CREATE OR REPLACE FUNCTION public.p2_calcular_ruta(
    p_origen_lon double precision,
    p_origen_lat double precision,
    p_destino_lon double precision,
    p_destino_lat double precision,
    p_criterio text DEFAULT 'mas_rapida'
)
RETURNS TABLE (
    distancia_m double precision,
    duracion_s double precision,
    geometria_geojson text,
    ajuste_origen_m double precision,
    ajuste_destino_m double precision
)
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_origen geometry(Point,32721);
    v_destino geometry(Point,32721);
    v_inicio bigint;
    v_fin bigint;
    v_inicio_geom geometry(Point,32721);
    v_fin_geom geometry(Point,32721);
    v_ajuste_inicio double precision;
    v_ajuste_fin double precision;
    v_cost text;
    v_reverse text;
    v_edges_sql text;
BEGIN
    IF p_criterio IS NULL OR p_criterio NOT IN ('mas_rapida', 'mas_corta') THEN
        RAISE EXCEPTION 'criterio invalido: %', p_criterio USING ERRCODE = '22023';
    END IF;
    IF p_origen_lon IS NULL OR p_origen_lat IS NULL
       OR p_destino_lon IS NULL OR p_destino_lat IS NULL
       OR NOT (p_origen_lon BETWEEN -180 AND 180)
       OR NOT (p_destino_lon BETWEEN -180 AND 180)
       OR NOT (p_origen_lat BETWEEN -90 AND 90)
       OR NOT (p_destino_lat BETWEEN -90 AND 90) THEN
        RAISE EXCEPTION 'coordenadas invalidas' USING ERRCODE = '22023';
    END IF;

    v_origen := ST_Transform(ST_SetSRID(ST_MakePoint(p_origen_lon, p_origen_lat), 4326), 32721);
    v_destino := ST_Transform(ST_SetSRID(ST_MakePoint(p_destino_lon, p_destino_lat), 4326), 32721);

    -- Ajuste al nodo mas proximo de la red. No supone que todo punto esta sobre calle.
    SELECT v.id, v.geom, ST_Distance(v.geom, v_origen)
      INTO v_inicio, v_inicio_geom, v_ajuste_inicio
      FROM public.red_vial_vertice v
      ORDER BY v.geom <-> v_origen, v.id LIMIT 1;
    SELECT v.id, v.geom, ST_Distance(v.geom, v_destino)
      INTO v_fin, v_fin_geom, v_ajuste_fin
      FROM public.red_vial_vertice v
      ORDER BY v.geom <-> v_destino, v.id LIMIT 1;

    IF v_inicio IS NULL OR v_fin IS NULL
       OR v_ajuste_inicio > 250 OR v_ajuste_fin > 250 THEN
        RETURN; -- Fuera de cobertura de la red, o nodos inexistentes.
    END IF;

    IF v_inicio = v_fin THEN
        RETURN QUERY SELECT 0.0::double precision, 0.0::double precision,
            ST_AsGeoJSON(ST_MakeLine(ST_Transform(v_inicio_geom,4326),
                                     ST_Transform(v_fin_geom,4326)), 6),
            v_ajuste_inicio, v_ajuste_fin;
        RETURN;
    END IF;

    IF p_criterio = 'mas_corta' THEN
        v_cost := 'cost_m';
        v_reverse := 'reverse_cost_m';
    ELSE
        v_cost := 'cost_s';
        v_reverse := 'reverse_cost_s';
    END IF;

    -- Columnas de costo escogidas entre identificadores constantes, no entrada SQL libre.
    v_edges_sql := format(
        'SELECT id, source, target, %I AS cost, %I AS reverse_cost FROM public.red_vial_arco',
        v_cost, v_reverse);

    RETURN QUERY
    WITH camino AS (
        SELECT p.path_seq, p.node, p.edge
        FROM pgr_dijkstra(v_edges_sql, v_inicio, v_fin, directed := true) p
        WHERE p.edge <> -1
    ), tramos AS (
        SELECT p.path_seq,
               ST_Transform(CASE WHEN p.node = a.source THEN a.geom
                                 ELSE ST_Reverse(a.geom) END, 4326) AS geom,
               ST_Length(a.geom) AS longitud,
               CASE WHEN p.node = a.source THEN a.cost_s
                    ELSE a.reverse_cost_s END AS segundos
        FROM camino p JOIN public.red_vial_arco a ON a.id = p.edge
    ), resumen AS (
        SELECT SUM(t.longitud)::double precision AS metros,
               SUM(t.segundos)::double precision AS segundos,
               ST_MakeLine(ARRAY_AGG(t.geom ORDER BY t.path_seq)) AS linea
        FROM tramos t
    )
    SELECT r.metros, r.segundos, ST_AsGeoJSON(r.linea, 6),
           v_ajuste_inicio, v_ajuste_fin
    FROM resumen r
    WHERE r.linea IS NOT NULL AND r.segundos >= 0;
END;
$$;
