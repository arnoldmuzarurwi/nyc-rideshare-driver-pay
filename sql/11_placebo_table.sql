/*
  11: 2023 placebo table
  Purpose:  Hold the Feb to Apr 2023 sample in its own table, for the
            placebo test (2023 vs 2024, when there was no policy), so
            fact_trip and every earlier result stay unchanged.
  Method:   Create fact_trip_2023 with exactly the same columns, keys
            and foreign keys as fact_trip (sql/01_schema.sql). Then
            run the same validation checks and flags as
            sql/02_validation.sql on the 2023 trips.
  Tables:   fact_trip_2023, dim_company, dim_zone
  Result:   fact_trip_2023 holds 1,150,388 trips (Feb to Apr 2023),
            loaded by src/load_mysql.py --placebo. 1,019 flagged
            is_valid = 0 (0.09%): 205 zero or negative miles, 817
            negative fares, 20 negative driver pay (some trips fail
            more than one check). Long trips (104 over 100 miles, 16
            over 4 hours) kept as real, as in 2024 and 2025. The flag
            rate is higher than 2024 and 2025 (0.02%) because 2023 has
            more negative fares (817, vs 227 in twice as many trips),
            but it is still under 0.1%.
*/

USE rideshare;

-- Part A: an empty copy of fact_trip's structure for the 2023 trips
CREATE TABLE fact_trip_2023 (
    trip_id               INT            AUTO_INCREMENT PRIMARY KEY,
    license_num           CHAR(6)        NOT NULL,
    pickup_datetime       DATETIME       NOT NULL,
    dropoff_datetime      DATETIME,
    pu_location_id        INT,
    do_location_id        INT,
    trip_miles            DECIMAL(8,2),
    trip_time_sec         INT,
    base_passenger_fare   DECIMAL(10,2),
    tolls                 DECIMAL(10,2),
    bcf                   DECIMAL(10,2),
    sales_tax             DECIMAL(10,2),
    congestion_surcharge  DECIMAL(10,2),
    airport_fee           DECIMAL(10,2),
    cbd_congestion_fee    DECIMAL(10,2),
    tips                  DECIMAL(10,2),
    driver_pay            DECIMAL(10,2),
    shared_request_flag   CHAR(1),
    period                VARCHAR(4),
    is_valid              TINYINT        DEFAULT 1,
    FOREIGN KEY (license_num)    REFERENCES dim_company(license_num),
    FOREIGN KEY (pu_location_id) REFERENCES dim_zone(location_id),
    FOREIGN KEY (do_location_id) REFERENCES dim_zone(location_id)
);

-- Check: the new table is empty, and fact_trip is unchanged
SELECT
    (SELECT COUNT(*) FROM fact_trip_2023) AS rows_2023,
    (SELECT COUNT(*) FROM fact_trip)      AS rows_fact_trip;

-- Part B: the same data quality checks as sql/02_validation.sql, on 2023
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
FROM fact_trip_2023;

-- Flag the same impossible trips as in 2024 and 2025
SET SQL_SAFE_UPDATES = 0;

UPDATE fact_trip_2023
SET is_valid = 0
WHERE trip_miles <= 0
   OR base_passenger_fare < 0
   OR driver_pay < 0;

SET SQL_SAFE_UPDATES = 1;

-- Check: how many 2023 trips were flagged, and what share
SELECT
    COUNT(*)                                  AS total_trips,
    SUM(is_valid = 0)                         AS flagged,
    ROUND(SUM(is_valid = 0) / COUNT(*) * 100, 2) AS pct_flagged,
    SUM(is_valid = 1)                         AS valid_trips
FROM fact_trip_2023;