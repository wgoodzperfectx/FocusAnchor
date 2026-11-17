"""Inspect local dataset files without loading participant measurements.

Usage: python scripts/data_inventory.py --dataset-root <LOCAL_PROJECT_ROOT>/9_Dataset --output reports/data_inventory.json
Add --verify-crc to stream every member of the WESAD archive and validate CRCs.
"""

import argparse
import hashlib
import json
import re
import zipfile
from datetime import datetime, timezone
from pathlib import Path


DATASETS = ("wesad", "nurse", "mobile_phone_use", "k_emophone")
WESAD_ARCHIVE = "WESAD.zip"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def inspect_wesad(root: Path, verify_crc: bool) -> dict:
    archive = root / WESAD_ARCHIVE
    result = {"archive_path": str(archive), "archive_present": archive.is_file()}
    if not archive.is_file():
        result["status"] = "MISSING"
        return result
    result["archive_bytes"] = archive.stat().st_size
    result["sha256"] = sha256_file(archive)
    with zipfile.ZipFile(archive) as package:
        members = package.infolist()
        subject_pattern = re.compile(r"(?:^|/)(S\d+)(?:/|$)")
        subjects = sorted({match.group(1) for member in members
                           if (match := subject_pattern.search(member.filename))},
                          key=lambda item: int(item[1:]))
        unsafe = [item.filename for item in members if item.filename.startswith("/")
                  or ".." in item.filename.replace("\\", "/").split("/")]
        subject_files = {subject: sorted(item.filename.rsplit("/", 1)[-1]
                                         for item in members
                                         if item.filename.startswith(f"WESAD/{subject}/") and not item.is_dir())
                         for subject in subjects}
        required_main_pickle = {subject: f"{subject}.pkl" in names
                                for subject, names in subject_files.items()}
        result.update({"member_count": len(members), "subjects": subjects,
                       "subject_count": len(subjects),
                       "subject_files": subject_files,
                       "main_pickle_present": required_main_pickle,
                       "declared_unpacked_bytes": sum(item.file_size for item in members),
                       "encrypted_members": sum(bool(item.flag_bits & 1) for item in members),
                       "unsafe_member_paths": unsafe,
                       "crc_status": "NOT_RUN"})
        if verify_crc:
            bad_member = package.testzip()
            result["crc_status"] = "PASS" if bad_member is None else "FAIL"
            result["bad_member"] = bad_member
    extracted = root / "WESAD" / "WESAD"
    result["extracted_path"] = str(extracted)
    result["extracted_subject_dirs"] = sorted(
        (item.name for item in extracted.iterdir() if item.is_dir()),
        key=lambda item: int(item[1:]) if re.fullmatch(r"S\d+", item) else 9999,
    ) if extracted.is_dir() else []
    result["status"] = "ARCHIVE_VERIFIED" if result["crc_status"] == "PASS" else "ARCHIVE_PRESENT"
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset-root", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--verify-crc", action="store_true")
    args = parser.parse_args()
    root = args.dataset_root.resolve()
    if not root.is_dir():
        parser.error(f"dataset root does not exist: {root}")
    inventory = {
        "schema_version": "1.0",
        "observed_at_utc": datetime.now(timezone.utc).isoformat(),
        "dataset_root": str(root),
        "datasets": {key: {"status": "NOT_OBSERVED"} for key in DATASETS},
    }
    inventory["datasets"]["wesad"] = inspect_wesad(root, args.verify_crc)
    for key, candidates in {
        "nurse": ("Stress_dataset.zip", "NURSE.zip", "SurveyResults.xlsx"),
        "mobile_phone_use": ("mpud.zip", "mobile_phone_use.zip"),
        "k_emophone": ("K-EmoPhone.zip", "k_emophone.zip"),
    }.items():
        found = [root / name for name in candidates if (root / name).is_file()]
        inventory["datasets"][key] = {"status": "FILES_OBSERVED" if found else "NOT_OBSERVED",
                                       "top_level_files": [{"path": str(path),
                                                            "bytes": path.stat().st_size,
                                                            "sha256": sha256_file(path)}
                                                           for path in found]}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(inventory, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {args.output}: WESAD {inventory['datasets']['wesad']['status']}, "
          f"{inventory['datasets']['wesad'].get('subject_count', 0)} archive subjects")


if __name__ == "__main__":
    main()
