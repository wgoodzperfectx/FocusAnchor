"""Subject-disjoint ExtraSensory exercise-context research baseline."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
import yaml
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import average_precision_score, balanced_accuracy_score, brier_score_loss, f1_score, roc_auc_score
from sklearn.model_selection import train_test_split
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from xgboost import XGBClassifier


def digest(path: Path) -> str:
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def metrics(y: np.ndarray, p: np.ndarray) -> dict:
    pred = p >= 0.5
    ece = 0.0
    for index in range(10):
        left, right = index / 10, (index + 1) / 10
        mask = (p >= left) & (p <= right if index == 9 else p < right)
        if mask.any():
            ece += float(mask.mean() * abs(y[mask].mean() - p[mask].mean()))
    return {"rows": len(y), "positive": int(y.sum()),
            "macro_f1": float(f1_score(y, pred, average="macro", zero_division=0)),
            "balanced_accuracy": float(balanced_accuracy_score(y, pred)),
            "auroc": float(roc_auc_score(y, p)) if len(set(y)) == 2 else None,
            "auprc": float(average_precision_score(y, p)) if len(set(y)) == 2 else None,
            "ece_10": ece, "brier": float(brier_score_loss(y, p)),
            "predicted_exercise": int(pred.sum()),
            "false_exercise": int(((y == 0) & pred).sum())}


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    config_path = root / "experiments/extrasensory_activity.yaml"
    config = yaml.safe_load(config_path.read_text(encoding="utf-8"))
    source = json.loads((root / config["source_manifest"]).read_text(encoding="utf-8"))
    input_path = root / config["input"]
    if digest(input_path) != source["output_sha256"]:
        raise ValueError("processed input hash mismatch")
    frame = pd.read_parquet(input_path)
    label = config["label"]
    frame = frame.loc[frame[label].notna()].copy()
    frame = frame.loc[~frame.filter(regex="^(raw_acc:|watch_acceleration:)").isna().all(axis=1)]
    features = [column for column in frame if column.startswith(tuple(config["feature_prefixes"]))]
    users = sorted(frame.user_id.unique())
    train_users, remainder = train_test_split(users, test_size=0.4, random_state=config["seed"])
    cal_users, test_users = train_test_split(remainder, test_size=0.5, random_state=config["seed"])
    if len(set(train_users) & set(cal_users)) or len(set(train_users) & set(test_users)) or len(set(cal_users) & set(test_users)):
        raise AssertionError("user leakage")
    parts = [frame[frame.user_id.isin(group)] for group in (train_users, cal_users, test_users)]
    if any(part[label].nunique() != 2 for part in parts):
        raise ValueError("both classes required in every split")
    train, cal, test = parts
    y_train = train[label].to_numpy(dtype=int)
    y_cal = cal[label].to_numpy(dtype=int)
    y_test = test[label].to_numpy(dtype=int)
    models = {
        "lr": make_pipeline(SimpleImputer(strategy="median"), StandardScaler(),
                            LogisticRegression(max_iter=500, class_weight="balanced", random_state=config["seed"])),
        "xgb": XGBClassifier(n_estimators=150, max_depth=3, learning_rate=0.05,
                             subsample=0.8, colsample_bytree=0.8, n_jobs=4,
                             scale_pos_weight=(len(y_train) - y_train.sum()) / y_train.sum(),
                             eval_metric="logloss", random_state=config["seed"]),
    }
    output = {"config_sha256": digest(config_path), "input_sha256": digest(input_path),
              "source_sha256": source["source_sha256"], "seed": config["seed"],
              "label": label, "features": features,
              "split": {"train_users": len(train_users), "cal_users": len(cal_users),
                        "test_users": len(test_users), "train_rows": len(train),
                        "cal_rows": len(cal), "test_rows": len(test), "disjoint": True}, "models": {}}
    (root / "models/extrasensory").mkdir(parents=True, exist_ok=True)
    (root / "predictions/extrasensory").mkdir(parents=True, exist_ok=True)
    for name, model in models.items():
        model.fit(train[features], y_train)
        p_cal = model.predict_proba(cal[features])[:, 1]
        p_test = model.predict_proba(test[features])[:, 1]
        model_path = root / f"models/extrasensory/{name}.joblib"
        joblib.dump({"model": model, "features": features, "label": label,
                     "purpose": "offline research; not a G0 activity source"}, model_path)
        prediction = test[["user_id", "timestamp", label]].copy()
        prediction["probability"] = p_test
        prediction_path = root / f"predictions/extrasensory/{name}_test.parquet"
        prediction.to_parquet(prediction_path, index=False)
        output["models"][name] = {"calibration_set": metrics(y_cal, p_cal),
                                  "test": metrics(y_test, p_test),
                                  "per_user_test": {user: metrics(part[label].to_numpy(dtype=int),
                                                              p_test[test.user_id.to_numpy() == user])
                                                    for user, part in test.groupby("user_id")},
                                  "model_sha256": digest(model_path),
                                  "prediction_sha256": digest(prediction_path)}
        print(name, output["models"][name]["test"], flush=True)
    report = root / "reports/extrasensory_activity_metrics.json"
    report.write_text(json.dumps(output, indent=2, allow_nan=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
