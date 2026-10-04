/*
  Q4: Driver pay per hour
  Question: Did drivers earn more per hour on zone trips after
            congestion pricing started?
  Method:   Work out driver pay per hour of trip time (total pay /
            total hours) for zone trips vs all other trips, 2024 vs
            2025, by company. The pay effect is how much more zone
            pay per hour changed than other pay per hour.
  Tables:   fact_trip, dim_company, dim_zone
  Answer:   Yes, for both companies, and more with Uber. Uber zone pay
            per hour rose from $60.21 to $64.93 (+$4.72) while other
            trips rose $1.78, an effect of about $2.94 per hour (5%).
            Lyft zone pay rose $2.08 vs $1.18 elsewhere, an effect of
            about $0.89 per hour (1.5%). Pay per hour counts only time
            with a passenger, not waiting time, so real hourly
            earnings are lower than these figures.
*/

USE rideshare;

WITH trips_flagged AS (
    -- Label every valid trip as a zone trip or another trip
    SELECT
        c.company_name,
        t.period,
        t.driver_pay,
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
pay_by_company AS (
    -- One row per company: pay per hour for each trip type and year
    SELECT
        company_name,
        SUM(CASE WHEN trip_type = 'zone'  AND period = 'pre'  THEN driver_pay END)
          / SUM(CASE WHEN trip_type = 'zone'  AND period = 'pre'  THEN trip_time_sec END) * 3600  AS zone_pay_hr_2024,
        SUM(CASE WHEN trip_type = 'zone'  AND period = 'post' THEN driver_pay END)
          / SUM(CASE WHEN trip_type = 'zone'  AND period = 'post' THEN trip_time_sec END) * 3600  AS zone_pay_hr_2025,
        SUM(CASE WHEN trip_type = 'other' AND period = 'pre'  THEN driver_pay END)
          / SUM(CASE WHEN trip_type = 'other' AND period = 'pre'  THEN trip_time_sec END) * 3600  AS other_pay_hr_2024,
        SUM(CASE WHEN trip_type = 'other' AND period = 'post' THEN driver_pay END)
          / SUM(CASE WHEN trip_type = 'other' AND period = 'post' THEN trip_time_sec END) * 3600  AS other_pay_hr_2025,
        COUNT(*)                                                                                AS trips
    FROM trips_flagged
    GROUP BY company_name
)
SELECT
    company_name,
    ROUND(zone_pay_hr_2024, 2)                                AS zone_pay_hr_2024,
    ROUND(zone_pay_hr_2025, 2)                                AS zone_pay_hr_2025,
    ROUND(other_pay_hr_2024, 2)                               AS other_pay_hr_2024,
    ROUND(other_pay_hr_2025, 2)                               AS other_pay_hr_2025,
    ROUND((zone_pay_hr_2025  - zone_pay_hr_2024)
        - (other_pay_hr_2025 - other_pay_hr_2024), 2)         AS pay_effect,
    trips
FROM pay_by_company
ORDER BY company_name;