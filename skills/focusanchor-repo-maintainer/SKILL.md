---
name: focusanchor-repo-maintainer
description: Audit, consolidate, and maintain FocusAnchor Git worktrees and integration branches with verified recovery points and evidence. Use for explicit repository cleanup or multi-branch integration requests, not ordinary code edits.
---

# FocusAnchor repository maintenance

Choose `audit` for read-only inventory, `consolidate` for authorized integration and local commits, or `maintain` for routine branch/worktree health. Never infer permission to delete or merge from ordinary code work.

Read the project `AGENTS.md`, Architecture Charter, current integration spec, and [consolidation policy](references/consolidation-policy.md). Treat Git and files as authoritative over reports. Run `python scripts/inventory.py --repo <main-repo> --output <inventory.json>` to capture branch, HEAD, and worktree status before mutations.

In `consolidate`, first preserve every source HEAD and all staged, unstaged, and untracked content with independently verified recovery files. Keep sensitive backups local. Create a separate integration worktree and branch. Integrate only semantically compatible, verified changes; keep experimental work on its original branch. Do not change shared contracts, authorization, task state ownership, or platform deployment without explicit approval. Execute relevant tests and builds, record actual commands and results, and make scoped local commits only after validation. Do not push or merge main by default.

Use Git worktree commands for lifecycle operations. Remove a tree only after proving unique commits and dirty content are recoverable, it is unused, and its results are integrated or archived. Keep historical branches. The independent `8_Drive` clone is outside automatic integration and cleanup.

Record inventory, decisions, integration commits, validation, cleanup, recovery commands, and blockers in `10_Codex/reports/repository-consolidation/`. For project-specific roles and exceptions, read [consolidation policy](references/consolidation-policy.md). After each substantial run, update the skill from observed reusable lessons and validate it again.

For repository publication preparation, read [README lifecycle](references/readme-lifecycle.md). Audit tracked secrets, signing files, personal data, model weights, restricted datasets, large files, license and third-party assets before proposing a public push. Write a status matrix with evidence and a publication check report. Do not create a public repository, push, release, or change remote visibility/default branch without explicit authorization.

Run `python scripts/publication_scan.py --repo <repo> --output <local-report.json>` for tracked-file triage. It flags path/size/known secret patterns, but cannot establish rights or guarantee absence of secrets; review media, license and provenance separately. Keep scan reports local until checked for sensitive paths.
