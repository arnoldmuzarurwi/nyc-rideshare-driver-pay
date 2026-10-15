/*
  13: Monthly before and after panel
  Purpose:  Build the monthly table for the dashboard's before and
            after panel, so each line has 9 points (Feb, Mar and Apr
            of 2023, 2024 and 2025) and every point can be hovered,
            without changing 12_dashboard_before_after.sql or its CSV.
  Method:   Same calculations as 12_dashboard_before_after.sql (speed
            from total miles over total hours, average fare, fare per
            mile, pay per hour of trip time, driver share of fare),
            for zone vs other trips, by company, year and pickup
            month. 2023 is summarized from fact_trip_2023 and 2024
            and 2025 from fact_trip, each on its own, then the
            summary rows are stacked. Valid trips only (is_valid = 1).
            The three monthly trip counts for each company, trip type
            and year should add up to that row in
            dashboard_before_after_3yr.csv.
  Tables:   fact_trip, fact_trip_2023, dim_company, dim_zone
  Result:   36 rows (2 companies, zone vs other, Feb to Apr of 2023,
            2024 and 2025), months 2 to 4 only. The three monthly trip
            counts for each company, trip type and year add up exactly
            to dashboard_before_after_3yr.csv, and zone plus other
            trips match q1_driver_share.csv for every 2024 and 2025
            month. Uber zone trips were faster in all three 2025
            months (14.89 to 15.55 mph) than in any 2023 or 2024 month
            (14.22 to 14.63). Lyft's 2025 zone speeds (14.39 to 14.73)
            overlap earlier years; its gain shows only against other
            Lyft trips, which slowed in 2025.
*/

USE rideshare;

-- 2023 placebo year, summarized from its own table
SELECT
    c.company_name,
    CASE
        WHEN pu.in_cbd = 1 OR dz.in_cbd = 1 THEN 'zone'
        ELSE 'other'
    END                                                              AS trip_type,
    2023                                                             AS year,
    MONTH(t.pickup_datetime)                                         AS month,
    COUNT(*)                                                         AS trips,
    ROUND(SUM(t.trip_miles) / (SUM(t.trip_time_sec) / 3600), 2)      AS avg_mph,
    ROUND(AVG(t.base_passenger_fare), 2)                             AS avg_fare,
    ROUND(SUM(t.base_passenger_fare) / SUM(t.trip_miles), 2)         AS fare_per_mile,
    ROUND(SUM(t.driver_pay) / SUM(t.trip_time_sec) * 3600, 2)        AS pay_per_hour,
    ROUND(SUM(t.driver_pay) / SUM(t.base_passenger_fare) * 100, 1)   AS driver_share_pct
FROM fact_trip_2023 t
JOIN dim_company c    ON t.license_num    = c.license_num
LEFT JOIN dim_zone pu ON t.pu_location_id = pu.location_id
LEFT JOIN dim_zone dz ON t.do_location_id = dz.location_id
WHERE t.is_valid = 1
GROUP BY c.company_name, trip_type, month

UNION ALL

-- 2024 (pre) and 2025 (post), same as 12_dashboard_before_after.sql
SELECT
    c.company_name,
    CASE
        WHEN pu.in_cbd = 1 OR dz.in_cbd = 1 THEN 'zone'
        ELSE 'other'
    END                                                              AS trip_type,
    CASE WHEN t.period = 'pre' THEN 2024 ELSE 2025 END               AS year,
    MONTH(t.pickup_datetime)                                         AS month,
    COUNT(*)                                                         AS trips,
    ROUND(SUM(t.trip_miles) / (SUM(t.trip_time_sec) / 3600), 2)      AS avg_mph,
    ROUND(AVG(t.base_passenger_fare), 2)                             AS avg_fare,
    ROUND(SUM(t.base_passenger_fare) / SUM(t.trip_miles), 2)         AS fare_per_mile,
    ROUND(SUM(t.driver_pay) / SUM(t.trip_time_sec) * 3600, 2)        AS pay_per_hour,
    ROUND(SUM(t.driver_pay) / SUM(t.base_passenger_fare) * 100, 1)   AS driver_share_pct
FROM fact_trip t
JOIN dim_company c    ON t.license_num    = c.license_num
LEFT JOIN dim_zone pu ON t.pu_location_id = pu.location_id
LEFT JOIN dim_zone dz ON t.do_location_id = dz.location_id
WHERE t.is_valid = 1
GROUP BY c.company_name, trip_type, year, month

ORDER BY company_name, trip_type DESC, year, month;