-- Function to calculate route
-- Usage: GET /rpc/route?x1=...&y1=...&x2=...&y2=...

CREATE OR REPLACE FUNCTION route(
    x1 float, y1 float,
    x2 float, y2 float
) RETURNS TABLE (
    seq int,
    node bigint,
    edge bigint,
    cost float,
    agg_cost float,
    geojson text
) AS $$
DECLARE
    start_node bigint;
    end_node bigint;
    start_geom geometry;
    end_geom geometry;
    start_point geometry;
    end_point geometry;
BEGIN
    start_point := ST_SetSRID(ST_MakePoint(x1, y1), 4326);
    end_point := ST_SetSRID(ST_MakePoint(x2, y2), 4326);

    -- Find nearest node to start point
    SELECT v.id, v.the_geom INTO start_node, start_geom
    FROM ways_vertices_pgr v
    WHERE EXISTS (SELECT 1 FROM ways w WHERE w.source = v.id OR w.target = v.id)
    ORDER BY v.the_geom <-> start_point
    LIMIT 1;

    -- Find nearest node to end point
    SELECT v.id, v.the_geom INTO end_node, end_geom
    FROM ways_vertices_pgr v
    WHERE EXISTS (SELECT 1 FROM ways w WHERE w.source = v.id OR w.target = v.id)
    ORDER BY v.the_geom <-> end_point
    LIMIT 1;

    IF start_node IS NULL THEN
        RAISE NOTICE 'Start node not found for point (%, %)', x1, y1;
        RETURN;
    END IF;

    IF end_node IS NULL THEN
        RAISE NOTICE 'End node not found for point (%, %)', x2, y2;
        RETURN;
    END IF;

    RETURN QUERY
    -- 1. Connection from start point to network
    SELECT
        0 as seq,
        start_node as node,
        -1::bigint as edge,
        ST_Distance(start_point::geography, start_geom::geography) as cost,
        0::float as agg_cost,
        ST_AsGeoJSON(ST_MakeLine(start_point, start_geom))::text as geojson

    UNION ALL

    -- 2. The route on the network
    SELECT
        r.seq + 1 as seq,
        r.node,
        r.edge,
        r.cost,
        r.agg_cost,
        ST_AsGeoJSON(w.the_geom)::text as geojson
    FROM pgr_dijkstra(
        'SELECT gid as id, source, target, length_m as cost, length_m as reverse_cost FROM ways',
        start_node,
        end_node,
        directed := false
    ) as r
    LEFT JOIN ways w ON r.edge = w.gid
    WHERE r.edge <> -1

    UNION ALL

    -- 3. Connection from network to end point
    SELECT
        1000000 as seq,
        end_node as node,
        -2::bigint as edge,
        ST_Distance(end_geom::geography, end_point::geography) as cost,
        0::float as agg_cost,
        ST_AsGeoJSON(ST_MakeLine(end_geom, end_point))::text as geojson;
END;
$$ LANGUAGE plpgsql STABLE;


SELECT * FROM route(13.3616929, 52.4031588, 13.3622796, 52.4020178);
