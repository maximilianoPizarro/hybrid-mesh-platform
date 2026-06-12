#!/usr/bin/env python3
"""Validate PUSH/PULL workload partition in region values files."""

from __future__ import annotations

import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]

PUSH_IDS = frozenset({"operators-ci", "operators-platform"})

REGION_VALUES = {
    "hub": ROOT / "charts/region/hub/values.yaml",
    "east": ROOT / "charts/region/east/values.yaml",
    "west": ROOT / "charts/region/west/values.yaml",
}


def load(path: Path) -> dict:
    with path.open(encoding="utf-8") as f:
        return yaml.safe_load(f)["clusterGroup"]["applications"]


def main() -> int:
    errors = []
    for region in ("east", "west"):
        apps = load(REGION_VALUES[region])
        overlap = set(apps) & PUSH_IDS
        if overlap:
            errors.append(
                f"charts/region/{region}/values.yaml: PULL must not include PUSH apps {overlap}"
            )
        if "operators" in apps:
            errors.append(
                f"charts/region/{region}/values.yaml: legacy 'operators' app must be operators-edge"
            )
        if "operators-edge" not in apps:
            errors.append(
                f"charts/region/{region}/values.yaml: missing operators-edge (PULL)"
            )
    hub = yaml.safe_load(REGION_VALUES["hub"].open(encoding="utf-8"))
    projects = hub["clusterGroup"].get("argoProjects", [])
    for required in ("fleet-push", "fleet-pull", "operators-platform"):
        if required not in projects:
            errors.append(
                f"charts/region/hub/values.yaml: missing argoProject {required}"
            )
    if errors:
        for e in errors:
            print(f"ERROR: {e}", file=sys.stderr)
        return 1
    print("PUSH/PULL partition OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
