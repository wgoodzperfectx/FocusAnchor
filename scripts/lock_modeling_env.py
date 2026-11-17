"""Record installed direct and transitively required modeling packages."""

from __future__ import annotations

from importlib import metadata
from pathlib import Path

from packaging.requirements import Requirement
from packaging.utils import canonicalize_name


root = Path(__file__).resolve().parents[1]
direct = []
for line in (root / "requirements-modeling.txt").read_text(encoding="utf-8").splitlines():
    if line.strip() and not line.startswith("#"):
        direct.append(canonicalize_name(Requirement(line).name))
queue = list(direct)
found = {}
while queue:
    name = queue.pop()
    if name in found:
        continue
    distribution = metadata.distribution(name)
    found[name] = distribution.version
    for dependency in distribution.requires or []:
        requirement = Requirement(dependency)
        if requirement.marker is None or requirement.marker.evaluate({"extra": ""}):
            queue.append(canonicalize_name(requirement.name))
lines = [f"{name}=={version}" for name, version in sorted(found.items())]
(root / "requirements-modeling.lock.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"Locked {len(lines)} packages")
