#!/usr/bin/env python3
"""Ensure MultiClusterEngine cluster-proxy-addon component is disabled."""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time

MCE_NAME = os.environ.get("MCE_NAME", "multiclusterengine")
MAX_WAIT = int(os.environ.get("MCE_WAIT_ITERATIONS", "60"))
SLEEP_SEC = int(os.environ.get("MCE_WAIT_SECONDS", "30"))
COMPONENT = "cluster-proxy-addon"


def run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, capture_output=True, text=True, check=False)


def main() -> int:
    raw = None
    for attempt in range(1, MAX_WAIT + 1):
        result = run(["oc", "get", "mce", MCE_NAME, "-o", "json"])
        if result.returncode == 0:
            raw = result.stdout
            break
        print(f"waiting for MultiClusterEngine/{MCE_NAME} ({attempt}/{MAX_WAIT})")
        time.sleep(SLEEP_SEC)

    if raw is None:
        print(f"ERROR: MultiClusterEngine/{MCE_NAME} not found", file=sys.stderr)
        return 1

    mce = json.loads(raw)
    spec = mce.setdefault("spec", {})
    overrides = spec.setdefault("overrides", {})
    components = overrides.setdefault("components", [])

    changed = False
    found = False
    for component in components:
        if component.get("name") != COMPONENT:
            continue
        found = True
        if component.get("enabled") is not False:
            component["enabled"] = False
            changed = True
        break

    if not found:
        components.append(
            {"name": COMPONENT, "enabled": False, "configOverrides": {}}
        )
        changed = True

    if not changed:
        print(f"{COMPONENT} already disabled on MultiClusterEngine/{MCE_NAME}")
        return 0

    patch = json.dumps({"spec": {"overrides": {"components": components}}})
    patch_result = run(
        ["oc", "patch", "mce", MCE_NAME, "--type=merge", "-p", patch]
    )
    if patch_result.returncode != 0:
        print(patch_result.stderr or patch_result.stdout, file=sys.stderr)
        return patch_result.returncode

    print(f"disabled {COMPONENT} on MultiClusterEngine/{MCE_NAME}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
