"""WESAD wrist-only, subject-safe window features from the original ZIP.

The output is research data, not a FocusAnchor user state or live signal.
Only unpickle WESAD archives whose source and allowed use have been reviewed.
"""

import argparse
import hashlib
import json
import pickle
import zipfile
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import pandas as pd


WINDOWS_SEC = (30, 60, 120)
LABEL_HZ = 700
WRIST_HZ = {"BVP": 64, "EDA": 4, "TEMP": 4, "ACC": 32}
ALLOWED_PICKLE_CLASSES = {
    ("numpy.core.multiarray", "_reconstruct"),
    ("numpy._core.multiarray", "_reconstruct"),
    ("numpy", "ndarray"),
    ("numpy", "dtype"),
}


class RestrictedNumpyUnpickler(pickle.Unpickler):
    def find_class(self, module: str, name: str):
        if (module, name) not in ALLOWED_PICKLE_CLASSES:
            raise pickle.UnpicklingError(f"disallowed pickle class: {module}.{name}")
        return super().find_class(module, name)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def scalar_features(values: np.ndarray, prefix: str) -> dict:
    flat = np.asarray(values, dtype=np.float64).reshape(-1)
    finite = flat[np.isfinite(flat)]
    result = {f"{prefix}_missing_rate": float(1 - len(finite) / len(flat)) if len(flat) else 1.0}
    if len(finite):
        result.update({f"{prefix}_mean": float(np.mean(finite)),
                       f"{prefix}_std": float(np.std(finite)),
                       f"{prefix}_min": float(np.min(finite)),
                       f"{prefix}_max": float(np.max(finite)),
                       f"{prefix}_delta": float(finite[-1] - finite[0])})
    else:
        result.update({f"{prefix}_{key}": np.nan for key in ("mean", "std", "min", "max", "delta")})
    return result


def window_features(wrist: dict, start_sec: int, duration_sec: int) -> dict:
    result = {}
    anomalies = []
    for channel, hz in WRIST_HZ.items():
        begin, end = start_sec * hz, (start_sec + duration_sec) * hz
        arr = np.asarray(wrist[channel][begin:end], dtype=np.float64)
        expected = duration_sec * hz
        if channel == "ACC":
            if arr.ndim != 2 or arr.shape[1] != 3:
                raise ValueError(f"ACC shape unexpected: {arr.shape}")
            sample_finite = np.all(np.isfinite(arr), axis=1)
            mag = np.linalg.norm(arr, axis=1) / 64.0  # E4 ACC is in 1/64 g.
            result.update(scalar_features(mag, "acc_magnitude_g"))
            result["acc_missing_rate"] = float(1 - sample_finite.sum() / expected)
            anomaly = float(np.mean((mag[sample_finite] > 16) | (mag[sample_finite] < 0))) if sample_finite.any() else 1.0
        else:
            flat = arr.reshape(-1)
            result.update(scalar_features(flat, channel.lower()))
            finite = flat[np.isfinite(flat)]
            if channel == "EDA":
                anomaly = float(np.mean(finite < 0)) if len(finite) else 1.0
            elif channel == "TEMP":
                anomaly = float(np.mean((finite < 20) | (finite > 45))) if len(finite) else 1.0
            else:
                anomaly = 0.0
        if len(arr) != expected:
            anomalies.append(f"{channel}_short")
            result[f"{channel.lower()}_missing_rate"] = max(
                result.get(f"{channel.lower()}_missing_rate", 0.0), 1 - len(arr) / expected)
        if anomaly > 0.05:
            anomalies.append(f"{channel}_implausible")
        result[f"{channel.lower()}_anomaly_rate"] = anomaly
    missing = max(float(result[key]) for key in result if key.endswith("_missing_rate"))
    anomalous = max(float(result[key]) for key in result if key.endswith("_anomaly_rate"))
    if missing > 0.2 or anomalous > 0.2:
        quality = "invalid"
    elif missing > 0.05 or anomalous > 0.05:
        quality = "degraded"
    else:
        quality = "good"
    result.update({"signal_quality": quality, "missing_rate": missing,
                   "quality_flags": ";".join(anomalies)})
    return result


