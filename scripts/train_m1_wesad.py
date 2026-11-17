"""Subject-disjoint WESAD RF/XGBoost baselines with held-out calibration.

Outputs are research predictions only. No decision or Agent is invoked.
"""

import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
import sklearn
import xgboost
import yaml
from sklearn.ensemble import RandomForestClassifier
from sklearn.isotonic import IsotonicRegression
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (average_precision_score, balanced_accuracy_score,
                             brier_score_loss, confusion_matrix, f1_score,
                             roc_auc_score)
from xgboost import XGBClassifier


FEATURE_PREFIXES = ("bvp_", "eda_", "temp_", "acc_")


def file_hash(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def logit(probability: np.ndarray) -> np.ndarray:
    clipped = np.clip(probability, 1e-6, 1 - 1e-6)
    return np.log(clipped / (1 - clipped))


def expected_calibration_error(y: np.ndarray, p: np.ndarray, bins: int) -> float:
    boundaries = np.linspace(0, 1, bins + 1)
    error = 0.0
    for index in range(bins):
        mask = (p >= boundaries[index]) & (p < boundaries[index + 1] if index < bins - 1 else p <= 1)
        if mask.any():
            error += float(mask.mean() * abs(y[mask].mean() - p[mask].mean()))
    return error


def metrics(y: np.ndarray, p: np.ndarray, bins: int, margin: float, logistic_c: float) -> dict:
    predicted = (p >= 0.5).astype(int)
    slope_fit = LogisticRegression(C=logistic_c, max_iter=1000).fit(logit(p).reshape(-1, 1), y)
    abstain = np.abs(p - 0.5) <= margin
    return {
        "n": int(len(y)), "positive_n": int(y.sum()),
        "macro_f1": float(f1_score(y, predicted, average="macro", zero_division=0)),
        "balanced_accuracy": float(balanced_accuracy_score(y, predicted)),
        "auroc": float(roc_auc_score(y, p)),
        "auprc": float(average_precision_score(y, p)),
        "ece": expected_calibration_error(y, p, bins),
        "brier": float(brier_score_loss(y, p)),
        "calibration_intercept": float(slope_fit.intercept_[0]),
        "calibration_slope": float(slope_fit.coef_[0, 0]),
        "confusion_matrix_tn_fp_fn_tp": confusion_matrix(y, predicted, labels=[0, 1]).ravel().astype(int).tolist(),
        "experimental_abstain_rate": float(abstain.mean()),
        "experimental_coverage": float((~abstain).mean()),
    }


def make_model(kind: str, cfg: dict, seed: int, y_train: np.ndarray):
    if kind == "rf":
        return RandomForestClassifier(**cfg["rf"], random_state=seed)
    if kind == "xgboost":
        positive = int(y_train.sum())
        negative = int(len(y_train) - positive)
        return XGBClassifier(**cfg["xgboost"], random_state=seed,
                             objective="binary:logistic", eval_metric="logloss",
                             tree_method="hist", scale_pos_weight=negative / positive)
    raise ValueError(f"unknown model: {kind}")


def run_experiment(frame: pd.DataFrame, cfg: dict, kind: str, window: int, root: Path) -> dict:
    subset = frame.loc[frame.window_seconds == window].copy()
    feature_names = [name for name in subset.columns if name.startswith(FEATURE_PREFIXES)
                     and pd.api.types.is_numeric_dtype(subset[name])]
    if not feature_names or subset[feature_names].isna().any().any():
        raise ValueError(f"missing or non-finite model features for {window}s")
    subjects = sorted(subset.subject_id.unique(), key=lambda item: int(item[1:]))
    predictions, folds, importances = [], [], []
    artifact_dir = root / "models" / "m1" / kind / f"{window}s"
    artifact_dir.mkdir(parents=True, exist_ok=True)
    for subject in subjects:
        remaining = [item for item in subjects if item != subject]
        rng = np.random.default_rng(cfg["seed"] + int(subject[1:]) * 1000 + window)
        shuffled = rng.permutation(remaining).tolist()
        calibration_subjects = sorted(shuffled[:cfg["calibration_subjects_per_fold"]])
        training_subjects = sorted(shuffled[cfg["calibration_subjects_per_fold"]:])
        if set(training_subjects) & set(calibration_subjects) or subject in training_subjects + calibration_subjects:
            raise AssertionError("subject leakage in split")
        train = subset.loc[subset.subject_id.isin(training_subjects)]
        calibrate = subset.loc[subset.subject_id.isin(calibration_subjects)]
        test = subset.loc[subset.subject_id == subject]
        y_train = train.label_binary.to_numpy(dtype=int)
        y_cal = calibrate.label_binary.to_numpy(dtype=int)
        y_test = test.label_binary.to_numpy(dtype=int)
        if any(len(np.unique(item)) != 2 for item in (y_train, y_cal, y_test)):
            raise ValueError(f"both classes required in every split: {subject} {window}s")
        model = make_model(kind, cfg, cfg["seed"], y_train)
        model.fit(train[feature_names], y_train)
        p_cal = model.predict_proba(calibrate[feature_names])[:, 1]
        p_raw = model.predict_proba(test[feature_names])[:, 1]
        platt = LogisticRegression(C=cfg["calibration_logistic_c"], max_iter=1000)
        platt.fit(logit(p_cal).reshape(-1, 1), y_cal)
        p_platt = platt.predict_proba(logit(p_raw).reshape(-1, 1))[:, 1]
        isotonic = IsotonicRegression(out_of_bounds="clip").fit(p_cal, y_cal)
        p_isotonic = isotonic.predict(p_raw)
        joblib.dump({"model": model, "features": feature_names, "platt": platt,
                     "isotonic": isotonic, "train_subjects": training_subjects,
                     "calibration_subjects": calibration_subjects, "test_subject": subject,
                     "window_seconds": window}, artifact_dir / f"{subject}.joblib")
        for feature, importance in zip(feature_names, model.feature_importances_):
            importances.append({"test_subject": subject, "feature": feature,
                                "importance": float(importance)})
        fold = {"test_subject": subject, "train_subjects": training_subjects,
                "calibration_subjects": calibration_subjects,
                "train_n": len(train), "calibration_n": len(calibrate), "test_n": len(test),
                "metrics": {method: metrics(y_test, p, cfg["ece_bins"], cfg["experimental_abstain_margin"],
                                            cfg["calibration_logistic_c"])
                            for method, p in (("raw", p_raw), ("platt", p_platt), ("isotonic", p_isotonic))},
                "platt_coefficient": float(platt.coef_[0, 0]),
                "platt_intercept": float(platt.intercept_[0]),
                "isotonic_threshold_count": int(len(isotonic.X_thresholds_))}
        folds.append(fold)
        for position, (index, row) in enumerate(test.iterrows()):
            predictions.append({"subject_id": subject, "window_seconds": window,
                                "window_start_ms": int(row.window_start_ms),
                                "window_end_ms": int(row.window_end_ms),
                                "label_binary": int(y_test[position]),
                                "p_raw": float(p_raw[position]),
                                "p_platt": float(p_platt[position]),
                                "p_isotonic": float(p_isotonic[position]),
                                "calibration_subjects": ",".join(calibration_subjects)})
        print(f"{kind} {window}s {subject}: test={len(test)}", flush=True)
    prediction_frame = pd.DataFrame(predictions).sort_values(
        ["subject_id", "window_start_ms"], kind="stable").reset_index(drop=True)
    prediction_path = root / "predictions" / "m1" / f"{kind}_{window}s.parquet"
    prediction_path.parent.mkdir(parents=True, exist_ok=True)
    prediction_frame.to_parquet(prediction_path, index=False)
    y_all = prediction_frame.label_binary.to_numpy(dtype=int)
    pooled = {method: metrics(y_all, prediction_frame[f"p_{method}"].to_numpy(),
                              cfg["ece_bins"], cfg["experimental_abstain_margin"],
                              cfg["calibration_logistic_c"])
              for method in ("raw", "platt", "isotonic")}
    calibration_path = root / "calibration" / "m1" / f"{kind}_{window}s.json"
    calibration_path.parent.mkdir(parents=True, exist_ok=True)
    calibration_path.write_text(json.dumps({"model": kind, "window_seconds": window,
                                           "calibration_subjects_per_fold": cfg["calibration_subjects_per_fold"],
                                           "platt_logistic_c": cfg["calibration_logistic_c"],
                                           "folds": [{key: fold[key] for key in
                                                      ("test_subject", "train_subjects", "calibration_subjects",
                                                       "platt_coefficient", "platt_intercept",
                                                       "isotonic_threshold_count")}
                                                     for fold in folds]}, indent=2) + "\n", encoding="utf-8")
    result = {"model": kind, "window_seconds": window, "features": feature_names,
              "fold_count": len(folds), "prediction_path": str(prediction_path),
              "prediction_sha256": file_hash(prediction_path),
              "calibration_path": str(calibration_path),
              "calibration_sha256": file_hash(calibration_path),
              "pooled_metrics": pooled, "per_subject_folds": folds,
              "feature_importances": importances}
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, default=Path("."))
    parser.add_argument("--models", nargs="*", help="Optional subset for smoke runs")
    parser.add_argument("--windows", nargs="*", type=int, help="Optional subset for smoke runs")
    args = parser.parse_args()
    cfg = yaml.safe_load(args.config.read_text(encoding="utf-8"))
    input_path = Path(cfg["input"])
    source = json.loads(Path(cfg["source_manifest"]).read_text(encoding="utf-8"))
    if not input_path.is_file() or file_hash(input_path) != source["output_sha256"]:
        raise ValueError("processed input missing or hash mismatch")
    frame = pd.read_parquet(input_path)
    if frame.subject_id.nunique() != source["subject_count"] or len(frame) != source["row_count"]:
        raise ValueError("processed input counts mismatch")
    if not frame.signal_quality.isin(["good", "degraded"]).all():
        raise ValueError("invalid-quality windows require separate policy")
    if not all(frame.label_provenance.str.contains("pkl:label_700hz")):
        raise ValueError("label provenance missing")
    output_root = args.output_root.resolve()
    run = {"schema_version": "1.0", "generated_at_utc": datetime.now(timezone.utc).isoformat(),
           "config": str(args.config.resolve()), "config_sha256": file_hash(args.config),
           "input": str(input_path.resolve()), "input_sha256": file_hash(input_path),
           "source_archive_sha256": source["source_sha256"], "seed": cfg["seed"],
           "versions": {"numpy": np.__version__, "pandas": pd.__version__,
                        "scikit_learn": sklearn.__version__, "xgboost": xgboost.__version__},
           "results": []}
    for window in args.windows or cfg["window_seconds"]:
        for kind in args.models or cfg["models"]:
            run["results"].append(run_experiment(frame, cfg, kind, window, output_root))
    metrics_path = output_root / "reports" / "m1_wesad_metrics.json"
    metrics_path.parent.mkdir(parents=True, exist_ok=True)
    metrics_path.write_text(json.dumps(run, indent=2, ensure_ascii=False, allow_nan=False) + "\n", encoding="utf-8")
    print(f"wrote {metrics_path}: {len(run['results'])} model/window experiments")


if __name__ == "__main__":
    main()
