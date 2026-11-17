#!/usr/bin/env python3
"""Capture an evidence snapshot of registered worktrees without mutation."""
import argparse
import json
import subprocess
from pathlib import Path


def git(repo, *args):
    return subprocess.check_output(["git", "-C", str(repo), *args], text=True, encoding="utf-8", errors="replace").strip()


def worktrees(repo):
    blocks = git(repo, "worktree", "list", "--porcelain").split("\n\n")
    result = []
    for block in blocks:
        if not block.strip():
            continue
        fields = dict(line.split(" ", 1) if " " in line else (line, True) for line in block.splitlines())
        path = Path(fields["worktree"])
        status = git(path, "status", "--porcelain=v1", "--untracked-files=all")
        result.append({"path": str(path), "head": fields.get("HEAD"), "branch": fields.get("branch"),
                       "detached": "detached" in fields, "status": status.splitlines() if status else [],
                       "remotes": git(path, "remote", "-v").splitlines()})
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    repo = Path(args.repo).resolve(strict=True)
    data = {"repo": str(repo), "worktrees": worktrees(repo)}
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Captured {len(data['worktrees'])} worktrees: {output}")


if __name__ == "__main__":
    main()
