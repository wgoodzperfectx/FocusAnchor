"""Build a notification-time receptivity proxy table from a locally licensed MPUD ZIP.

Only prior sensor events enter features. The ESM outcome is questionnaire click,
not FocusAnchor assistance benefit or user consent.
"""

from __future__ import annotations

import argparse
from collections import deque
import csv
from datetime import datetime, timedelta
import io
import json
from pathlib import Path
import zipfile

import pandas as pd


FEATURE_EVENTS = ("Notif", "App", "Screen", "Phone", "UserAct")
FEATURES = [
    "hour_sin", "hour_cos", "is_weekend", "notif_5m", "notif_30m",
    "app_5m", "screen_5m", "phone_30m", "useract_5m",
    "screen_on", "screen_known", "battery", "battery_known",
    "noise", "noise_known", "minutes_since_esm",
]


def parse_time(value: str) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.strip())
    except ValueError:
        return None


def numeric(value: str) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def extract_subject(archive: zipfile.ZipFile, name: str) -> tuple[list[dict], dict]:
    user = Path(name).stem
    queues = {key: deque() for key in FEATURE_EVENTS}
    state: dict[str, tuple[datetime, float]] = {}
    previous_esm: datetime | None = None
    previous_ts: datetime | None = None
    stats = {"events": 0, "esm": 0, "labeled": 0, "ambiguous": 0,
             "bad_time": 0, "out_of_order": 0}
    output: list[dict] = []
    with io.TextIOWrapper(archive.open(name), encoding="utf-8-sig", errors="replace", newline="") as stream:
        reader = csv.DictReader(stream)
        for event in reader:
            stats["events"] += 1
            ts = parse_time(event.get("ts", ""))
            if ts is None:
                stats["bad_time"] += 1
                continue
            if previous_ts is not None and ts < previous_ts:
                stats["out_of_order"] += 1
            previous_ts = ts
            kind = event.get("sensor_id", "")
            for q in queues.values():
                while q and q[0] < ts - timedelta(minutes=30):
                    q.popleft()
            if kind == "Esm" and event.get("Esm_Posted"):
                stats["esm"] += 1
                posted = parse_time(event["Esm_Posted"])
                clicked = parse_time(event.get("Esm_Clicked", ""))
                timedout = parse_time(event.get("Esm_Timedout", ""))
                if posted is None or abs((posted - ts).total_seconds()) > 120:
                    stats["ambiguous"] += 1
                    continue
                if clicked and posted <= clicked <= posted + timedelta(minutes=10):
                    label = 1
                elif timedout and timedout >= posted and not clicked:
                    label = 0
                else:
                    stats["ambiguous"] += 1
                    previous_esm = posted
                    continue
                import math
                hour = posted.hour + posted.minute / 60
                row = {
                    "user": user, "posted": posted.isoformat(), "clicked_10m": label,
                    "hour_sin": math.sin(2 * math.pi * hour / 24),
                    "hour_cos": math.cos(2 * math.pi * hour / 24),
                    "is_weekend": int(posted.weekday() >= 5),
                    "screen_known": int("screen" in state),
                    "screen_on": state.get("screen", (ts, 0))[1],
                    "battery_known": int("battery" in state),
                    "battery": state.get("battery", (ts, 50))[1],
                    "noise_known": int("noise" in state),
                    "noise": state.get("noise", (ts, 0))[1],
                    "minutes_since_esm": min(1440, (posted - previous_esm).total_seconds() / 60) if previous_esm else 1440,
                }
                for sensor, col, minutes in [
                    ("Notif", "notif_5m", 5), ("Notif", "notif_30m", 30),
                    ("App", "app_5m", 5), ("Screen", "screen_5m", 5),
                    ("Phone", "phone_30m", 30), ("UserAct", "useract_5m", 5),
                ]:
                    row[col] = sum(t < posted and t >= posted - timedelta(minutes=minutes) for t in queues[sensor])
                output.append(row)
                stats["labeled"] += 1
                previous_esm = posted
                continue
            if kind in queues:
                queues[kind].append(ts)
            if kind == "Screen" and event.get("Screen_Value"):
                state["screen"] = (ts, int(event["Screen_Value"].lower() in {"on", "unlocked"}))
            elif kind == "Batt":
                value = numeric(event.get("Batt_Value", ""))
                if value is not None and 0 <= value <= 100:
                    state["battery"] = (ts, value)
            elif kind == "Noise":
                value = numeric(event.get("Noise_Value", ""))
                if value is not None and 0 <= value <= 120:
                    state["noise"] = (ts, value)
    return output, stats


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path("data/processed/mpud/receptivity.parquet"))
    parser.add_argument("--manifest", type=Path, default=Path("data/processed/mpud/manifest.json"))
    args = parser.parse_args()
    records: list[dict] = []
    counts = {"users": 0, "events": 0, "esm": 0, "labeled": 0,
              "ambiguous": 0, "bad_time": 0, "out_of_order": 0}
    with zipfile.ZipFile(args.archive) as archive:
        names = sorted(n for n in archive.namelist() if n.endswith(".csv") and "/data/" in n)
        for n in names:
            rows, stats = extract_subject(archive, n)
            records.extend(rows)
            counts["users"] += 1
            for key, value in stats.items():
                counts[key] += value
    df = pd.DataFrame.from_records(records)
    if df.empty:
        raise RuntimeError("No labeled ESM events")
    if counts["out_of_order"]:
        raise RuntimeError(f"Source events out of order: {counts['out_of_order']}; temporal features unsafe")
    duplicate_keys = df.duplicated(["user", "posted"], keep=False)
    conflicts = df.loc[duplicate_keys].groupby(["user", "posted"])["clicked_10m"].nunique()
    conflict_keys = conflicts[conflicts > 1].index
    counts["conflicting_esm_keys_excluded"] = len(conflict_keys)
    if len(conflict_keys):
        df = df.set_index(["user", "posted"]).drop(index=conflict_keys).reset_index()
    counts["duplicate_esm_rows_removed"] = int(df.duplicated(["user", "posted"]).sum())
    df = df.drop_duplicates(["user", "posted"], keep="first")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    df.to_parquet(args.output, index=False)
    manifest = {"source_archive": args.archive.name, "counts": counts,
                "label": "ESM questionnaire notification clicked within 10 minutes; timeout without click is negative",
                "feature_cutoff": "strictly before Esm_Posted; no ESM outcome or post-event sensor values",
                "features": FEATURES, "rows": len(df), "positive": int(df.clicked_10m.sum())}
    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({"rows": len(df), "positive": manifest["positive"], **counts}))


if __name__ == "__main__":
    main()
