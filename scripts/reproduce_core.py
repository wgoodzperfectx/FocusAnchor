"""Rebuild WESAD, MPUD and NURSE offline research artifacts from local archives."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[1]


def digest(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(block)
    return hasher.hexdigest()


def run(*arguments: str) -> None:
    command = [sys.executable, *arguments]
    print("RUN", subprocess.list2cmdline(command), flush=True)
    subprocess.run(command, cwd=ROOT, check=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset-root", required=True, type=Path)
    args = parser.parse_args()
    manifest = yaml.safe_load((ROOT / "experiment_manifest.yaml").read_text(encoding="utf-8"))
    archives = {}
    for name, details in manifest["datasets"].items():
        archive = args.dataset_root / details["local_archive"]
        if not archive.is_file():
            parser.error(f"{name} archive missing: {archive}")
        observed = digest(archive)
        if observed != details["sha256"]:
            parser.error(f"{name} SHA256 mismatch: {observed}")
        archives[name] = archive.resolve()
        print(f"{name}: archive SHA256 PASS", flush=True)
    survey = args.dataset_root / manifest["datasets"]["nurse"]["survey_file"]
    if not survey.is_file() or digest(survey) != manifest["datasets"]["nurse"]["survey_sha256"]:
        parser.error(f"NURSE survey missing or SHA256 mismatch: {survey}")
    print("nurse survey: SHA256 PASS", flush=True)

    run("scripts/preprocess_wesad.py", "--archive", str(archives["wesad"]),
        "--output-dir", "data/processed/wesad")
    run("scripts/train_m1_wesad.py", "--config", "experiments/m1_wesad_baseline.yaml")
    for window in (30, 60, 120):
        run("scripts/evaluate_nurse_external.py", "--archive", str(archives["nurse"]),
            "--survey", str(survey.resolve()), "--window", str(window))
    run("scripts/assemble_nurse_windows.py")
    run("scripts/preprocess_mpud.py", "--archive", str(archives["mobile_phone_use"]))
    run("scripts/train_m2_mpud.py")
    run("scripts/train_m1_replay.py")
    run("scripts/build_replay_fixtures.py")
    m1 = json.loads((ROOT / "reports/m1_wesad_metrics.json").read_text(encoding="utf-8"))
    m2 = json.loads((ROOT / "reports/m2_receptivity_metrics.json").read_text(encoding="utf-8"))
    expected = manifest["expected_outputs"]
    if len(m1["results"]) != expected["m1_model_window_combinations"]:
        raise ValueError("M1 experiment count mismatch")
    combinations = {(item["model"], item["window_seconds"]) for item in m1["results"]}
    if combinations != {(model, window) for model in ("rf", "xgboost") for window in (30, 60, 120)}:
        raise ValueError("M1 model/window coverage mismatch")
    for item in m1["results"]:
        if item["fold_count"] != 15:
            raise ValueError("M1 LOSO fold count mismatch")
        for path_key, hash_key in (("prediction_path", "prediction_sha256"),
                                   ("calibration_path", "calibration_sha256")):
            if digest(Path(item[path_key])) != item[hash_key]:
                raise ValueError(f"M1 output hash mismatch: {item[path_key]}")
    if m2["split"]["disjoint"] is not True:
        raise ValueError("M2 user split is not disjoint")
    for model in ("lr", "xgb"):
        prediction = ROOT / "predictions" / "m2" / f"{model}_test.parquet"
        if digest(prediction) != m2["models"][model]["prediction_sha256"]:
            raise ValueError(f"M2 output hash mismatch: {prediction}")
    nurse = json.loads((ROOT / "data/processed/nurse/manifest.json").read_text(encoding="utf-8"))
    if {int(k): v for k, v in nurse["window_counts"].items()} != expected["nurse_window_counts"]:
        raise ValueError("NURSE window counts mismatch")
    if digest(ROOT / expected["nurse_windows"]) != nurse["output_sha256"]:
        raise ValueError("NURSE canonical window hash mismatch")
    for window in (30, 60, 120):
        report = json.loads((ROOT / f"reports/m1_nurse_external_{window}s.json").read_text(encoding="utf-8"))
        if digest(ROOT / report["predictions_path"]) != report["predictions_sha256"]:
            raise ValueError(f"NURSE {window}s prediction hash mismatch")
    run("scripts/audit_artifacts.py")
    print("CORE REPRODUCTION PASS: metrics, predictions, models and replay fixtures regenerated")


if __name__ == "__main__":
    main()
