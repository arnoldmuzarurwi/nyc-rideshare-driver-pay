USE rideshare;

-- Data quality checks: each column counts how many trips have that problem
SELECT
    COUNT(*)                                        AS total_trips,
    SUM(pu_location_id IS NULL OR do_location_id IS NULL) AS missing_zone,
    SUM(trip_miles <= 0)                            AS zero_or_negative_miles,
    SUM(trip_time_sec <= 0)                         AS zero_or_negative_time,
    SUM(base_passenger_fare < 0)                    AS negative_fare,
    SUM(driver_pay < 0)                             AS negative_driver_pay,
    SUM(dropoff_datetime < pickup_datetime)         AS dropoff_before_pickup,
    SUM(trip_miles > 100)                           AS over_100_miles,
    SUM(trip_time_sec > 4 * 3600)                   AS over_4_hours,
    SUM(pu_location_id IN (264, 265))               AS unknown_pickup_zone
FROM fact_trip;

SET SQL_SAFE_UPDATES = 0;

UPDATE fact_trip
SET is_valid = 0
WHERE trip_miles <= 0
   OR base_passenger_fare < 0
   OR driver_pay < 0;

SET SQL_SAFE_UPDATES = 1;