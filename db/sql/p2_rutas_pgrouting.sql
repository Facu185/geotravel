-- p2_calcular_ruta: la ruta por calles entre dos puntos, calculada en PostgreSQL con pgRouting sobre la red vial
-- de OpenStreetMap de todo Uruguay (tablas red_vial_arco y red_vial_vertice, ver db/sql/red_vial_generar.sql).
-- NO es una migración de Flyway: la aplica infra/init/seed.sh en cada arranque (es repetible).
--
-- Cómo calcula:
--   1. AJUSTE A LA CALLE. Cada extremo se engancha al punto de la calle más cercana (la proyección sobre el arco, no a
--      la esquina más próxima): se corta virtualmente ese arco en dos y el punto pasa a ser un vértice. La ruta sale y
--      llega exactamente a ese punto, y hay un tramo recto corto (el "conector") entre el recurso o el incidente y la
--      calle, que cuenta en la distancia y el tiempo. Si un extremo queda a más de 500 m de cualquier calle, no hay ruta.
--   2. SENTIDOS. Los arcos de mano única tienen costo negativo en el sentido prohibido (convención de pgRouting) y
--      Dijkstra se calcula dirigido.
--   3. UN SOLO CAMINO, según el criterio (quinto parámetro):
--        'tiempo' (por defecto): el de menor duración (costo cost_s: largo / velocidad de cada calle + demora por esquina);
--        'distancia': el de menor cantidad de metros (costo cost_m: el largo de cada arco), aunque tarde más.
--      Sea cual sea el criterio, se informan las dos cosas del camino elegido: la distancia (suma de los largos) y la
--      duración (suma de cost_s). Con 'tiempo' la distancia es la del camino más rápido, que puede no ser la más corta.
--   4. ESCALA. Para no armar el grafo de todo el país en cada pedido, se usan solo los arcos dentro de una caja alrededor de
--      los dos puntos (con índice espacial), que se agranda si no aparece camino.
--   5. LAS CALLES DEL RECORRIDO: se devuelve, en orden, el nombre de cada calle por la que pasa la ruta y cuántos metros.
-- Limitaciones: no se modelan giros prohibidos ni semáforos (solo una demora fija por esquina) ni el tránsito en vivo.

DROP FUNCTION IF EXISTS public.p2_calcular_ruta(double precision, double precision, double precision, double precision, text);
DROP FUNCTION IF EXISTS public.p2_calcular_ruta(double precision, double precision, double precision, double precision);
DROP FUNCTION IF EXISTS public.p2_calcular_ruta(double precision, double precision, double precision, double precision, text);

CREATE OR REPLACE FUNCTION public.p2_calcular_ruta(
    p_origen_lon double precision,
    p_origen_lat double precision,
    p_destino_lon double precision,
    p_destino_lat double precision,
    p_criterio text DEFAULT 'tiempo'
)
RETURNS TABLE (
    distancia_m double precision,
    duracion_s double precision,
    geometria_geojson text,
    ajuste_origen_m double precision,
    ajuste_destino_m double precision,
    calles_json text
)
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    c_ajuste_max   CONSTANT double precision := 500;        -- metros hasta la calle más cercana
    c_conector_m_s CONSTANT double precision := 20 / 3.6;   -- velocidad en el conector (m/s)
    v_o geometry;
    v_d geometry;
    a_o record;
    a_d record;
    v_f_o double precision;
    v_f_d double precision;
    v_q_o geometry;
    v_q_d geometry;
    v_aj_o double precision;
    v_aj_d double precision;
    v_directa double precision;
    v_margenes double precision[];
    v_margen double precision;
    v_caja text;
    v_ext text;
    v_dist double precision;
    v_dur double precision;
    v_geoms geometry[];
    v_calles jsonb;
    v_partes geometry[];
    v_linea geometry;
    v_col text;   -- columna de costo de Dijkstra según el criterio
    v_rcol text;  -- y la del sentido contrario
