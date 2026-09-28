"""
Load the processed data into the MySQL "rideshare" database.

Fills three tables (created beforehand by sql/01_schema.sql):
    dim_company  - Uber / Lyft lookup
    dim_zone     - taxi zone lookup
    fact_trip    - the six sampled monthly trip files

Password handling: the password is NEVER stored in this file. It is read from
the MYSQL_PASSWORD line of a .env file in the project root (which is
gitignored), or, if there is none, asked for when the script runs.

Run from the project root:
    python3 src/load_mysql.py
"""

import getpass
import os
import sys
import time
from pathlib import Path

import pandas as pd
import pymysql

ROOT = Path(__file__).resolve().parent.parent
RAW_DIR = ROOT / "data" / "raw"
PROCESSED_DIR = ROOT / "data" / "processed"

DB_HOST = "localhost"
DB_USER = "root"
DB_NAME = "rideshare"

BATCH_ROWS = 10_000  # rows sent to MySQL per INSERT batch

# Sampled file column -> fact_trip column (only the ones whose names differ).
RENAME = {
    "hvfhs_license_num": "license_num",
    "PULocationID": "pu_location_id",
    "DOLocationID": "do_location_id",
    "trip_time": "trip_time_sec",
}

# fact_trip columns to insert, in order (trip_id and is_valid use their defaults).
FACT_COLUMNS = [
    "license_num", "pickup_datetime", "dropoff_datetime",
    "pu_location_id", "do_location_id", "trip_miles", "trip_time_sec",
    "base_passenger_fare", "tolls", "bcf", "sales_tax",
    "congestion_surcharge", "airport_fee", "cbd_congestion_fee",
    "tips", "driver_pay", "shared_request_flag", "period",
]


# ---------------------------------------------------------------------------
# Connection / password
# ---------------------------------------------------------------------------

def get_password() -> str:
    """Password from the environment, then .env, then an interactive prompt."""
    if os.environ.get("MYSQL_PASSWORD"):
        return os.environ["MYSQL_PASSWORD"]
    env_file = ROOT / ".env"
    if env_file.exists():
        # Minimal .env parser: lines of KEY=VALUE, ignoring blanks and # comments.
        for line in env_file.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                if key.strip() == "MYSQL_PASSWORD":
                    value = value.strip()
                    # Only '#' at the START of a line is a comment, so a '#' inside the
                    # password is kept. Remove one matching pair of surrounding quotes, if any.
                    if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
                        value = value[1:-1]
                    return value
    return getpass.getpass(f"MySQL password for {DB_USER}@{DB_HOST}: ")


def connect():
    return pymysql.connect(host=DB_HOST, user=DB_USER, password=get_password(),
                           database=DB_NAME, autocommit=False)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def to_python_rows(df: pd.DataFrame):
    """Turn a DataFrame into a list of tuples with NaN/NaT as None (MySQL NULL)."""
    # astype(object) first so None survives instead of being turned back into NaN.
    return list(df.astype(object).where(df.notna(), None).itertuples(index=False, name=None))


def insert_batches(cur, sql: str, rows: list, label: str):
    """executemany in batches (pymysql folds these into multi-row INSERTs) with progress."""
    total = len(rows)
    for start in range(0, total, BATCH_ROWS):
        cur.executemany(sql, rows[start:start + BATCH_ROWS])
        done = min(start + BATCH_ROWS, total)
        print(f"\r  {label}: {done:,}/{total:,} rows ({done / total:.0%})", end="", flush=True)
    print()


# ---------------------------------------------------------------------------
# Loaders
# ---------------------------------------------------------------------------

def load_company(cur):
    print("dim_company")
    # ON DUPLICATE KEY UPDATE makes this safe to re-run.
    cur.executemany(
        "INSERT INTO dim_company (license_num, company_name) VALUES (%s, %s) "
        "ON DUPLICATE KEY UPDATE company_name = VALUES(company_name)",
        [("HV0003", "Uber"), ("HV0005", "Lyft")])
    print("  2 rows")


def load_zones(cur):
    print("dim_zone")
    zones = pd.read_csv(RAW_DIR / "taxi_zone_lookup.csv")
    zones = zones.rename(columns={"LocationID": "location_id", "Borough": "borough",
                                  "Zone": "zone", "service_zone": "service_zone"})
    # Zones 264 and 265 ("Unknown" / "Outside of NYC") have missing values in the CSV.
    # They are kept, with the missing values stored as NULL (needed: trips reference them).
    rows = to_python_rows(zones[["location_id", "borough", "zone", "service_zone"]])
    insert_batches(
        cur,
        "INSERT INTO dim_zone (location_id, borough, zone, service_zone) VALUES (%s, %s, %s, %s) "
        "ON DUPLICATE KEY UPDATE borough = VALUES(borough), zone = VALUES(zone), "
        "service_zone = VALUES(service_zone)",
        rows, "zones")


def load_trips(conn, cur):
    print("fact_trip")
    # Guard against loading twice, which would duplicate every trip.
    cur.execute("SELECT COUNT(*) FROM fact_trip")
    if cur.fetchone()[0] > 0:
        sys.exit("fact_trip already has rows; refusing to load again. "
                 "Empty it yourself first if you want a fresh load.")

    placeholders = ", ".join(["%s"] * len(FACT_COLUMNS))
    sql = f"INSERT INTO fact_trip ({', '.join(FACT_COLUMNS)}) VALUES ({placeholders})"

    for path in sorted(PROCESSED_DIR.glob("fhvhv_sample_*.parquet")):
        df = pd.read_parquet(path).rename(columns=RENAME)[FACT_COLUMNS]
        insert_batches(cur, sql, to_python_rows(df), path.stem.replace("fhvhv_sample_", ""))
        conn.commit()  # commit per month so a failure keeps completed months


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    start = time.time()
    conn = connect()
    try:
        with conn.cursor() as cur:
            load_company(cur)
            load_zones(cur)
            conn.commit()  # dimensions must exist before trips (foreign keys)
            load_trips(conn, cur)
    finally:
        conn.close()
    print(f"Done in {time.time() - start:.0f}s")


if __name__ == "__main__":
    main()
