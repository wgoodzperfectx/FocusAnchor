"""Fit a WESAD 60 s replay artifact; validation remains the separate LOSO run."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import joblib
import pandas as pd
import yaml

from train_m1_wesad import FEATURE_PREFIXES, make_model


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(8 * 1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=Path("data/processed/wesad/windows.parquet"))
    parser.add_argument("--config", type=Path, default=Path("experiments/m1_wesad_baseline.yaml"))
    parser.add_argument("--output", type=Path, default=Path("models/m1_replay_rf60.joblib"))
    parser.add_argument("--manifest", type=Path, default=Path("reports/m1_replay_artifact.json"))
    args = parser.parse_args()
    config = yaml.safe_load(args.config.read_text(encoding="utf-8"))
    table = pd.read_parquet(args.input)
    table = table[table.window_seconds == 60]
    features = [name for name in table.columns if name.startswith(FEATURE_PREFIXES)
                and pd.api.types.is_numeric_dtype(table[name])]
    if table.empty or table[features].isna().any().any():
        raise RuntimeError("Missing 60 second WESAD feature windows")
    model = make_model("rf", config, config["seed"], table.label_binary.to_numpy(dtype=int))
    model.fit(table[features], table.label_binary)
    bounds = {name: [float(table[name].quantile(0.01)), float(table[name].quantile(0.99))]
              for name in features}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump({"model": model, "features": features, "window_seconds": 60,
                 "feature_bounds_1_99": bounds, "calibration_status": "uncalibrated",
                 "purpose": "local replay only; validation is separate LOSO experiment"}, args.output)
    result = {"input_sha256": sha256(args.input), "model_sha256": sha256(args.output),
              "subjects": int(table.subject_id.nunique()), "windows": len(table),
              "features": features, "calibration_status": "uncalibrated",
              "validation": "not evaluated; LOSO metrics are separate and do not validate this all-subject artifact"}
    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"subjects": result["subjects"], "windows": result["windows"],
                      "feature_count": len(features), "model_sha256": result["model_sha256"]}))


if __name__ == "__main__":
    main()
