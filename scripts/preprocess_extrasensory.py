"""Extract a minimal ExtraSensory activity table for offline quality assessment."""

from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import zipfile
from pathlib import Path

import numpy as np
import pandas as pd


LABELS = ("label:OR_exercise", "label:FIX_walking", "label:FIX_running")


def digest(path: Path) -> str:
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--output-dir", type=Path, default=Path("data/processed/extrasensory"))
    args = parser.parse_args()
    parts = []
    with zipfile.ZipFile(args.archive) as archive:
        names = sorted(name for name in archive.namelist() if name.endswith(".features_labels.csv.gz"))
        if len(names) != 60 or archive.testzip() is not None:
            raise ValueError("Expected 60 intact per-user files")
        for name in names:
            with archive.open(name) as raw, gzip.GzipFile(fileobj=raw) as stream:
                header = pd.read_csv(stream, nrows=0).columns.tolist()
            features = [column for column in header if column.startswith(("raw_acc:", "watch_acceleration:"))]
            columns = ["timestamp", *features, *LABELS]
            with archive.open(name) as raw, gzip.GzipFile(fileobj=raw) as stream:
                frame = pd.read_csv(stream, usecols=columns, low_memory=False)
            frame.insert(0, "user_id", name.split(".")[0])
            parts.append(frame)
            print(f"{frame.user_id.iloc[0]}: {len(frame)} rows", flush=True)
    table = pd.concat(parts, ignore_index=True)
    if table.duplicated(["user_id", "timestamp"]).any():
        raise ValueError("duplicate user/timestamp key")
    for label in LABELS:
        values = set(table[label].dropna().unique())
        if not values.issubset({0, 1}):
            raise ValueError(f"unexpected label values: {label} {values}")
    features = [column for column in table if column.startswith(("raw_acc:", "watch_acceleration:"))]
    table[features] = table[features].replace([np.inf, -np.inf], np.nan)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    output = args.output_dir / "activity.parquet"
    table.to_parquet(output, index=False)
    manifest = {
        "source_archive": str(args.archive.resolve()), "source_sha256": digest(args.archive),
        "rows": len(table), "users": int(table.user_id.nunique()),
        "feature_count": len(features), "feature_prefixes": ["raw_acc:", "watch_acceleration:"],
        "labels": {label: {"positive": int((table[label] == 1).sum()),
                           "negative": int((table[label] == 0).sum()),
                           "unknown": int(table[label].isna().sum()),
                           "known_users": int(table.loc[table[label].notna(), "user_id"].nunique()),
                           "positive_users": int(table.loc[table[label] == 1, "user_id"].nunique())}
                   for label in LABELS},
        "all_acceleration_features_missing_rows": int(table[features].isna().all(axis=1).sum()),
        "feature_missing_rate": {feature: float(table[feature].isna().mean()) for feature in features},
        "output_sha256": digest(output),
        "usage": "Offline activity context research only; not M1 stress or M2 benefit ground truth",
    }
    (args.output_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {len(table)} rows for {manifest['users']} users", flush=True)


if __name__ == "__main__":
    main()
