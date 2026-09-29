USE rideshare;

-- Preview: zones where most same-zone trips in 2025 paid the congestion fee
SELECT
    z.location_id,
    z.borough,
    z.zone,
    COUNT(*)                        AS same_zone_trips,
    AVG(t.cbd_congestion_fee > 0)   AS share_charged
FROM fact_trip t
JOIN dim_zone z ON t.pu_location_id = z.location_id
WHERE t.period = 'post'
  AND t.is_valid = 1
  AND t.pu_location_id = t.do_location_id
GROUP BY z.location_id, z.borough, z.zone
HAVING share_charged > 0.5
ORDER BY z.location_id;

-- Summary check of the preview list
SELECT
    z.borough,
    COUNT(*)              AS zones,
    MIN(share_charged)    AS lowest_share,
    MIN(same_zone_trips)  AS fewest_trips
FROM (
    SELECT
        t.pu_location_id,
        COUNT(*)                        AS same_zone_trips,
        AVG(t.cbd_congestion_fee > 0)   AS share_charged
    FROM fact_trip t
    WHERE t.period = 'post'
      AND t.is_valid = 1
      AND t.pu_location_id = t.do_location_id
    GROUP BY t.pu_location_id
    HAVING share_charged > 0.5
) AS cbd
JOIN dim_zone z ON cbd.pu_location_id = z.location_id
GROUP BY z.borough;

-- Which zones on the list are borderline (under 90% charged)?
SELECT
    z.location_id,
    z.zone,
    COUNT(*)                        AS same_zone_trips,
    AVG(t.cbd_congestion_fee > 0)   AS share_charged
FROM fact_trip t
JOIN dim_zone z ON t.pu_location_id = z.location_id
WHERE t.period = 'post'
  AND t.is_valid = 1
  AND t.pu_location_id = t.do_location_id
GROUP BY z.location_id, z.zone
HAVING share_charged > 0.5 AND share_charged < 0.9
ORDER BY share_charged;

-- Mark congestion zones: at least 90% of same-zone 2025 trips paid the fee
SET SQL_SAFE_UPDATES = 0;

UPDATE dim_zone
SET in_cbd = 1
WHERE location_id IN (
    SELECT pu_location_id FROM (
        SELECT
            t.pu_location_id,
            AVG(t.cbd_congestion_fee > 0) AS share_charged
        FROM fact_trip t
        WHERE t.period = 'post'
          AND t.is_valid = 1
          AND t.pu_location_id = t.do_location_id
        GROUP BY t.pu_location_id
        HAVING share_charged >= 0.9
    ) AS cbd
);

SET SQL_SAFE_UPDATES = 1;

-- Check: should say 37
SELECT COUNT(*) AS cbd_zones FROM dim_zone WHERE in_cbd = 1;