def process_subject(package: zipfile.ZipFile, subject: str, purity: float) -> tuple[list[dict], dict]:
    member = f"WESAD/{subject}/{subject}.pkl"
    with package.open(member) as stream:
        data = RestrictedNumpyUnpickler(stream, encoding="latin1").load()
    if str(data["subject"]) != subject:
        raise ValueError(f"subject mismatch in {member}")
    wrist = data["signal"]["wrist"]
    labels = np.asarray(data["label"]).reshape(-1)
    lengths = {name: len(wrist[name]) for name in WRIST_HZ}
    duration_sec = min([len(labels) // LABEL_HZ] +
                       [lengths[name] // hz for name, hz in WRIST_HZ.items()])
    if duration_sec <= 0:
        raise ValueError(f"no aligned duration in {member}")
    records = []
    excluded = Counter()
    for duration in WINDOWS_SEC:
        for start in range(0, duration_sec - duration + 1, duration):
            segment = labels[start * LABEL_HZ:(start + duration) * LABEL_HZ]
            counts = np.bincount(segment.astype(np.int64), minlength=8)
            raw = int(np.argmax(counts))
            fraction = float(counts[raw] / len(segment))
            if raw not in (1, 2, 3) or fraction < purity:
                excluded[f"{duration}s_label_or_transition"] += 1
                continue
            features = window_features(wrist, start, duration)
            records.append({"dataset": "wesad", "subject_id": subject,
                            "session_id": subject, "time_reference": "relative_to_synchronized_recording",
                            "window_seconds": duration, "window_start_ms": start * 1000,
                            "window_end_ms": (start + duration) * 1000,
                            "label_raw": raw, "label_binary": int(raw == 2),
                            "label_purity": fraction,
                            "label_provenance": f"{member}:label_700hz_protocol_condition",
                            **features})
    summary = {"subject_id": subject, "label_samples": len(labels),
               "wrist_samples": lengths, "aligned_duration_sec": duration_sec,
               "raw_label_counts": {str(int(k)): int(v) for k, v in zip(*np.unique(labels, return_counts=True))},
               "retained_windows": dict(Counter(str(row["window_seconds"]) for row in records)),
               "excluded_windows": dict(excluded)}
    return records, summary


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--subjects", nargs="*", help="Debug subset only; omit for all subjects")
    parser.add_argument("--min-label-purity", type=float, default=0.95)
    args = parser.parse_args()
    if not (0 < args.min_label_purity <= 1):
        parser.error("--min-label-purity must be in (0,1]")
    archive = args.archive.resolve()
    if not archive.is_file():
        parser.error(f"archive missing: {archive}")
    with zipfile.ZipFile(archive) as package:
        all_subjects = sorted({name.split("/")[1] for name in package.namelist()
                               if name.startswith("WESAD/S") and name.count("/") >= 2},
                              key=lambda item: int(item[1:]))
        subjects = args.subjects or all_subjects
        if not set(subjects).issubset(all_subjects):
            parser.error("unknown subject in --subjects")
        rows, summaries = [], []
        for subject in subjects:
            part, summary = process_subject(package, subject, args.min_label_purity)
            rows.extend(part)
            summaries.append(summary)
            print(f"{subject}: {len(part)} retained windows", flush=True)
    if not rows:
        raise ValueError("no valid windows")
    frame = pd.DataFrame(rows).sort_values(
        ["subject_id", "window_seconds", "window_start_ms"], kind="stable").reset_index(drop=True)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    output = args.output_dir / "windows.parquet"
    frame.to_parquet(output, index=False)
    manifest = {"schema_version": "1.0", "generated_at_utc": datetime.now(timezone.utc).isoformat(),
                "source_archive": str(archive), "source_sha256": sha256_file(archive),
                "label_definition": "1 baseline, 2 stress, 3 amusement; binary=1 only for stress",
                "window_seconds": list(WINDOWS_SEC), "stride": "non_overlapping",
                "min_label_purity": args.min_label_purity,
                "time_reference": "relative_to_synchronized_recording",
                "subjects": subjects, "subject_count": len(subjects),
                "row_count": len(frame), "window_counts": {str(k): int(v) for k, v in frame.groupby("window_seconds").size().items()},
                "quality_counts": {str(k): int(v) for k, v in frame.groupby("signal_quality").size().items()},
                "label_counts": {str(k): int(v) for k, v in frame.groupby("label_binary").size().items()},
                "subject_summaries": summaries, "output_parquet": str(output),
                "output_sha256": sha256_file(output)}
    (args.output_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"wrote {output}: {len(frame)} rows, {len(subjects)} subjects")


if __name__ == "__main__":
    main()
