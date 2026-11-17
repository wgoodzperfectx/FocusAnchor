"""Frozen WESAD RF fold ensemble on validated NURSE survey intervals.

This is an offline, selected-event external test, not continuous detection.
NURSE labels are read only for evaluation; no model fitting or threshold tuning.
"""

import argparse
import io
import json
import zipfile
from collections import Counter
from datetime import datetime, time, timedelta, timezone
from pathlib import Path

import joblib
import numpy as np
import openpyxl
import pandas as pd
from sklearn.metrics import average_precision_score, balanced_accuracy_score, brier_score_loss, confusion_matrix, f1_score, roc_auc_score

from preprocess_wesad import window_features, sha256_file, WRIST_HZ
from train_m1_wesad import expected_calibration_error, logit


UTC_OFFSET_HOURS = 6  # Paper states collection in CST, six hours behind GMT.
EXPECTED_HASH = "86e7146cbb124f9b5e37bc5bd8fa63f8786379dfdb10dfc9fdc5fd6c41e63407"
EXPECTED_SURVEY_HASH = "4ee7733f8e8da362af33a765c495f4a5ed8302b5af39327c2cdb420a27def2b3"


def survey_events(path: Path):
    book = openpyxl.load_workbook(path, read_only=True, data_only=True)
    events, counts = [], Counter()
    try:
        for row in list(book.active.values)[1:]:
            if row[0] is None:
                continue
            counts["nonblank_id"] += 1
            label = str(row[5]).strip()
            if label not in ("0", "1", "2"):
                counts["unvalidated_label"] += 1
                continue
            day, start, end = row[4], row[1], row[2]
            if not isinstance(day, datetime) or not isinstance(start, time) or not isinstance(end, time):
                counts["invalid_time"] += 1
                continue
            begin = datetime.combine(day.date(), start, tzinfo=timezone.utc) + timedelta(hours=UTC_OFFSET_HOURS)
            finish = datetime.combine(day.date(), end, tzinfo=timezone.utc) + timedelta(hours=UTC_OFFSET_HOURS)
            if finish <= begin:
                finish += timedelta(days=1)
            events.append((str(row[0]), begin.timestamp(), finish.timestamp(), int(label)))
            counts[f"label_{label}"] += 1
    finally:
        book.close()
    return events, dict(counts)


def read_channel(inner, channel):
    raw = inner.read(f"{channel}.csv")
    if not raw:
        return None
    lines = raw.splitlines()
    if len(lines) < 3:
        return None
    first = np.fromstring(lines[0].decode(), sep=",")
    rate = np.fromstring(lines[1].decode(), sep=",")
    if not len(first) or not len(rate) or int(rate[0]) != WRIST_HZ[channel]:
        return None
    values = np.loadtxt(io.BytesIO(b"\n".join(lines[2:])), delimiter=",")
    if channel == "ACC" and (values.ndim != 2 or values.shape[1] != 3):
        return None
    return float(first[0]), values


