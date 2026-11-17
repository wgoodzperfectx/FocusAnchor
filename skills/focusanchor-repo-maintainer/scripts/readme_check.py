#!/usr/bin/env python3
"""Flag README review triggers from a Git diff; never promote capability status."""
import argparse
import json
import subprocess
from pathlib import Path

TRIGGERS = {
    "agentarts_provider": ("scripts/agentarts", "docs/agentarts/", "entry/src/main/ets/services/AgentArts"),
    "knowledge_v2": ("knowledge/", "knowledge-base/", "docs/knowledge/", "tests/knowledge/"),
    "watch_ack": ("wear/src/main/ets/services/", "entry/src/main/ets/services/WatchSync", "tests/sync-"),
    "ui_integration": ("entry/src/main/ets/pages/", "entry/src/main/ets/components/", "wear/src/main/ets/pages/"),
    "demo_steps": ("docs/demo/", "scripts/verify-", "tests/"),
    "architecture_contract": ("docs/contracts/", "docs/architecture/", "AGENTS.md"),
}
DOCS = ["README.md", "docs/evidence/capability-status.md", "docs/demo/README.md", "docs/roadmap.md"]


def changed(repo, base, head):
    data = subprocess.check_output(["git", "-C", str(repo), "diff", "--name-only", "-z", base, head])
    return sorted(x.decode("utf-8", "surrogateescape") for x in data.split(b"\0") if x)


def review(changes):
    return {name: [path for path in changes if any(path.startswith(prefix) for prefix in prefixes)]
            for name, prefixes in TRIGGERS.items()
            if any(any(path.startswith(prefix) for prefix in prefixes) for path in changes)}


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--repo", required=True)
    p.add_argument("--base", required=True)
    p.add_argument("--head", default="HEAD")
    args = p.parse_args()
    repo = Path(args.repo).resolve(strict=True)
    changes = changed(repo, args.base, args.head)
    triggers = review(changes)
    print(json.dumps({"base": args.base, "head": args.head, "changes": changes,
                      "review_triggers": triggers, "documents_to_review": DOCS if triggers else [],
                      "capability_promotion": "requires current acceptance evidence; never inferred from Git diff"},
                     ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
