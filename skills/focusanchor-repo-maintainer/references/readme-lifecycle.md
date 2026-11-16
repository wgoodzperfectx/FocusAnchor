# README lifecycle

On integration, inspect actual code, current tests, build results, license, and remote before changing README. Address reviewers, developers, and project members. Keep IMPLEMENTED, MOCK / REPLAY, EXPERIMENTAL, BLOCKED, and NOT_RUN distinct; link each capability to evidence. A screenshot or platform preview is not a device/API result.

Recheck README, capability matrix, architecture diagram, demo commands, and test instructions whenever any of these changes: real AgentArts call acceptance; KB V2 retrieval evaluation; real phone-watch ACK; major UI integration; local demo steps; approved shared contract or architecture decision. For unverified progress, update only progress text, not capability level. Re-run documented demo commands before committing docs. Publish only after rights, sensitive files, and reproducibility gates pass; keep remote mutations separate from documentation updates.

Run `python scripts/readme_check.py --repo <repo> --base <last-reviewed-commit> --head HEAD` after integration. It detects changed paths likely to affect these sections and lists documents to inspect. File changes are review triggers only; acceptance events require separate current test/platform/device evidence. Run `python scripts/test_readme_check.py` when modifying the detector.