def collect(archive: Path, events, window):
    by_subject = {}
    for subject, begin, end, label in events:
        by_subject.setdefault(subject, []).append((begin, end, label))
    rows, reasons = [], Counter()
    with zipfile.ZipFile(archive) as outer:
        members = [name for name in outer.namelist() if name.endswith(".zip")]
        for index, name in enumerate(members, 1):
            subject = name.split("/")[0]
            if subject not in by_subject:
                continue
            try:
                with zipfile.ZipFile(io.BytesIO(outer.read(name))) as inner:
                    # EDA is enough to skip sessions with no survey-time overlap.
                    eda = read_channel(inner, "EDA")
                    if eda is None:
                        reasons["eda_missing_or_invalid"] += 1
                        continue
                    session_start = eda[0]
                    session_end = session_start + len(eda[1]) / WRIST_HZ["EDA"]
                    matched = [(a, b, label) for a, b, label in by_subject[subject]
                               if a < session_end and b > session_start]
                    if not matched:
                        reasons["no_survey_overlap"] += 1
                        continue
                    channels = {"EDA": eda}
                    for key in ("BVP", "TEMP", "ACC"):
                        channels[key] = read_channel(inner, key)
                    if any(value is None for value in channels.values()):
                        reasons["missing_channel"] += 1
                        continue
                    # The WESAD feature extractor assumes equal sensor epochs.
                    if any(abs(value[0] - session_start) > 1 for value in channels.values()):
                        reasons["misaligned_channel"] += 1
                        continue
                    wrist = {key: value[1] for key, value in channels.items()}
                    duration = min(len(wrist[key]) / hz for key, hz in WRIST_HZ.items())
                    for begin, end, label in matched:
                        left = max(begin, session_start)
                        right = min(end, session_start + duration)
                        # Align non-overlapping windows to the session clock.
                        first_second = int(np.ceil((left - session_start) / window)) * window
                        last_second = int(np.floor((right - session_start) / window)) * window
                        for start_second in range(first_second, last_second, window):
                            features = window_features(wrist, start_second, window)
                            rows.append({"dataset": "nurse", "subject_id": subject, "session_id": name,
                                         "time_reference": "unix_epoch_utc_from_e4_and_cst_survey",
                                         "window_seconds": window,
                                         "window_start_epoch": int(session_start + start_second),
                                         "window_end_epoch": int(session_start + start_second + window),
                                         "window_start_ms": int((session_start + start_second) * 1000),
                                         "window_end_ms": int((session_start + start_second + window) * 1000),
                                         "label_raw": label, "label_binary": int(label > 0),
                                         "label_provenance": "SurveyResults.xlsx:validated_event_level",
                                         **features})
                    reasons["overlapping_sessions"] += 1
            except (zipfile.BadZipFile, KeyError, ValueError, OSError) as exc:
                reasons[f"session_error_{type(exc).__name__}"] += 1
            if index % 100 == 0:
                print(f"scanned {index}/{len(members)} sessions; candidate windows {len(rows)}", flush=True)
    frame = pd.DataFrame(rows)
    if frame.empty:
        raise ValueError("no NURSE windows aligned to validated survey intervals")
    group = frame.groupby(["subject_id", "session_id", "window_start_epoch"])
    conflicting = group.label_binary.nunique() > 1
    reasons["conflicting_windows"] = int(conflicting.sum())
    frame = frame.loc[~frame.set_index(["subject_id", "session_id", "window_start_epoch"]).index.isin(conflicting[conflicting].index)]
    frame = frame.drop_duplicates(["subject_id", "session_id", "window_start_epoch"])
    reasons["invalid_quality_windows"] = int((frame.signal_quality == "invalid").sum())
    frame = frame.loc[frame.signal_quality != "invalid"].copy()
    return frame, dict(reasons), len(members)