BEGIN
    IF p_criterio = 'tiempo' THEN
        v_col := 'cost_s'; v_rcol := 'reverse_cost_s';
    ELSIF p_criterio = 'distancia' THEN
        v_col := 'cost_m'; v_rcol := 'reverse_cost_m';
    ELSE
        RAISE EXCEPTION 'criterio invalido (tiempo o distancia)' USING ERRCODE = '22023';
    END IF;

    IF p_origen_lon IS NULL OR p_origen_lat IS NULL OR p_destino_lon IS NULL OR p_destino_lat IS NULL
       OR NOT (p_origen_lon BETWEEN -180 AND 180) OR NOT (p_destino_lon BETWEEN -180 AND 180)
       OR NOT (p_origen_lat BETWEEN -90 AND 90) OR NOT (p_destino_lat BETWEEN -90 AND 90) THEN
        RAISE EXCEPTION 'coordenadas invalidas' USING ERRCODE = '22023';
    END IF;

    v_o := ST_Transform(ST_SetSRID(ST_MakePoint(p_origen_lon, p_origen_lat), 4326), 32721);
    v_d := ST_Transform(ST_SetSRID(ST_MakePoint(p_destino_lon, p_destino_lat), 4326), 32721);

    -- 1. Ajuste de cada extremo a la calle más cercana (solo redes conectadas grandes: no a una calle aislada).
    SELECT a.id, a.geom INTO a_o FROM public.red_vial_arco a WHERE a.componente_grande ORDER BY a.geom <-> v_o LIMIT 1;
    IF NOT FOUND THEN RETURN; END IF;
    SELECT a.id, a.geom INTO a_d FROM public.red_vial_arco a WHERE a.componente_grande ORDER BY a.geom <-> v_d LIMIT 1;
    IF NOT FOUND THEN RETURN; END IF;

    v_f_o := LEAST(0.9995, GREATEST(0.0005, ST_LineLocatePoint(a_o.geom, v_o)));
    v_f_d := LEAST(0.9995, GREATEST(0.0005, ST_LineLocatePoint(a_d.geom, v_d)));
    v_q_o := ST_LineInterpolatePoint(a_o.geom, v_f_o);
    v_q_d := ST_LineInterpolatePoint(a_d.geom, v_f_d);
    v_aj_o := ST_Distance(v_q_o, v_o);
    v_aj_d := ST_Distance(v_q_d, v_d);
    IF v_aj_o > c_ajuste_max OR v_aj_d > c_ajuste_max THEN
        RETURN; -- fuera de la red vial
    END IF;
    v_directa := ST_Distance(v_q_o, v_q_d);

    -- Los dos extremos en el mismo lugar de la calle: solo los conectores.
    IF v_directa < 1 THEN
        v_partes := ARRAY[]::geometry[];
        IF v_aj_o > 0.5 THEN v_partes := v_partes || ST_MakeLine(v_o, v_q_o); END IF;
        IF v_aj_d > 0.5 THEN v_partes := v_partes || ST_MakeLine(v_q_d, v_d); END IF;
        v_linea := CASE WHEN cardinality(v_partes) > 0 THEN ST_MakeLine(v_partes)
                        ELSE ST_MakeLine(v_o, v_d) END;
        RETURN QUERY SELECT v_aj_o + v_aj_d + v_directa,
                            (v_aj_o + v_aj_d + v_directa) / c_conector_m_s,
                            ST_AsGeoJSON(ST_Transform(ST_SetSRID(v_linea, 32721), 4326), 6),
                            v_aj_o, v_aj_d, '[]'::text;
        RETURN;
    END IF;

    -- 4. Cajas cada vez más grandes alrededor de los dos puntos; la última, sin límite.
    v_margenes := ARRAY[3000 + 0.5 * v_directa, 20000 + 3 * v_directa, NULL];

    FOREACH v_margen IN ARRAY v_margenes LOOP
        v_caja := CASE WHEN v_margen IS NULL THEN 'true'
                       ELSE format('a.geom && %L::geometry',
                                   ST_Expand(ST_Envelope(ST_Collect(v_q_o, v_q_d)), v_margen)::text) END;

        -- Los arcos de la caja, más los dos arcos ajustados cortados en el punto (vértices virtuales -1 y -2).
        v_ext := format($ext$
            WITH cortes(arco, pid, f) AS (
                VALUES (%1$s::bigint, -1::bigint, %2$s::float8), (%3$s::bigint, -2::bigint, %4$s::float8)
            ),
            usados AS (SELECT DISTINCT arco FROM cortes),
            nodos AS (
                SELECT a.id AS arco, a.source AS nodo, 0.0::float8 AS f FROM public.red_vial_arco a JOIN usados u ON u.arco = a.id
                UNION ALL SELECT arco, pid, f FROM cortes
                UNION ALL SELECT a.id, a.target, 1.0::float8 FROM public.red_vial_arco a JOIN usados u ON u.arco = a.id
            ),
            tramos AS (
                SELECT arco, nodo AS source, lead(nodo) OVER w AS target, f AS f1, lead(f) OVER w AS f2
                FROM nodos WINDOW w AS (PARTITION BY arco ORDER BY f, nodo DESC)
            ),
            piezas AS (
                SELECT (-(100 + row_number() OVER (ORDER BY t.arco, t.f1)))::bigint AS id, t.source, t.target,
                       ST_LineSubstring(a.geom, t.f1, t.f2) AS geom, a.nombre,
                       CASE WHEN a.%6$s < 0 THEN -1 ELSE a.%6$s * (t.f2 - t.f1) END AS cost,
                       CASE WHEN a.%7$s < 0 THEN -1 ELSE a.%7$s * (t.f2 - t.f1) END AS reverse_cost,
                       CASE WHEN a.cost_s < 0 THEN -1 ELSE a.cost_s * (t.f2 - t.f1) END AS dur,
                       CASE WHEN a.reverse_cost_s < 0 THEN -1 ELSE a.reverse_cost_s * (t.f2 - t.f1) END AS rdur
                FROM tramos t JOIN public.red_vial_arco a ON a.id = t.arco
                WHERE t.target IS NOT NULL AND t.f2 > t.f1
            )
            SELECT a.id, a.source, a.target, a.geom, a.nombre, a.%6$s AS cost, a.%7$s AS reverse_cost,
                   a.cost_s AS dur, a.reverse_cost_s AS rdur
            FROM public.red_vial_arco a
            WHERE %5$s AND a.id NOT IN (SELECT arco FROM usados)
            UNION ALL
            SELECT id, source, target, geom, nombre, cost, reverse_cost, dur, rdur FROM piezas
        $ext$, a_o.id, v_f_o, a_d.id, v_f_d, v_caja, v_col, v_rcol);

        -- 2 y 3. Dijkstra dirigido, de un vértice virtual al otro.
        EXECUTE format($q$
            WITH camino AS (
                SELECT p.seq AS path_seq, p.node, p.edge  -- seq (no path_seq): en pgRouting 4 el primer tramo repite path_seq
                FROM pgr_dijkstra(%L, -1::bigint, -2::bigint, true) p
                WHERE p.edge <> -1
            ),
            ext AS (%s),
            tramos AS (
                SELECT c.path_seq, e.nombre,
                       CASE WHEN c.node = e.source THEN e.geom ELSE ST_Reverse(e.geom) END AS geom,
                       CASE WHEN c.node = e.source THEN e.dur ELSE e.rdur END AS seg
                FROM camino c JOIN ext e ON e.id = c.edge
            ),
            grupos AS (
                SELECT path_seq, nombre, ST_Length(geom) AS metros,
                       sum(CASE WHEN nombre IS DISTINCT FROM previo THEN 1 ELSE 0 END) OVER (ORDER BY path_seq) AS g
                FROM (SELECT *, lag(nombre) OVER (ORDER BY path_seq) AS previo FROM tramos) t
            ),
            calles AS (
                SELECT g, min(path_seq) AS orden, max(nombre) AS nombre, sum(metros) AS metros FROM grupos GROUP BY g
            )
            SELECT (SELECT sum(ST_Length(geom)) FROM tramos),
                   (SELECT sum(seg) FROM tramos),
                   (SELECT array_agg(geom ORDER BY path_seq) FROM tramos),
                   (SELECT jsonb_agg(jsonb_build_object('calle', COALESCE(nombre, '(sin nombre)'), 'metros', round(metros))
                                     ORDER BY orden) FROM calles)
        $q$, format('SELECT id, source, target, cost, reverse_cost FROM (%s) q', v_ext), v_ext)
        INTO v_dist, v_dur, v_geoms, v_calles;

        EXIT WHEN v_geoms IS NOT NULL;
    END LOOP;

    IF v_geoms IS NULL THEN
        RETURN; -- no hay camino (por ejemplo, un extremo en una red aislada de la otra)
    END IF;

    -- La línea completa: conector de salida + calles + conector de llegada (así toca los dos marcadores).
    v_partes := ARRAY[]::geometry[];
    IF v_aj_o > 0.5 THEN v_partes := v_partes || ST_MakeLine(v_o, v_q_o); END IF;
    v_partes := v_partes || v_geoms;
    IF v_aj_d > 0.5 THEN v_partes := v_partes || ST_MakeLine(v_q_d, v_d); END IF;
    v_linea := ST_MakeLine(v_partes);

    RETURN QUERY SELECT v_dist + v_aj_o + v_aj_d,
                        v_dur + (v_aj_o + v_aj_d) / c_conector_m_s,
                        ST_AsGeoJSON(ST_Transform(ST_SetSRID(v_linea, 32721), 4326), 6),
                        v_aj_o, v_aj_d, COALESCE(v_calles, '[]'::jsonb)::text;
END;
$$;
