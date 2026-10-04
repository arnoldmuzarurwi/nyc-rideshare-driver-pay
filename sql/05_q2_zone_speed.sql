/*
  Q2: Congestion zone traffic speed
  Question: Did traffic in the congestion zone speed up after
            congestion pricing started?
  Method:   Compare average speed (mph) for zone trips vs all other
            trips, 2024 vs 2025, by company. The effect is how much
            more zone trips changed than other trips.
  Tables:   fact_trip, dim_company, dim_zone
  Answer:   Yes. Zone trips sped up more than other trips for both
            companies. Uber zone trips gained 0.91 mph vs 0.11 mph
            for other trips, an effect of about 0.80 mph (5 to 6%).
            Lyft zone trips gained 0.14 mph while other trips slowed
            0.27 mph, an effect of about 0.41 mph (3%). Speed covers
            the whole trip, including miles outside the zone, so the
            effect inside the zone is likely larger.
*/

USE rideshare;

WITH trips_flagged AS (
    -- Label every valid trip as a zone trip or another trip
    SELECT
        c.company_name,
        t.period,
        t.trip_miles,
        t.trip_time_sec,
        CASE
            WHEN pu.in_cbd = 1 OR dz.in_cbd = 1 THEN 'zone'
            ELSE 'other'
        END AS trip_type
    FROM fact_trip t
    JOIN dim_company c    ON t.license_num    = c.license_num
    LEFT JOIN dim_zone pu ON t.pu_location_id = pu.location_id
    LEFT JOIN dim_zone dz ON t.do_location_id = dz.location_id
    WHERE t.is_valid = 1
),
speed_by_group AS (
    -- Average speed from totals: all miles / all hours
    SELECT
        company_name,
        trip_type,
        period,
        COUNT(*)                                                 AS trips,
        ROUND(SUM(trip_miles) / (SUM(trip_time_sec) / 3600), 2)  AS avg_mph
    FROM trips_flagged
    GROUP BY company_name, trip_type, period
)
SELECT
    company_name,
    trip_type,
    MAX(CASE WHEN period = 'pre'  THEN avg_mph END) AS mph_2024,
    MAX(CASE WHEN period = 'post' THEN avg_mph END) AS mph_2025,
    ROUND(MAX(CASE WHEN period = 'post' THEN avg_mph END)
        - MAX(CASE WHEN period = 'pre'  THEN avg_mph END), 2) AS change_mph,
    SUM(trips)                                       AS trips
FROM speed_by_group
GROUP BY company_name, trip_type
ORDER BY company_name, trip_type DESC;