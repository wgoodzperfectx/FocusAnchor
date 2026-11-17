"""Create synthetic replay fixtures from aggregate feature medians, never source rows."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import joblib
import pandas as pd


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=Path("service/replay_fixtures.json"))
    args = parser.parse_args()
    m1 = joblib.load("models/m1_replay_rf60.joblib")
    m2 = joblib.load("models/m2_receptivity_xgb.joblib")
    wesad = pd.read_parquet("data/processed/wesad/windows.parquet")
    wesad = wesad[wesad.window_seconds == 60]
    mpud = pd.read_parquet("data/processed/mpud/receptivity.parquet")
    m1_features = {name: float(wesad[name].median()) for name in m1["features"]}
    m2_features = {name: float(mpud[name].median()) for name in m2["features"]}
    fixtures = [
        {"name": "wesad_aggregate_median_good", "target": "/v1/m1/estimate",
         "request": {"schema_version": "0.1-replay", "source": "replay", "timestamp_ms": 0,
                     "window_seconds": 60, "signal_quality": "good", "features": m1_features}},
        {"name": "wesad_aggregate_median_bad_quality", "target": "/v1/m1/estimate",
         "request": {"schema_version": "0.1-replay", "source": "replay", "timestamp_ms": 0,
                     "window_seconds": 60, "signal_quality": "invalid", "features": m1_features}},
        {"name": "mpud_aggregate_median_context", "target": "/v1/m2/decision-candidate",
         "request": {"schema_version": "0.1-replay", "source": "replay", "timestamp_ms": 0,
                     "context_quality": "good", "features": m2_features,
                     "task_context": {"task_status": "pending", "user_requested_help": False}}},
    ]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(fixtures, indent=2) + "\n", encoding="utf-8")
    print(f"synthetic fixtures: {len(fixtures)}")


if __name__ == "__main__":
    main()
