/*
  10: Fare split in the congestion zone
  Question: When zone fares rose, how much went to drivers and how
            much did the company keep?
  Method:   For each trip, company kept = base fare minus driver pay.
            Compare the change in average fare, driver pay and
            company kept for zone trips vs all other trips, 2024 vs
            2025, by company. A second query checks how many "other"
            trips paid the congestion fee, to confirm the comparison
            group is mostly untouched by the policy.
  Tables:   fact_trip, dim_company, dim_zone
  Answer:   Uber kept most of the extra zone fare. Compared with other
            trips, Uber zone fares rose $3.07; drivers got $0.95 of
            that (31%) and Uber kept $2.12 (69%). Lyft zone fares fell
            $0.42; driver pay fell $0.64 while Lyft kept $0.23 more.
            These are raw averages, not adjusted for trip length: Uber
            zone trips got longer (5.40 to 5.64 miles) and Lyft zone
            trips got shorter (5.61 to 5.37 miles), which pushes
            Uber's figures up and Lyft's down. The check shows 97.8%
            to 99.4% of 2025 zone trips paid the fee and only about 3%
            of other trips did, so the comparison group is mostly
            untouched by the policy.
*/

USE rideshare;

-- Main result: where the extra zone fare went
WITH trips_flagged AS (
    -- Label every valid trip as a zone trip or another trip
    SELECT
        c.company_name,
        t.period,
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
),
group_averages AS (
    -- Average fare, driver pay and company kept per trip, by group
    SELECT
        company_name,
        trip_type,
        period,
        AVG(base_passenger_fare)               AS avg_fare,
        AVG(driver_pay)                        AS avg_driver_pay,
        AVG(base_passenger_fare - driver_pay)  AS avg_company_kept
    FROM trips_flagged
    GROUP BY company_name, trip_type, period
)
SELECT
    company_name,
    ROUND((MAX(CASE WHEN trip_type = 'zone'  AND period = 'post' THEN avg_fare END)
         - MAX(CASE WHEN trip_type = 'zone'  AND period = 'pre'  THEN avg_fare END))
        - (MAX(CASE WHEN trip_type = 'other' AND period = 'post' THEN avg_fare END)
         - MAX(CASE WHEN trip_type = 'other' AND period = 'pre'  THEN avg_fare END)), 2)
        AS fare_effect,
    ROUND((MAX(CASE WHEN trip_type = 'zone'  AND period = 'post' THEN avg_driver_pay END)
         - MAX(CASE WHEN trip_type = 'zone'  AND period = 'pre'  THEN avg_driver_pay END))
        - (MAX(CASE WHEN trip_type = 'other' AND period = 'post' THEN avg_driver_pay END)
         - MAX(CASE WHEN trip_type = 'other' AND period = 'pre'  THEN avg_driver_pay END)), 2)
        AS driver_pay_effect,
    ROUND((MAX(CASE WHEN trip_type = 'zone'  AND period = 'post' THEN avg_company_kept END)
         - MAX(CASE WHEN trip_type = 'zone'  AND period = 'pre'  THEN avg_company_kept END))
        - (MAX(CASE WHEN trip_type = 'other' AND period = 'post' THEN avg_company_kept END)
         - MAX(CASE WHEN trip_type = 'other' AND period = 'pre'  THEN avg_company_kept END)), 2)
        AS company_kept_effect
FROM group_averages
GROUP BY company_name
ORDER BY company_name;

-- Check: share of 2025 trips charged the fee, zone vs other
SELECT
    c.company_name,
    CASE WHEN pu.in_cbd = 1 OR dz.in_cbd = 1 THEN 'zone' ELSE 'other' END AS trip_type,
    COUNT(*)                                        AS trips,
    ROUND(AVG(t.cbd_congestion_fee > 0) * 100, 1)   AS pct_charged
FROM fact_trip t
JOIN dim_company c    ON t.license_num    = c.license_num
LEFT JOIN dim_zone pu ON t.pu_location_id = pu.location_id
LEFT JOIN dim_zone dz ON t.do_location_id = dz.location_id
WHERE t.is_valid = 1
  AND t.period = 'post'
GROUP BY c.company_name, trip_type
ORDER BY c.company_name, trip_type DESC;