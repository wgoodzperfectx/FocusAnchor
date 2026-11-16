#!/usr/bin/env python3
"""Back up dirty worktree files, Git diff, and metadata with SHA-256 checks."""
import argparse
import hashlib
import json
import subprocess
import zipfile
from pathlib import Path


def command(repo, *args):
    return subprocess.check_output(["git", "-C", str(repo), *args])


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--repo", required=True)
    p.add_argument("--output", required=True)
    a = p.parse_args()
    repo = Path(a.repo).resolve(strict=True)
    output = Path(a.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    names = [x.decode("utf-8", "surrogateescape") for x in command(repo, "ls-files", "-m", "-o", "--exclude-standard", "-z").split(b"\0") if x]
    manifest = {"repo": str(repo), "head": command(repo, "rev-parse", "HEAD").decode().strip(), "files": {}}
    diff = command(repo, "diff", "--binary", "HEAD")
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as z:
        z.writestr("git-diff.patch", diff)
        for name in names:
            source = repo / name
            if not source.is_file():
                continue
            data = source.read_bytes()
            manifest["files"][name] = hashlib.sha256(data).hexdigest()
            z.writestr("files/" + name.replace("\\", "/"), data)
        z.writestr("manifest.json", json.dumps(manifest, ensure_ascii=False, indent=2))
    with zipfile.ZipFile(output) as z:
        assert z.testzip() is None
        for name, digest in manifest["files"].items():
            assert hashlib.sha256(z.read("files/" + name.replace("\\", "/"))).hexdigest() == digest
        assert z.read("git-diff.patch") == diff
    print(f"Verified {len(manifest['files'])} files and Git diff: {output}")


if __name__ == "__main__":
    main()
