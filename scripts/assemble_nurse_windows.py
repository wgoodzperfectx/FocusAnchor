"""Assemble the three audited NURSE window lengths into the canonical table."""

import json
from pathlib import Path

import pandas as pd

from preprocess_wesad import sha256_file


ROOT = Path("data/processed/nurse")
WINDOWS = (30, 60, 120)


def main():
    frames, manifests = [], []
    for window in WINDOWS:
        folder = ROOT / f"{window}s"
        manifest = json.loads((folder / "manifest.json").read_text(encoding="utf-8"))
        path = folder / "windows.parquet"
        if sha256_file(path) != manifest["windows_sha256"]:
            raise ValueError(f"window hash mismatch: {path}")
        frame = pd.read_parquet(path)
        if len(frame) != manifest["row_count"] or set(frame.window_seconds) != {window}:
            raise ValueError(f"window count or duration mismatch: {path}")
        frames.append(frame)
        manifests.append(manifest)
    if len({item["source_archive_sha256"] for item in manifests}) != 1 or len({item["survey_sha256"] for item in manifests}) != 1:
        raise ValueError("NURSE sources differ across window lengths")
    combined = pd.concat(frames, ignore_index=True).sort_values(
        ["subject_id", "session_id", "window_seconds", "window_start_ms"], kind="stable")
    if combined.duplicated(["subject_id", "session_id", "window_seconds", "window_start_ms"]).any():
        raise ValueError("duplicate canonical NURSE windows")
    output = ROOT / "windows.parquet"
    combined.to_parquet(output, index=False)
    result = {"dataset": "nurse", "window_seconds": list(WINDOWS),
              "source_archive_sha256": manifests[0]["source_archive_sha256"],
              "survey_sha256": manifests[0]["survey_sha256"],
              "time_reference": manifests[0]["time_reference"],
              "label_definition": manifests[0]["label_definition"],
              "subject_count": int(combined.subject_id.nunique()), "row_count": len(combined),
              "window_counts": {str(k): int(v) for k, v in combined.groupby("window_seconds").size().items()},
              "quality_counts": combined.signal_quality.value_counts().to_dict(),
              "label_counts": {str(k): int(v) for k, v in combined.label_raw.value_counts().items()},
              "output_parquet": str(output), "output_sha256": sha256_file(output)}
    (ROOT / "manifest.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {output}: {len(combined)} windows, {result['subject_count']} subjects")


if __name__ == "__main__":
    main()
