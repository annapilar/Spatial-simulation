"""
Reads hansel2025_31258.gpkg and susi2025_31258.gpkg, rounds each GPS timestamp
to the nearest 15-minute simulation step, and writes the corresponding cycle
numbers to CSV files that the GAMA model loads for targeted location export.

Simulation clock:
  start : 2025-06-06 09:00:00
  step  : 15 minutes
  end   : 2025-09-07 11:00:00  (cycle 8936)
"""

import re
import geopandas as gpd
from datetime import datetime

START        = datetime(2025, 6, 6, 9, 0, 0)   # CEST (UTC+2), matches simulation starting_date
END          = datetime(2025, 9, 7, 11, 0, 0)   # CEST (UTC+2)
STEP_SEC     = 15 * 60
TOTAL_CYCLES = int((END - START).total_seconds() / STEP_SEC)

BASE = "C:/Users/wallentin/Desktop/GAMA/UNIGIS SpatSim/1_ASSignments/Ass4 - validation/"
OUT  = BASE + "includes/"


def parse_time(val):
    """Parse a CEST timestamp, handling multiple formats and timezone label suffixes."""
    s = str(val).strip()
    s = re.sub(r"\s*\(.*?\)", "", s).strip()  # remove e.g. "(W. Europe Summer Time)"
    for fmt in ("%Y-%m-%d %H:%M:%S", "%d/%m/%Y %H:%M:%S", "%Y-%m-%dT%H:%M:%SZ"):
        try:
            return datetime.strptime(s, fmt)
        except ValueError:
            continue
    raise ValueError(f"Unrecognised time format: {val!r}")


def extract_cycles(gpkg_path):
    gdf = gpd.read_file(gpkg_path)
    cycles = set()
    for val in gdf["time"]:
        dt = parse_time(val)
        delta_sec = (dt - START).total_seconds()
        cycle = round(delta_sec / STEP_SEC)
        if 0 <= cycle <= TOTAL_CYCLES:
            cycles.add(cycle)
    return sorted(cycles)


for cow, fname in [("hansel", "hansel2025_31258.gpkg"), ("susi", "susi2025_31258.gpkg")]:
    cycles = extract_cycles(BASE + fname)
    out_path = OUT + cow + "_export_cycles.csv"
    with open(out_path, "w") as f:
        for c in cycles:
            f.write(str(c) + "\n")
    print(f"{fname}: {len(cycles)} unique export cycles  ->  {out_path}")

print(f"\nSimulation span: cycle 0 .. {TOTAL_CYCLES}  ({TOTAL_CYCLES+1} steps)")
