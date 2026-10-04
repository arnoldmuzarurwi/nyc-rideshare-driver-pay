/*
  Q3: Rider fares in the congestion zone
  Question: Did riders pay more than the $1.50 congestion fee?
  Method:   Compare the change in average base fare for zone trips vs
            all other trips, 2024 vs 2025, by company, and add the
            average fee paid. A second query checks trip length and
            price per mile, so longer trips are not mistaken for
            higher prices.
  Tables:   fact_trip, dim_company, dim_zone
  Answer:   Uber zone riders did; Lyft zone riders paid about the fee.
            Uber zone base fares rose $3.07 more than other fares, on
            top of a $1.49 average fee. About half of that came from
            longer zone trips (5.40 to 5.64 miles), so at the same
            distance Uber zone riders paid about $3.00 extra, roughly
            double the fee. Lyft zone fares fell only because zone trips
            got shorter (5.61 to 5.37 miles). Per mile, Lyft zone prices
            rose slightly more than elsewhere, about $1.75 extra in all.
*/

USE rideshare;

-- Main result: fare change for zone vs other trips, plus the fee
WITH trips_flagged AS (
    -- Label every valid trip as a zone trip or another trip
    SELECT
        c.company_name,
        t.period,
        t.base_passenger_fare,
        COALESCE(t.cbd_congestion_fee, 0) AS cbd_fee,
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
fares_by_company AS (
    -- One row per company: average fare for each trip type and year
    SELECT
        company_name,
        AVG(CASE WHEN trip_type = 'zone'  AND period = 'pre'  THEN base_passenger_fare END) AS zone_fare_2024,
        AVG(CASE WHEN trip_type = 'zone'  AND period = 'post' THEN base_passenger_fare END) AS zone_fare_2025,
        AVG(CASE WHEN trip_type = 'other' AND period = 'pre'  THEN base_passenger_fare END) AS other_fare_2024,
        AVG(CASE WHEN trip_type = 'other' AND period = 'post' THEN base_passenger_fare END) AS other_fare_2025,
        AVG(CASE WHEN trip_type = 'zone'  AND period = 'post' THEN cbd_fee END)             AS zone_fee_2025,
        COUNT(*)                                                                          AS trips
    FROM trips_flagged
    GROUP BY company_name
)
SELECT
    company_name,
    ROUND(zone_fare_2025  - zone_fare_2024, 2)                AS zone_fare_change,
    ROUND(other_fare_2025 - other_fare_2024, 2)               AS other_fare_change,
    ROUND((zone_fare_2025  - zone_fare_2024)
        - (other_fare_2025 - other_fare_2024), 2)             AS fare_effect,
    ROUND(zone_fee_2025, 2)                                   AS avg_fee_2025,
    ROUND((zone_fare_2025  - zone_fare_2024)
        - (other_fare_2025 - other_fare_2024)
        + zone_fee_2025, 2)                                   AS total_extra_per_zone_trip,
    trips
FROM fares_by_company
ORDER BY company_name;

-- Check: did trip length change, and did price per mile change?
WITH trips_flagged AS (
    -- Same labels as above, keeping miles and fare
    SELECT
        c.company_name,
        t.period,
        t.trip_miles,
        t.base_passenger_fare,
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
    period,
    ROUND(AVG(trip_miles), 2)                               AS avg_miles,
    ROUND(SUM(base_passenger_fare) / SUM(trip_miles), 2)    AS fare_per_mile
FROM trips_flagged
GROUP BY company_name, trip_type, period
ORDER BY company_name, trip_type DESC, period DESC;