"""Train subject-disjoint MPUD questionnaire-click proxy baselines."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import average_precision_score, balanced_accuracy_score, brier_score_loss, f1_score, roc_auc_score
from sklearn.model_selection import train_test_split
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from xgboost import XGBClassifier

from preprocess_mpud import FEATURES


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def ece(y: np.ndarray, p: np.ndarray, bins: int = 10) -> float:
    result = 0.0
    for left, right in zip(np.linspace(0, 1, bins + 1)[:-1], np.linspace(0, 1, bins + 1)[1:]):
        mask = (p >= left) & (p <= right if right == 1 else p < right)
        if mask.any():
            result += float(mask.mean() * abs(y[mask].mean() - p[mask].mean()))
    return result


def metrics(y: np.ndarray, p: np.ndarray) -> dict:
    pred = p >= 0.5
    false_positive = int(((y == 0) & pred).sum())
    positive_decisions = int(pred.sum())
    return {
        "rows": len(y), "positive_rate": float(y.mean()),
        "macro_f1": float(f1_score(y, pred, average="macro", zero_division=0)),
        "balanced_accuracy": float(balanced_accuracy_score(y, pred)),
        "auroc": float(roc_auc_score(y, p)),
        "auprc": float(average_precision_score(y, p)),
        "ece_10": ece(y, p), "brier": float(brier_score_loss(y, p)),
        "false_interruption_rate_proxy": false_positive / positive_decisions if positive_decisions else None,
        "false_positive_count": false_positive, "predicted_positive_count": positive_decisions,
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", type=Path, default=Path("data/processed/mpud/receptivity.parquet"))
    ap.add_argument("--metrics", type=Path, default=Path("reports/m2_receptivity_metrics.json"))
    ap.add_argument("--model-dir", type=Path, default=Path("models"))
    ap.add_argument("--prediction-dir", type=Path, default=Path("predictions/m2"))
    args = ap.parse_args()
    frame = pd.read_parquet(args.input)
    if frame.empty or frame["user"].nunique() < 10:
        raise RuntimeError("Insufficient subject-diverse data")
    users = sorted(frame.user.unique())
    train_users, remaining = train_test_split(users, test_size=0.4, random_state=1337)
    cal_users, test_users = train_test_split(remaining, test_size=0.5, random_state=1337)
    sets = [set(train_users), set(cal_users), set(test_users)]
    assert not (sets[0] & sets[1] or sets[0] & sets[2] or sets[1] & sets[2])
    train = frame[frame.user.isin(train_users)]
    cal = frame[frame.user.isin(cal_users)]
    test = frame[frame.user.isin(test_users)]
    x_train = train[FEATURES].to_numpy(dtype=float)
    x_cal = cal[FEATURES].to_numpy(dtype=float)
    x_test = test[FEATURES].to_numpy(dtype=float)
    y_train = train.clicked_10m.to_numpy(dtype=int)
    y_cal = cal.clicked_10m.to_numpy(dtype=int)
    y_test = test.clicked_10m.to_numpy(dtype=int)
    if any(len(set(y)) < 2 for y in (y_train, y_cal, y_test)):
        raise RuntimeError("A split has a single outcome class")
    models = {
        "lr": make_pipeline(SimpleImputer(strategy="median"), StandardScaler(), LogisticRegression(max_iter=1000, random_state=1337)),
        "xgb": XGBClassifier(n_estimators=250, max_depth=3, learning_rate=0.05,
                             subsample=0.8, colsample_bytree=0.8, n_jobs=4,
                             random_state=1337, eval_metric="logloss"),
    }
    result = {"input_sha256": digest(args.input), "seed": 1337, "features": FEATURES,
              "split": {"train_users": len(train_users), "cal_users": len(cal_users), "test_users": len(test_users),
                        "train_rows": len(train), "cal_rows": len(cal), "test_rows": len(test),
                        "disjoint": True}, "models": {}}
    args.model_dir.mkdir(parents=True, exist_ok=True)
    args.prediction_dir.mkdir(parents=True, exist_ok=True)
    bounds = {name: [float(train[name].quantile(0.01)), float(train[name].quantile(0.99))]
              for name in FEATURES}
    for name, model in models.items():
        model.fit(x_train, y_train)
        raw_cal = model.predict_proba(x_cal)[:, 1]
        raw_test = model.predict_proba(x_test)[:, 1]
        calibration = LogisticRegression(C=10000, random_state=1337)
        calibration.fit(raw_cal.reshape(-1, 1), y_cal)
        calibrated_cal = calibration.predict_proba(raw_cal.reshape(-1, 1))[:, 1]
        calibrated_test = calibration.predict_proba(raw_test.reshape(-1, 1))[:, 1]
        cal_metrics = {"raw": metrics(y_cal, raw_cal), "platt": metrics(y_cal, calibrated_cal)}
        selected_probability = min(("raw", "platt"), key=lambda option: cal_metrics[option]["brier"])
        path = args.model_dir / f"m2_receptivity_{name}.joblib"
        joblib.dump({"model": model, "calibration": calibration, "features": FEATURES,
                     "label": "ESM questionnaire click proxy", "seed": 1337,
                     "feature_bounds_1_99": bounds,
                     "selected_probability_by_calibration_brier": selected_probability}, path)
        predictions = test[["user", "posted", "clicked_10m"]].copy()
        predictions["raw_probability"] = raw_test
        predictions["platt_probability"] = calibrated_test
        prediction_path = args.prediction_dir / f"{name}_test.parquet"
        predictions.to_parquet(prediction_path, index=False)
        result["models"][name] = {"calibration_set": cal_metrics,
                                  "selected_probability_by_calibration_brier": selected_probability,
                                  "raw": metrics(y_test, raw_test),
                                  "platt": metrics(y_test, calibrated_test),
                                  "model_sha256": digest(path),
                                  "prediction_sha256": digest(prediction_path)}
    args.metrics.parent.mkdir(parents=True, exist_ok=True)
    args.metrics.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"split": result["split"], "models": {k: v["raw"] for k, v in result["models"].items()}}, indent=2))


if __name__ == "__main__":
    main()
