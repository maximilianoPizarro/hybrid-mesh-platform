#!/usr/bin/env bash
# Create/update east and west branches with only their clusterGroup values file.
# main stays hub (values-global.yaml -> clusterGroupName: hub, all values-* present).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CLUSTER_VALUES=(
  "east:values-east.yaml"
  "west:values-west.yaml"
)

OTHER_VALUES=(
  values-hub.yaml
  values-east.yaml
  values-west.yaml
  values-standalone.yaml
  values-group-one.yaml
)

require_clean() {
  if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo "ERROR: commit or stash working tree changes before syncing cluster branches." >&2
    exit 1
  fi
}

set_global_cluster_group() {
  local cg="$1"
  if grep -q '^  clusterGroupName:' values-global.yaml; then
    sed -i "s/^  clusterGroupName:.*/  clusterGroupName: ${cg}/" values-global.yaml
  else
    echo "ERROR: clusterGroupName not found in values-global.yaml" >&2
    exit 1
  fi
}

write_branch_marker() {
  local branch="$1"
  local values_file="$2"
  cat > BRANCHES.md <<EOF
# Cluster branch: ${branch}

This git branch targets the **${branch}** spoke cluster only.

| Item | Value |
|------|-------|
| \`values-global.yaml\` | \`clusterGroupName: ${branch}\` |
| Cluster values | \`${values_file}\` only |
| Install | \`./pattern.sh install\` on the ${branch} spoke |

Hub configuration lives on \`main\` (\`values-hub.yaml\`).

Regenerate spoke values on \`main\`, then run \`scripts/sync-cluster-branches.sh\`.
EOF
}

sync_spoke_branch() {
  local branch="$1"
  local keep="$2"
  local main_ref="$3"

  echo "== Sync branch ${branch} (keep ${keep}) =="
  git checkout -B "${branch}" "${main_ref}"

  set_global_cluster_group "${branch}"

  for f in "${OTHER_VALUES[@]}"; do
    if [[ "${f}" != "${keep}" ]] && [[ -f "${f}" ]]; then
      rm -f "${f}"
      echo "  removed ${f}"
    fi
  done

  write_branch_marker "${branch}" "${keep}"
  git add values-global.yaml BRANCHES.md
  git add -u
  if git diff --cached --quiet; then
    echo "  no changes to commit on ${branch}"
  else
    git commit -m "branch(${branch}): spoke profile — ${keep} only, clusterGroupName ${branch}"
  fi
}

main() {
  require_clean
  local start
  start="$(git branch --show-current)"
  local main_ref
  main_ref="$(git rev-parse HEAD)"

  if [[ "${start}" != "main" ]]; then
    echo "ERROR: run from main (current: ${start})" >&2
    exit 1
  fi

  set_global_cluster_group hub
  cat > BRANCHES.md <<'EOF'
# Cluster branch: main (hub)

| Branch | Cluster | Values file |
|--------|---------|-------------|
| `main` | Hub | `values-hub.yaml` |
| `east` | East spoke | `values-east.yaml` only |
| `west` | West spoke | `values-west.yaml` only |

Create/update spoke branches:

```bash
scripts/sync-cluster-branches.sh
```
EOF
  git add values-global.yaml BRANCHES.md 2>/dev/null || true
  if ! git diff --cached --quiet 2>/dev/null; then
    git commit -m "docs: hub branch marker and clusterGroupName hub" || true
  fi

  for entry in "${CLUSTER_VALUES[@]}"; do
    branch="${entry%%:*}"
    keep="${entry##*:}"
    sync_spoke_branch "${branch}" "${keep}" "${main_ref}"
  done

  git checkout main
  set_global_cluster_group hub
  echo ""
  echo "Done. Branches: main (hub), east (${CLUSTER_VALUES[0]##*:}), west (${CLUSTER_VALUES[1]##*:})"
  git branch -v | grep -E 'main|east|west'
}

main "$@"
