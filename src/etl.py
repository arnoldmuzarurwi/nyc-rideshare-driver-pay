"""
ETL script: download NYC TLC High Volume For-Hire Vehicle (HVFHV) trip files,
keep Uber and Lyft trips, draw a 2% random sample, and save it.

Run from the project root:
    python3 src/etl.py
"""

import urllib.request
from pathlib import Path

import numpy as np
import pandas as pd
import pyarrow.parquet as pq

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Project folders, resolved relative to this file so the script works from anywhere.
ROOT = Path(__file__).resolve().parent.parent
RAW_DIR = ROOT / "data" / "raw"
PROCESSED_DIR = ROOT / "data" / "processed"

BASE_URL = "https://d37ci6vzurychx.cloudfront.net"

# Months to process: (year, month). 2024 = "pre" period, 2025 = "post" period.
# Feb-Apr in both years gives a like-for-like seasonal comparison.
MONTHS = [(2024, 2), (2024, 3), (2024, 4), (2025, 2), (2025, 3), (2025, 4)]

# Reference files (zone names and zone boundaries) that go in data/raw/ too.
REFERENCE_FILES = ["misc/taxi_zone_lookup.csv", "misc/taxi_zones.zip"]

# The only columns we read from each monthly file (saves memory).
COLUMNS = [
    "hvfhs_license_num", "pickup_datetime", "dropoff_datetime",
    "PULocationID", "DOLocationID", "trip_miles", "trip_time",
    "base_passenger_fare", "tolls", "bcf", "sales_tax",
    "congestion_surcharge", "airport_fee", "cbd_congestion_fee",
    "tips", "driver_pay", "shared_request_flag",
]

# License numbers: HV0003 = Uber, HV0005 = Lyft (HV0002/HV0004 are others, dropped).
KEEP_LICENSES = ["HV0003", "HV0005"]

SAMPLE_FRACTION = 0.02   # keep 2% of the Uber/Lyft trips
SEED = 42                # fixed seed so the sample is reproducible
CHUNK_ROWS = 1_000_000   # rows per chunk; a full month is ~20M rows, too big to load at once


# ---------------------------------------------------------------------------
# Step 1: download
# ---------------------------------------------------------------------------

def download(url_path: str) -> Path:
    """Download one file into data/raw/ (skipped if it is already there)."""
    dest = RAW_DIR / Path(url_path).name
    if dest.exists() and dest.stat().st_size > 0:
        print(f"already downloaded: {dest.name}")
        return dest
    print(f"downloading {dest.name} ...")
    # Write to a .part file first so an interrupted download is never mistaken for a complete one.
    part = dest.with_name(dest.name + ".part")
    urllib.request.urlretrieve(f"{BASE_URL}/{url_path}", part)
    part.rename(dest)
    return dest


# ---------------------------------------------------------------------------
# Step 2: filter + sample one monthly file
# ---------------------------------------------------------------------------

def process_month(year: int, month: int) -> dict:
    """Read one month in chunks, filter to Uber/Lyft, sample 2%, save, return row counts."""
    raw_path = download(f"trip-data/fhvhv_tripdata_{year}-{month:02d}.parquet")
    parquet = pq.ParquetFile(raw_path)

    # cbd_congestion_fee only exists in 2025 files. Read only the columns that exist;
    # the missing one is filled with 0 below.
    available = set(parquet.schema_arrow.names)
    read_cols = [c for c in COLUMNS if c in available]

    # One random generator per month, seeded with 42, so results are reproducible.
    rng = np.random.RandomState(SEED)

    n_original = 0
    n_filtered = 0
    sampled_parts = []

    # Stream the file in batches of CHUNK_ROWS rows instead of loading it all.
    for batch in parquet.iter_batches(batch_size=CHUNK_ROWS, columns=read_cols):
        chunk = batch.to_pandas()
        n_original += len(chunk)

        # Keep only Uber and Lyft trips.
        chunk = chunk[chunk["hvfhs_license_num"].isin(KEEP_LICENSES)]
        n_filtered += len(chunk)

        # Random 2% of this chunk. Sampling every chunk at 2% gives ~2% of the month.
        sampled_parts.append(chunk.sample(frac=SAMPLE_FRACTION, random_state=rng))

    sample = pd.concat(sampled_parts, ignore_index=True)

    # 2024 files have no cbd_congestion_fee (NYC congestion pricing began Jan 2025): use 0.
    if "cbd_congestion_fee" not in sample.columns:
        sample["cbd_congestion_fee"] = 0.0
    sample["cbd_congestion_fee"] = sample["cbd_congestion_fee"].fillna(0)

    # Label the period: 2024 = before congestion pricing, 2025 = after.
    sample["period"] = "pre" if year == 2024 else "post"

    # Keep column order identical across all months.
    sample = sample[COLUMNS + ["period"]]

    out_path = PROCESSED_DIR / f"fhvhv_sample_{year}-{month:02d}.parquet"
    sample.to_parquet(out_path, index=False)
    print(f"saved {out_path.name}: {len(sample):,} rows")

    return {
        "month": f"{year}-{month:02d}",
        "original": n_original,
        "after_uber_lyft_filter": n_filtered,
        "after_sampling": len(sample),
    }


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)

    # Zone lookup CSV and zone shapefile (not sampled, just downloaded).
    for ref in REFERENCE_FILES:
        download(ref)

    # Process each monthly trip file and collect its row counts.
    counts = [process_month(year, month) for year, month in MONTHS]

    # Summary table of row counts, printed and saved.
    table = pd.DataFrame(counts)
    print("\nRow counts per month:")
    print(table.to_string(index=False, formatters={
        c: "{:,}".format for c in table.columns if c != "month"}))
    table.to_csv(PROCESSED_DIR / "row_counts.csv", index=False)


if __name__ == "__main__":
    main()
