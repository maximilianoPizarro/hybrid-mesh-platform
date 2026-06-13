#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "=== ArgoCD Preflight (Validated Patterns) ==="

python scripts/verify-gitops-strategies.py

failed=0
echo "1. Linting root bootstrap chart ..."
if ! helm lint . >/dev/null 2>&1; then
  echo "  FAIL: root Chart.yaml bootstrap"
  failed=1
else
  echo "  PASS: root bootstrap chart"
fi

echo "2. Linting region bootstrap charts ..."
for region in hub east west; do
  if ! helm lint "charts/region/${region}" >/dev/null 2>&1; then
    echo "  FAIL: charts/region/${region}"
    failed=1
  else
    echo "  PASS: charts/region/${region}"
  fi
done

echo "3. Linting all charts/all/* ..."
for chart in charts/all/*/Chart.yaml; do
  dir="$(dirname "$chart")"
  if ! helm lint "$dir" >/dev/null 2>&1; then
    echo "  FAIL: $dir"
    failed=1
  fi
done
if [ "$failed" -eq 0 ]; then
  echo "  PASS: all charts lint"
fi

echo "4. Checking explicit paths in spoke region values ..."
for f in charts/region/east/values.yaml charts/region/west/values.yaml; do
  missing=$(python - <<PY
import yaml
from pathlib import Path
apps = yaml.safe_load(Path("$f").read_text())["clusterGroup"]["applications"]
print(sum(1 for k,v in apps.items() if "path" not in v and "chart" not in v))
PY
)
  if [ "$missing" != "0" ]; then
    echo "  WARN: $f has $missing apps without explicit path/chart"
  else
    echo "  PASS: $f paths explicit"
  fi
done

echo "5. Checking argoProject coverage ..."
python - <<'PY'
import yaml
from pathlib import Path
for fname in (
    "charts/region/hub/values.yaml",
    "charts/region/east/values.yaml",
    "charts/region/west/values.yaml",
):
    cg = yaml.safe_load(Path(fname).read_text())["clusterGroup"]
    projects = set(cg.get("argoProjects", []))
    for app_id, app in cg.get("applications", {}).items():
        p = app.get("argoProject")
        if p and p not in projects:
            raise SystemExit(f"  ERROR: {fname} app {app_id} project {p} not in argoProjects")
    print(f"  PASS: {fname}")
PY

echo ""
echo "=== Preflight complete ==="
exit "$failed"
