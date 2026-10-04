/*
  Q5: Best places and times to drive
  Question: Where and when do drivers earn the most per hour?
  Method:   Using 2025 trips from both companies, work out driver pay
            per hour (total pay / total hours) by pickup zone, and
            rank the top 10 zones in each borough with RANK(). Then
            work out pay per hour for every hour of the day and day
            of the week. Zones with under 500 trips are left out so
            a few lucky trips can't top the list.
  Tables:   fact_trip, dim_zone
  Answer:   Airports and the outer edges of the city pay best. JFK
            ($77.58 per hour, 20,700 trips) and LaGuardia ($74.36)
            lead Queens, and Charleston/Tottenville tops Staten Island
            ($79.25, but only 517 trips). Downtown leads Manhattan
            (Battery Park City, $68.86). By time, 3 to 6 AM pays most
            every day (Sunday 4 AM, $77.17), and weekday afternoons
            from 2 to 5 PM pay least (Friday 4 PM, $55.85). The best
            hours have the fewest trips, so drivers likely wait longer
            between rides, and pay per hour counts only time with a
            passenger.
*/

USE rideshare;

-- Part A: top 10 pickup zones per borough by pay per hour
WITH zone_pay AS (
    -- Pay per hour for each pickup zone, 2025 only
    SELECT
        z.borough,
        z.location_id,
        z.zone,
        COUNT(*)                                             AS trips,
        SUM(t.driver_pay) / SUM(t.trip_time_sec) * 3600      AS pay_per_hour
    FROM fact_trip t
    JOIN dim_zone z ON t.pu_location_id = z.location_id
    WHERE t.is_valid = 1
      AND t.period = 'post'
      AND z.location_id NOT IN (264, 265)
    GROUP BY z.borough, z.location_id, z.zone
    HAVING COUNT(*) >= 500
),
zone_ranked AS (
    -- Rank zones within each borough, best pay first
    SELECT
        *,
        RANK() OVER (PARTITION BY borough ORDER BY pay_per_hour DESC) AS zone_rank
    FROM zone_pay
)
SELECT
    borough,
    zone_rank,
    location_id,
    zone,
    trips,
    ROUND(pay_per_hour, 2) AS pay_per_hour
FROM zone_ranked
WHERE zone_rank <= 10
ORDER BY borough, zone_rank;

-- Part B: pay per hour for every hour of the day and day of the week
SELECT
    WEEKDAY(t.pickup_datetime)                                 AS day_num,
    DATE_FORMAT(t.pickup_datetime, '%a')                       AS weekday,
    HOUR(t.pickup_datetime)                                    AS pickup_hour,
    COUNT(*)                                                   AS trips,
    ROUND(SUM(t.driver_pay) / SUM(t.trip_time_sec) * 3600, 2)  AS pay_per_hour
FROM fact_trip t
WHERE t.is_valid = 1
  AND t.period = 'post'
GROUP BY day_num, weekday, pickup_hour
ORDER BY pay_per_hour DESC;