/*
  12: Before and after panel with 2023
  Purpose:  Build the three year table for the dashboard's before and
            after panel and KPI cards, adding Feb to Apr 2023 as a
            baseline year, without changing 09_exports.sql or its CSV.
  Method:   Same calculations as Table 2 in 09_exports.sql (speed from
            total miles over total hours, average fare, fare per mile,
            pay per hour of trip time, driver share of fare), for zone
            vs other trips, by company and year. 2023 is summarized
            from fact_trip_2023 and 2024 and 2025 from fact_trip, each
            on its own, then the summary rows are stacked. Valid trips
            only (is_valid = 1). The 2024 and 2025 rows should match
            dashboard_before_after.csv exactly.
  Tables:   fact_trip, fact_trip_2023, dim_company, dim_zone
  Result:   12 rows (2 companies, zone vs other, 2023 to 2025). The
            2024 and 2025 rows match dashboard_before_after.csv
            exactly, and the 2023 rows add up to 1,149,369 trips, all
            valid 2023 trips. The 2023 to 2024 gaps match the placebo
            test: zone vs other speed barely moved before the fee
            (Uber +0.10, Lyft +0.05 mph), while Uber zone fares had
            already risen $3.54 vs $0.75 for other trips.
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
GROUP BY c.company_name, trip_type

UNION ALL

-- 2024 (pre) and 2025 (post), same as 09_exports.sql
SELECT
    c.company_name,
    CASE
        WHEN pu.in_cbd = 1 OR dz.in_cbd = 1 THEN 'zone'
        ELSE 'other'
    END                                                              AS trip_type,
    CASE WHEN t.period = 'pre' THEN 2024 ELSE 2025 END               AS year,
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
GROUP BY c.company_name, trip_type, year

ORDER BY company_name, trip_type DESC, year;