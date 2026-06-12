#!/usr/bin/env python3
"""Validate PUSH/PULL workload partition in values files."""

from __future__ import annotations

import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]

PUSH_IDS = frozenset({"operators-ci", "operators-platform"})


def load(name: str) -> dict:
    with (ROOT / name).open(encoding="utf-8") as f:
        return yaml.safe_load(f)["clusterGroup"]["applications"]


def main() -> int:
    errors = []
    for fname in ("values-east.yaml", "values-west.yaml"):
        apps = load(fname)
        overlap = set(apps) & PUSH_IDS
        if overlap:
            errors.append(f"{fname}: PULL must not include PUSH apps {overlap}")
        if "operators" in apps:
            errors.append(
                f"{fname}: legacy 'operators' app must be replaced by operators-edge"
            )
        if "operators-edge" not in apps:
            errors.append(f"{fname}: missing operators-edge (PULL)")
    hub = yaml.safe_load((ROOT / "values-hub.yaml").open(encoding="utf-8"))
    projects = hub["clusterGroup"].get("argoProjects", [])
    for required in ("fleet-push", "fleet-pull", "operators-platform"):
        if required not in projects:
            errors.append(f"values-hub.yaml: missing argoProject {required}")
    if errors:
        for e in errors:
            print(f"ERROR: {e}", file=sys.stderr)
        return 1
    print("PUSH/PULL partition OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
