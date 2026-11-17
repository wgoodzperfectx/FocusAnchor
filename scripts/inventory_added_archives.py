"""Inventory newly supplied research ZIPs without extracting participant records."""

from __future__ import annotations

import argparse
import hashlib
import json
import zipfile
from datetime import datetime, timezone
from pathlib import Path


NAMES = ("swell.zip", "CLAS.zip", "StudentLife.zip",
         "ExtraSensory.per_uuid_features_labels.zip")


def digest(path: Path) -> str:
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset-root", required=True, type=Path)
    parser.add_argument("--output", type=Path, default=Path("reports/added_data_inventory.json"))
    args = parser.parse_args()
    result = {"schema_version": "1.0", "observed_at_utc": datetime.now(timezone.utc).isoformat(),
              "dataset_root": str(args.dataset_root.resolve()), "archives": {}}
    for name in NAMES:
        path = args.dataset_root / name
        if not path.is_file():
            result["archives"][name] = {"status": "MISSING"}
            continue
        with zipfile.ZipFile(path) as archive:
            entries = archive.infolist()
            bad = archive.testzip()
            result["archives"][name] = {
                "status": "CRC_PASS" if bad is None else "CRC_FAIL",
                "archive_bytes": path.stat().st_size,
                "sha256": digest(path),
                "member_count": len(entries),
                "declared_unpacked_bytes": sum(entry.file_size for entry in entries),
                "encrypted_members": sum(bool(entry.flag_bits & 1) for entry in entries),
                "unsafe_member_paths": [entry.filename for entry in entries
                                        if entry.filename.startswith("/") or
                                        ".." in entry.filename.replace("\\", "/").split("/")],
                "bad_member": bad,
                "sample_members": [entry.filename for entry in entries[:12]],
            }
        print(f"{name}: {result['archives'][name]['status']}", flush=True)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