def evaluate(frame, model_dir):
    bundles = [joblib.load(path) for path in sorted(model_dir.glob("S*.joblib"))]
    if len(bundles) != 15:
        raise ValueError(f"expected 15 frozen WESAD fold models, got {len(bundles)}")
    features = bundles[0]["features"]
    if any(bundle["features"] != features for bundle in bundles):
        raise ValueError("model feature lists differ")
    if frame[features].isna().any().any() or not np.isfinite(frame[features].to_numpy()).all():
        raise ValueError("non-finite external features")
    y = frame.label_binary.to_numpy(dtype=int)
    probabilities = {method: [] for method in ("raw", "platt", "isotonic")}
    for bundle in bundles:
        raw = bundle["model"].predict_proba(frame[features])[:, 1]
        probabilities["raw"].append(raw)
        probabilities["platt"].append(bundle["platt"].predict_proba(logit(raw).reshape(-1, 1))[:, 1])
        probabilities["isotonic"].append(bundle["isotonic"].predict(raw))
    probability = {method: np.mean(values, axis=0) for method, values in probabilities.items()}
    result = {}
    for method, p in probability.items():
        pred = (p >= 0.5).astype(int)
        retained = np.abs(p - 0.5) > 0.1
        result[method] = {"n": len(y), "subjects": int(frame.subject_id.nunique()),
                          "positive_n": int(y.sum()), "negative_n": int(len(y) - y.sum()),
                          "macro_f1": float(f1_score(y, pred, average="macro", zero_division=0)),
                          "balanced_accuracy": float(balanced_accuracy_score(y, pred)),
                          "auroc": float(roc_auc_score(y, p)) if len(np.unique(y)) == 2 else None,
                          "auprc": float(average_precision_score(y, p)) if len(np.unique(y)) == 2 else None,
                          "ece": float(expected_calibration_error(y, p, 10)),
                          "brier": float(brier_score_loss(y, p)),
                          "confusion_tn_fp_fn_tp": confusion_matrix(y, pred, labels=[0, 1]).ravel().tolist(),
                          "abstain_margin": 0.1, "abstain_rate": float((~retained).mean()),
                          "retained_n": int(retained.sum()),
                          "retained_balanced_accuracy": float(balanced_accuracy_score(y[retained], pred[retained]))
                          if retained.any() and len(np.unique(y[retained])) == 2 else None}
        frame[f"p_{method}"] = p
        frame[f"predicted_{method}"] = pred
    per_subject = []
    for subject, part in frame.groupby("subject_id"):
        labels = part.label_binary.to_numpy(dtype=int)
        raw = part.p_raw.to_numpy()
        per_subject.append({"subject_id": subject, "n": len(part), "positive_n": int(labels.sum()),
                            "predicted_positive_n": int(part.predicted_raw.sum()),
                            "auroc": float(roc_auc_score(labels, raw)) if len(np.unique(labels)) == 2 else None,
                            "balanced_accuracy": float(balanced_accuracy_score(labels, part.predicted_raw)) if len(np.unique(labels)) == 2 else None})
    return frame, result, per_subject


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--survey", type=Path, required=True)
    parser.add_argument("--window", type=int, choices=(30, 60, 120), default=60)
    parser.add_argument("--model-dir", type=Path)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    model_dir = args.model_dir or Path(f"models/m1/rf/{args.window}s")
    output_dir = args.output_dir or Path(f"data/processed/nurse/{args.window}s")
    report_path = args.report or Path(f"reports/m1_nurse_external_{args.window}s.json")
    if sha256_file(args.archive).lower() != EXPECTED_HASH:
        raise ValueError("NURSE archive SHA256 does not match official metadata")
    if sha256_file(args.survey).lower() != EXPECTED_SURVEY_HASH:
        raise ValueError("NURSE survey SHA256 does not match the reviewed official file")
    events, survey_counts = survey_events(args.survey)
    frame, reasons, sessions = collect(args.archive, events, args.window)
    output_dir.mkdir(parents=True, exist_ok=True)
    windows = output_dir / "windows.parquet"
    frame.to_parquet(windows, index=False)
    manifest = {"dataset": "nurse", "window_seconds": args.window, "stride": "non_overlapping",
                "source_archive_sha256": EXPECTED_HASH, "survey_sha256": EXPECTED_SURVEY_HASH,
                "label_definition": "survey 0=no stress, 1=medium, 2=high, na excluded; binary=1 for 1/2",
                "time_reference": "unix_epoch_utc_from_e4_and_cst_survey",
                "subjects": sorted(frame.subject_id.unique().tolist()), "subject_count": int(frame.subject_id.nunique()),
                "row_count": len(frame), "quality_counts": frame.signal_quality.value_counts().to_dict(),
                "label_counts": {str(k): int(v) for k, v in frame.label_raw.value_counts().items()},
                "exclusions": reasons, "windows_path": str(windows), "windows_sha256": sha256_file(windows)}
    (output_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    frame, metrics, per_subject = evaluate(frame, model_dir)
    predictions = output_dir / "external_predictions.parquet"
    frame.to_parquet(predictions, index=False)
    report = {"protocol": f"WESAD RF {args.window}s frozen 15-fold ensemble; raw/Platt/isotonic calibrated on WESAD only; 0.5 threshold and 0.1 abstain margin; no NURSE training or tuning",
              "scope": "only validated survey event intervals; selection bias; not continuous stress detection",
              "timezone": "survey local CST +06:00 to UTC per source paper; DST ambiguity retained as limitation",
              "label_mapping": "NURSE 0=no stress, 1=medium, 2=high; binary positive=1/2",
              "archive_sha256": sha256_file(args.archive), "survey_sha256": sha256_file(args.survey),
              "model_sha256": {path.name: sha256_file(path) for path in sorted(model_dir.glob("S*.joblib"))},
              "sessions_in_archive": sessions, "survey_counts": survey_counts, "exclusions": reasons,
              "quality_counts": frame.signal_quality.value_counts().to_dict(),
              "label_counts": {str(k): int(v) for k, v in frame.label_raw.value_counts().items()},
              "metrics": metrics, "per_subject": per_subject,
              "windows_path": str(windows), "windows_sha256": sha256_file(windows),
              "predictions_path": str(predictions), "predictions_sha256": sha256_file(predictions)}
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"metrics": metrics, "exclusions": reasons}, indent=2), flush=True)


if __name__ == "__main__":
    main()
