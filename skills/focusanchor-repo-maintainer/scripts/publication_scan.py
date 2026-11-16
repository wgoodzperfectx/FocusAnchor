#!/usr/bin/env python3
"""Read-only tracked-file publication triage; prints paths and categories, never values."""
import argparse
import json
import re
import subprocess
from pathlib import Path

SENSITIVE_NAME = re.compile(r"(?i)(^|/)(\.env(?:\.|$)|[^/]*\.(?:p12|p7b|jks|keystore|pem|key)$|[^/]*(?:credential|secret)[^/]*)")
MODEL_DATA_NAME = re.compile(r"(?i)\.(?:onnx|pt|pth|pkl|pickle|safetensors|csv|parquet|npy|npz)$")
MEDIA_NAME = re.compile(r"(?i)\.(?:png|jpg|jpeg|mp4|mov|webm|svg)$")
SECRET_CONTENT = re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9]{20,}")


def scan(repo):
    raw = subprocess.check_output(["git", "-C", str(repo), "ls-files", "-z"])
    paths = [p.decode("utf-8", "surrogateescape") for p in raw.split(b"\0") if p]
    result = {"tracked_count": len(paths), "sensitive_names": [], "model_or_data_names": [],
              "media_needing_rights_review": [], "files_over_10mb": [], "secret_pattern_paths": [],
              "unreadable": []}
    for name in paths:
        file = repo / name
        if SENSITIVE_NAME.search(name): result["sensitive_names"].append(name)
        if MODEL_DATA_NAME.search(name): result["model_or_data_names"].append(name)
        if MEDIA_NAME.search(name): result["media_needing_rights_review"].append(name)
        try:
            size = file.stat().st_size
            if size > 10_000_000: result["files_over_10mb"].append({"path": name, "bytes": size})
            if size <= 2_000_000 and not MEDIA_NAME.search(name) and SECRET_CONTENT.search(file.read_bytes()):
                result["secret_pattern_paths"].append(name)
        except (OSError, ValueError):
            result["unreadable"].append(name)
    return result


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--repo", required=True)
    p.add_argument("--output")
    args = p.parse_args()
    data = scan(Path(args.repo).resolve(strict=True))
    content = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        Path(args.output).write_text(content, encoding="utf-8")
    print(content)


if __name__ == "__main__":
    main()
