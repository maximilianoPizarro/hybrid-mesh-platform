#!/usr/bin/env python3
"""Restore all.yaml from legacy for charts where naive split broke Helm templates."""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEGACY = Path(__file__).resolve().parents[2] / "platform-hub-spoke-config" / "components"


def main() -> None:
    failed = []
    for chart in sorted((ROOT / "charts" / "all").iterdir()):
        if not (chart / "Chart.yaml").exists():
            continue
        r = subprocess.run(["helm", "lint", str(chart)], capture_output=True, text=True)
        if r.returncode == 0:
            continue
        failed.append(chart.name)
        legacy = LEGACY / chart.name / "templates" / "all.yaml"
        tpl = chart / "templates"
        if legacy.exists():
            for f in tpl.glob("*.yaml"):
                if f.name != "all.yaml":
                    f.unlink()
            shutil.copy2(legacy, tpl / "all.yaml")
            print(f"restored {chart.name} from legacy all.yaml")
        else:
            print(f"WARN: no legacy all.yaml for {chart.name}", file=sys.stderr)

    print(f"Restored {len(failed)} charts: {', '.join(failed)}")


if __name__ == "__main__":
    main()
