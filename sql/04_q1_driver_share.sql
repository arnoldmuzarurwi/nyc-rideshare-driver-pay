/*
  Q1: Baseline driver share of fare
  Question: How much of each fare reaches the driver, by company and month?
  Method:   Divide total driver pay by total base fare for each company
            and month, then compare each month to the one before it
            with LAG().
  Tables:   fact_trip, dim_company
  Answer:   Lyft drivers kept 77.7% to 81.2% of base fares, and their share
            rose every month in both years. Uber drivers kept 71.9% to 78.8%,
            and their share fell in 2025. Uber's share dips every March
            (down 2.9 pts in 2024, 4.1 pts in 2025), so the March 2025 low
            is partly seasonal.
*/

USE rideshare;

WITH monthly_totals AS (
    -- One row per company per month: trip count and total dollars
    SELECT
        c.company_name,
        DATE_FORMAT(t.pickup_datetime, '%Y-%m') AS month,
        t.period,
        COUNT(*)                                AS trips,
        SUM(t.base_passenger_fare)              AS total_fare,
        SUM(t.driver_pay)                       AS total_driver_pay
    FROM fact_trip t
    JOIN dim_company c ON t.license_num = c.license_num
    WHERE t.is_valid = 1
    GROUP BY c.company_name, month, t.period
),
monthly_share AS (
    -- Turn the totals into averages and the driver share KPI
    SELECT
        company_name,
        month,
        period,
        trips,
        ROUND(total_fare / trips, 2)                    AS avg_fare,
        ROUND(total_driver_pay / trips, 2)              AS avg_driver_pay,
        ROUND(total_driver_pay / total_fare * 100, 1)   AS driver_share_pct
    FROM monthly_totals
)
SELECT
    *,
    LAG(driver_share_pct) OVER (
        PARTITION BY company_name, period ORDER BY month
    ) AS prev_month_share_pct,
    ROUND(driver_share_pct - LAG(driver_share_pct) OVER (
        PARTITION BY company_name, period ORDER BY month
    ), 1) AS mom_change_pts
FROM monthly_share
ORDER BY company_name, month;