/*
  09: Dashboard exports
  Purpose:  Build the two summary tables the Tableau dashboard needs
            that the question files don't already provide.
  Method:   Table 1 gives every zone's 2025 pay per hour with its
            borough and congestion zone flag, for the map. Zones with
            under 500 trips get no rate, matching Q5. Table 2 gives
            speed, fare, fare per mile, pay per hour and driver share
            for zone vs other trips, by company and year, for the
            before and after panel.
  Tables:   fact_trip, dim_company, dim_zone
  Result:   Table 1 has 263 zones (all but the 2 unknowns), 37 of them
            in the congestion zone. Table 2 has 8 rows whose speed,
            fare and pay figures match Q2, Q3 and Q4, with trips adding
            up to 2,399,539. It also shows Uber zone trips fell about
            10% (313,803 to 283,622) while other trips held steady, and
            Uber drivers' share of zone fares fell from 70.9% to 66.8%.
*/

USE rideshare;

-- Table 1: every zone for the map, 2025 pay per hour and congestion flag
SELECT
    z.location_id,
    z.borough,
    z.zone,
    z.in_cbd,
    COUNT(t.trip_id)                                              AS trips,
    CASE
        WHEN COUNT(t.trip_id) >= 500
        THEN ROUND(SUM(t.driver_pay) / SUM(t.trip_time_sec) * 3600, 2)
    END                                                           AS pay_per_hour
FROM dim_zone z
LEFT JOIN fact_trip t
       ON t.pu_location_id = z.location_id
      AND t.is_valid = 1
      AND t.period = 'post'
WHERE z.location_id NOT IN (264, 265)
GROUP BY z.location_id, z.borough, z.zone, z.in_cbd
ORDER BY z.location_id;

-- Table 2: before and after panel, one row per company, trip type and year
WITH trips_flagged AS (
    -- Label every valid trip as a zone trip or another trip
    SELECT
        c.company_name,
        t.period,
        t.trip_miles,
        t.trip_time_sec,
        t.base_passenger_fare,
        t.driver_pay,
        CASE
            WHEN pu.in_cbd = 1 OR dz.in_cbd = 1 THEN 'zone'
            ELSE 'other'
        END AS trip_type
    FROM fact_trip t
    JOIN dim_company c    ON t.license_num    = c.license_num
    LEFT JOIN dim_zone pu ON t.pu_location_id = pu.location_id
    LEFT JOIN dim_zone dz ON t.do_location_id = dz.location_id
    WHERE t.is_valid = 1
)
SELECT
    company_name,
    trip_type,
    CASE WHEN period = 'pre' THEN 2024 ELSE 2025 END                AS year,
    COUNT(*)                                                         AS trips,
    ROUND(SUM(trip_miles) / (SUM(trip_time_sec) / 3600), 2)          AS avg_mph,
    ROUND(AVG(base_passenger_fare), 2)                               AS avg_fare,
    ROUND(SUM(base_passenger_fare) / SUM(trip_miles), 2)             AS fare_per_mile,
    ROUND(SUM(driver_pay) / SUM(trip_time_sec) * 3600, 2)            AS pay_per_hour,
    ROUND(SUM(driver_pay) / SUM(base_passenger_fare) * 100, 1)       AS driver_share_pct
FROM trips_flagged
GROUP BY company_name, trip_type, year
ORDER BY company_name, trip_type DESC, year;