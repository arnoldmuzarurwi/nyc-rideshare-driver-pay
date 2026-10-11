# NYC Rideshare Driver Pay and Congestion Pricing

**Congestion pricing:** on January 5, 2025, New York started charging a fee to drive into Manhattan at and below 60th Street. The goal is fewer cars, faster traffic, and money for the subway and buses. Uber and Lyft trips into or within the zone pay $1.50 per trip, charged to the rider.

**Why it matters:** if rides cost more, fewer people might take them and drivers could earn less. If traffic moves faster, drivers might finish more trips per hour and earn more. Nobody knows which happened without looking at the data.

**The question:** what did congestion pricing change for riders and drivers? Did traffic get faster, did riders pay more than the fee, and did drivers earn more?

**The approach:** compare Uber and Lyft trips inside the congestion zone with trips everywhere else, before and after the fee started (February to April 2024 vs 2025), using the city's public trip records, SQL in MySQL and statistical tests in Python.

## What I found

- **Traffic in the zone got faster.** Zone trips sped up more than trips elsewhere: about 0.8 mph more for Uber and 0.4 mph more for Lyft.
- **Uber riders paid more than the fee, but the fee didn't cause it.** Uber fares in the zone rose about $2.25 more than fares elsewhere, and Uber kept most of that. But they had risen just as much the year before the fee existed.
- **Drivers' pay per hour rose more in the zone,** which points to faster trips rather than drivers getting a bigger share of the fare.

To check whether these changes really came from the policy, I ran the same comparison on 2023 vs 2024, a year with no fee. That check is what showed the Uber fare rise was already happening.

Based on a 2% random sample of about 3.55 million Uber and Lyft trips. Tools: MySQL, SQL, Python (pandas, statsmodels).

<!-- DASHBOARD: add the screenshot (images/dashboard.png) and the Tableau Public link here after Phase 6 -->

## The five questions

| #   | Question                                          | Answer                                                                                                                                                                                                                               | Where                                                              |
| --- | ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------ |
| 1   | How much of each fare reaches the driver?         | Lyft drivers got 77.7% to 81.2% of the base fare each month; Uber drivers got 71.9% to 78.8%, lower in every 2025 month than the same month of 2024.                                                                                 | [04_q1_driver_share.sql](sql/04_q1_driver_share.sql)               |
| 2   | Did traffic in the congestion zone speed up?      | Yes. Zone trips gained 0.79 mph more than other trips for Uber and 0.41 mph more for Lyft, and the year before the fee showed almost no gap.                                                                                         | [05_q2_zone_speed.sql](sql/05_q2_zone_speed.sql)                   |
| 3   | Did riders pay more than the $1.50 fee?           | Uber riders did: at the same trip distance, zone fares rose $2.25 more than other fares, on top of the fee. But they had already risen $2.32 more the year before, so the fee didn't cause it. Lyft riders paid about the fee alone. | [06_q3_rider_fares.sql](sql/06_q3_rider_fares.sql)                 |
| 4   | Did drivers earn more per hour?                   | Zone pay per hour rose $2.94 more than other trips' for Uber and $0.89 more for Lyft, reversing a decline the year before. The direction is clear; the exact size is not a clean estimate.                                           | [07_q4_driver_pay_per_hour.sql](sql/07_q4_driver_pay_per_hour.sql) |
| 5   | Where and when do drivers earn the most per hour? | At the airports (JFK $77.58, LaGuardia $74.36) and from 3 to 6 AM every day; weekday afternoons from 2 to 5 PM pay least (2025 trips).                                                                                               | [08_q5_best_times_places.sql](sql/08_q5_best_times_places.sql)     |

**Where the extra Uber fare went:** at the same trip distance, Uber kept $1.95 of the $2.25 rise and drivers got $0.31. Uber was already keeping $2.59 more per zone trip the year before, so this split is an existing trend too ([10_fare_split.sql](sql/10_fare_split.sql)).

## Did congestion pricing cause these changes?

**How the comparison works.** Many things changed between 2024 and 2025 across the whole city: prices, demand, pay rules. So the project doesn't just compare zone trips before and after. It compares how much zone trips changed with how much all other trips changed over the same months. Citywide changes affect both groups and cancel out; the gap that remains is the change linked to the zone. This is called a difference in differences, and each gap was tested with a regression in Python ([congestion_test.ipynb](notebooks/congestion_test.ipynb)). Every 2025 gap is statistically significant except Lyft's fare, which didn't change.

**The check.** That method only works if zone trips and other trips were moving in step before the fee. To test this, I loaded February to April 2023 and ran exactly the same comparison for 2023 vs 2024, a year with no fee ([placebo_test.ipynb](notebooks/placebo_test.ipynb)). If the groups were moving in step, those gaps should be near zero.

