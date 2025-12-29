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
BEGIN
    -- Find nearest node to start point
    -- ways_vertices_pgr is created by osm2pgrouting
    -- We filter for nodes that are actually used in the ways table to avoid isolated vertices
    SELECT v.id INTO start_node
    FROM ways_vertices_pgr v
    WHERE EXISTS (SELECT 1 FROM ways w WHERE w.source = v.id OR w.target = v.id)
    ORDER BY v.the_geom <-> ST_SetSRID(ST_MakePoint(x1, y1), 4326)
    LIMIT 1;

    -- Find nearest node to end point
    SELECT v.id INTO end_node
    FROM ways_vertices_pgr v
    WHERE EXISTS (SELECT 1 FROM ways w WHERE w.source = v.id OR w.target = v.id)
    ORDER BY v.the_geom <-> ST_SetSRID(ST_MakePoint(x2, y2), 4326)
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
    SELECT
        r.seq,
        r.node,
        r.edge,
        r.cost,
        r.agg_cost,
        ST_AsGeoJSON(w.the_geom)::text as geojson
    FROM pgr_dijkstra(
        -- Query for edges. We use length_m as cost (shortest distance).
        -- You can change this to use time (length_m / speed).
        'SELECT gid as id, source, target, length_m as cost, length_m as reverse_cost FROM ways',
        start_node,
        end_node,
        directed := false
    ) as r
    LEFT JOIN ways w ON r.edge = w.gid;
END;
$$ LANGUAGE plpgsql STABLE;


SELECT * FROM route(13.3616929, 52.4031588, 13.3622796, 52.4020178);
