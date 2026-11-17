"""Independently check generated M1/M2 split and prediction artifacts."""

from __future__ import annotations

import json
import hashlib
from pathlib import Path

import pandas as pd
from sklearn.metrics import roc_auc_score, balanced_accuracy_score, f1_score
from sklearn.model_selection import train_test_split


ROOT = Path(__file__).resolve().parents[1]


def file_hash(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> None:
    m1 = json.loads((ROOT / "reports/m1_wesad_metrics.json").read_text(encoding="utf-8"))
    windows = pd.read_parquet(ROOT / "data/processed/wesad/windows.parquet")
    seen = set()
    fold_count = 0
    for result in m1["results"]:
        model_window = (result["model"], result["window_seconds"])
        if model_window in seen or result["fold_count"] != len(result["per_subject_folds"]):
            raise ValueError(f"duplicate experiment or fold count mismatch: {model_window}")
        seen.add(model_window)
        prediction = pd.read_parquet(result["prediction_path"])
        expected = windows[windows.window_seconds == result["window_seconds"]]
        if len(prediction) != len(expected) or set(prediction.subject_id) != set(expected.subject_id):
            raise ValueError(f"M1 prediction coverage mismatch: {model_window}")
        for fold in result["per_subject_folds"]:
            train = set(fold["train_subjects"])
            calibration = set(fold["calibration_subjects"])
            test = {fold["test_subject"]}
            if not train.isdisjoint(calibration) or not train.isdisjoint(test) or not calibration.isdisjoint(test):
                raise ValueError(f"M1 subject leakage: {model_window} {test}")
            if fold["test_n"] != int((prediction.subject_id == fold["test_subject"]).sum()):
                raise ValueError(f"M1 fold prediction count mismatch: {model_window} {test}")
            fold_count += 1
    if seen != {(model, window) for model in ("rf", "xgboost") for window in (30, 60, 120)}:
        raise ValueError("M1 model/window coverage mismatch")
    if fold_count != 90:
        raise ValueError(f"M1 expected 90 folds, got {fold_count}")

    nurse_manifest = json.loads((ROOT / "data/processed/nurse/manifest.json").read_text(encoding="utf-8"))
    nurse_windows = pd.read_parquet(ROOT / "data/processed/nurse/windows.parquet")
    if file_hash(ROOT / "data/processed/nurse/windows.parquet") != nurse_manifest["output_sha256"]:
        raise ValueError("NURSE canonical window hash mismatch")
    if len(nurse_windows) != nurse_manifest["row_count"] or nurse_windows.subject_id.nunique() != 15:
        raise ValueError("NURSE canonical subject or row count mismatch")
    nurse_counts = {int(k): int(v) for k, v in nurse_windows.groupby("window_seconds").size().items()}
    if nurse_counts != {int(k): int(v) for k, v in nurse_manifest["window_counts"].items()}:
        raise ValueError("NURSE window count mismatch")
    if (nurse_windows.window_end_ms - nurse_windows.window_start_ms != nurse_windows.window_seconds * 1000).any():
        raise ValueError("NURSE time span mismatch")
    if not set(nurse_windows.label_raw).issubset({0, 1, 2}) or \
            (nurse_windows.label_binary != (nurse_windows.label_raw > 0).astype(int)).any():
        raise ValueError("NURSE unvalidated or inconsistent label")
    if nurse_windows.duplicated(["subject_id", "session_id", "window_seconds", "window_start_ms"]).any():
        raise ValueError("NURSE duplicate windows")
    for window in (30, 60, 120):
        folder = ROOT / f"data/processed/nurse/{window}s"
        manifest = json.loads((folder / "manifest.json").read_text(encoding="utf-8"))
        report = json.loads((ROOT / f"reports/m1_nurse_external_{window}s.json").read_text(encoding="utf-8"))
        windows_path = folder / "windows.parquet"
        prediction_path = folder / "external_predictions.parquet"
        if file_hash(windows_path) != manifest["windows_sha256"] or \
                file_hash(prediction_path) != report["predictions_sha256"]:
            raise ValueError(f"NURSE {window}s artifact hash mismatch")
        part = pd.read_parquet(windows_path)
        predicted = pd.read_parquet(prediction_path)
        if len(part) != nurse_counts[window] or len(predicted) != len(part):
            raise ValueError(f"NURSE {window}s prediction coverage mismatch")
        pd.testing.assert_frame_equal(predicted[part.columns], part, check_exact=True)
        if set(part.subject_id) != set(nurse_windows.subject_id):
            raise ValueError(f"NURSE {window}s subject coverage mismatch")
        if set(report["model_sha256"]) != {f"{subject}.joblib" for subject in windows.subject_id.unique()}:
            raise ValueError(f"NURSE {window}s model ensemble incomplete")
        for filename, expected_hash in report["model_sha256"].items():
            model_path = ROOT / f"models/m1/rf/{window}s" / filename
            if file_hash(model_path) != expected_hash:
                raise ValueError(f"NURSE {window}s frozen model hash mismatch: {filename}")
        y = predicted.label_binary.to_numpy(dtype=int)
        for method in ("raw", "platt", "isotonic"):
            p = predicted[f"p_{method}"].to_numpy()
            classifications = predicted[f"predicted_{method}"].to_numpy(dtype=int)
            if (classifications != (p >= 0.5).astype(int)).any():
                raise ValueError(f"NURSE {window}s {method} threshold mismatch")
            metrics = report["metrics"][method]
            if abs(roc_auc_score(y, p) - metrics["auroc"]) > 1e-12 or \
                    abs(balanced_accuracy_score(y, classifications) - metrics["balanced_accuracy"]) > 1e-12 or \
                    abs(f1_score(y, classifications, average="macro") - metrics["macro_f1"]) > 1e-12:
                raise ValueError(f"NURSE {window}s {method} metrics mismatch")

    m2 = json.loads((ROOT / "reports/m2_receptivity_metrics.json").read_text(encoding="utf-8"))
    mpud = pd.read_parquet(ROOT / "data/processed/mpud/receptivity.parquet")
    users = sorted(mpud.user.unique())
    train, remaining = train_test_split(users, test_size=0.4, random_state=m2["seed"])
    calibration, test = train_test_split(remaining, test_size=0.5, random_state=m2["seed"])
    if not set(train).isdisjoint(calibration) or not set(train).isdisjoint(test) or \
            not set(calibration).isdisjoint(test):
        raise ValueError("M2 user split overlap")
    split = m2["split"]
    if (len(train), len(calibration), len(test)) != \
            (split["train_users"], split["cal_users"], split["test_users"]):
        raise ValueError("M2 reported user counts mismatch")
    for model in ("lr", "xgb"):
        prediction = pd.read_parquet(ROOT / f"predictions/m2/{model}_test.parquet")
        if len(prediction) != split["test_rows"] or set(prediction.user) != set(test):
            raise ValueError(f"M2 held-out prediction mismatch: {model}")
    print("ARTIFACT AUDIT PASS: 6 WESAD M1 combinations, 90 disjoint folds, NURSE 3 external windows, M2 205/68/69 users")


if __name__ == "__main__":
    main()