| Change in zone trips compared with other trips | 2024 to 2025 (fee starts) | 2023 to 2024 (no fee) | What it means                      |
| ---------------------------------------------- | ------------------------- | --------------------- | ---------------------------------- |
| Speed, Uber                                    | +0.79 mph                 | +0.11 mph             | Supported: the gain is new         |
| Speed, Lyft                                    | +0.41 mph                 | +0.06 mph             | Supported: the gain is new         |
| Uber fare, same distance                       | +$2.25                    | +$2.32                | Existing trend, not the fee        |
| Uber kept per trip, same distance              | +$1.95                    | +$2.59                | Existing trend, not the fee        |
| Lyft fare, same distance                       | −$0.02                    | +$0.28                | No rise after the fee              |
| Driver pay per hour, Uber                      | +$2.94                    | −$1.39                | Direction reversed; size not exact |
| Driver pay per hour, Lyft                      | +$0.89                    | −$0.58                | Direction reversed; size not exact |

So the faster traffic is the one change the data clearly links to congestion pricing. The higher Uber fares, and the larger share Uber kept, were already happening before the fee. Pay per hour turned from falling to rising, which fits faster trips, but because the groups weren't moving in step beforehand, the exact amount can't be pinned to the policy. Full results: [congestion_tests.csv](exports/congestion_tests.csv) and [placebo_tests.csv](exports/placebo_tests.csv).

## How it was built

**Data.** NYC Taxi and Limousine Commission High Volume For Hire Vehicle trip records, February to April of 2023, 2024 and 2025, keeping Uber (license HV0003) and Lyft (HV0005). Each month has about 18 to 20 million trips, too many for a laptop database, so `src/etl.py` takes a 2% random sample of each month with a fixed seed (42), so anyone rerunning it gets the same sample. For February 2024 the sample's averages were within about 0.2% of the full file ([sample_check.md](docs/sample_check.md)).

**Database.** A small star schema in MySQL ([01_schema.sql](sql/01_schema.sql)): one fact table of trips, `fact_trip` (2,400,067 trips from 2024 and 2025), and two lookup tables, `dim_company` and `dim_zone` (265 NYC taxi zones). The 2023 trips sit in a separate table, `fact_trip_2023` (1,150,388 trips), so the placebo test could not change any earlier result ([11_placebo_table.sql](sql/11_placebo_table.sql)).

**Cleaning.** Impossible trips (zero or negative miles, negative fares or negative driver pay) are flagged with `is_valid = 0` rather than deleted, and left out of the analysis: 528 trips in 2024 and 2025 (0.02%) and 1,019 in 2023 (0.09%, mostly negative fares). Very long trips (over 100 miles or 4 hours) are kept as real ([02_validation.sql](sql/02_validation.sql)).

**The congestion zone.** The city's data doesn't say which taxi zones are inside the congestion area, so it was worked out from the 2025 trips: a zone counts as inside when at least 90% of trips that start and end in it paid the fee. That gives 37 Manhattan zones; Lincoln Square East (52% charged) was left out because it straddles 60th Street ([03_congestion_zones.sql](sql/03_congestion_zones.sql)). A trip counts as a zone trip if it starts or ends in one of them. In 2025, 97.8% to 99.4% of zone trips paid the fee, against about 3% of other trips.

**Analysis.** Each question is answered in its own SQL file (`sql/04` to `sql/10`), with a header giving the question, method and answer. The regressions are in `notebooks/`, with standard errors clustered by pickup zone. Result tables are saved as CSVs in `exports/`.

### Running it yourself

1. Install Python packages: pandas, pyarrow, numpy, SQLAlchemy, PyMySQL, statsmodels, python-dotenv.
2. Put your MySQL password in a `.env` file in the project folder as `MYSQL_PASSWORD=...` (it is gitignored).
3. Download and sample the data: `python3 src/etl.py`, then `python3 src/etl.py --placebo` for 2023.
4. In MySQL, run `sql/01_schema.sql`, then load with `python3 src/load_mysql.py`.
5. Run `sql/02_validation.sql` and `sql/03_congestion_zones.sql`.
6. Run Part A of `sql/11_placebo_table.sql`, load 2023 with `python3 src/load_mysql.py --placebo`, then run Part B.
7. Run `sql/04` to `sql/10`, then the two notebooks.

## Limitations

- **One year before the fee.** The placebo test compares 2023 with 2024 only. More earlier years would show whether trends were steady.
- **Other 2025 changes.** Anything else that changed inside the zone in 2025 could also play a part in the speed gain.
- **Pay per hour counts only time with a passenger,** not waiting between rides, so real hourly earnings are lower than these figures. Driver pay excludes tips and tolls.
- **Speed covers the whole trip,** including miles outside the zone, so the gain inside the zone itself is likely larger.
- **The distance adjustment** assumes each extra mile adds the same amount to the fare.
- **The zone is built from taxi zones,** whose edges don't follow the 60th Street boundary exactly.
- **A 2% sample** is accurate for overall averages but noisier for small groups, so zones with under 500 trips are left out of the zone rankings.

## Who did what

I planned the project, ran every query and test, checked and interpreted the results, and committed the analysis myself (24 of the 29 commits before this README). Claude Code, an AI coding assistant, wrote the data pipeline scripts (`src/etl.py` and `src/load_mysql.py`) and set up the folders at my direction; those 5 commits are marked as co-authored by Claude.
