#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "=== ArgoCD Preflight (Validated Patterns) ==="

python scripts/verify-gitops-strategies.py

echo "1. Linting all charts/all/* ..."
failed=0
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

echo "2. Checking explicit paths in spoke values ..."
for f in values-east.yaml values-west.yaml; do
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

echo "3. Checking argoProject coverage ..."
python - <<'PY'
import yaml
from pathlib import Path
for fname in ("values-hub.yaml", "values-east.yaml", "values-west.yaml"):
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
