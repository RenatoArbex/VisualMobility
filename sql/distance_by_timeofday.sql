WITH RECURSIVE segments AS (
    SELECT ST_Makeline(pts.the_geom_webmercator) AS the_geom_webmercator,
        ST_Length(ST_Makeline(pts.the_geom_webmercator))/1000 AS distance,
        transport_modes.factor,
        transport_mode,
        (MAX(timestamp)-MIN(timestamp)) AS time,
        pts.track_id,
        pts.path_id AS id,
        pts.user_id
    FROM (SELECT * FROM points ORDER BY track_id, path_id, timestamp ASC) AS pts
        JOIN paths ON pts.path_id=paths.cartodb_id
        JOIN transport_modes ON paths.transport_mode = transport_modes.name
    GROUP BY pts.path_id, pts.track_id, factor, pts.user_id, transport_mode
), starts AS (
    SELECT events.date AS date, events.track_id, events.location_id AS location_id, locations.name AS location_name FROM events JOIN locations ON events.location_id=locations.cartodb_id WHERE events.type='StartTrack'
), ends AS (
    SELECT events.date AS date, events.track_id, events.location_id AS location_id, locations.name AS location_name FROM events JOIN locations ON events.location_id=locations.cartodb_id WHERE events.type='EndTrack'
), tracks AS (
    SELECT
        segments.track_id AS id,
        SUM(distance*factor) AS carbon,
        SUM(distance) AS distance,
        SUM(segments.time) AS time,
        starts.location_id AS start_id,
        ends.location_id AS end_id,
        starts.location_name AS start_name,
        ends.location_name AS end_name,
        starts.date AS start_date,
        ends.date AS end_date,
        user_id
    FROM segments
        JOIN starts ON starts.track_id=segments.track_id
        JOIN ends ON ends.track_id=segments.track_id
    GROUP BY segments.track_id, user_id, start_date, end_date, start_id, end_id, start_name, end_name
), hours ( h ) AS (
    SELECT 0 UNION ALL
    SELECT h + 1 FROM hours WHERE h < 24
), filtered_segments AS (
    SELECT ST_Length(ST_Makeline(points.the_geom_webmercator))/1000 AS distance,
        points.track_id,
        extract(hour from timestamp) AS hour
    FROM points
    WHERE points.track_id IN(
        SELECT id
        FROM tracks
        WHERE 
            tracks.user_id = 1
            AND tracks.id IN
                (SELECT track_id FROM segments WHERE transport_mode='Run')
    )
    GROUP BY points.track_id, hour
)
SELECT COALESCE(SUM(filtered_segments.distance),0) AS distance, hours.h
FROM filtered_segments RIGHT OUTER JOIN hours ON hours.h=filtered_segments.hour
GROUP BY hours.h
ORDER BY hours.h