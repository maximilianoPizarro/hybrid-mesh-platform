#!/usr/bin/env bash
# Sync workshop images and optional adoc stubs from hybrid-mesh-platform → showroom-hybrid-mesh-ai.
# Usage:
#   SHOWROOM_DIR=../showroom-hybrid-mesh-ai bash scripts/sync-showroom-content.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHOWROOM_DIR="${SHOWROOM_DIR:-$ROOT/../showroom-hybrid-mesh-ai}"
IMG_SRC="$ROOT/docs/assets/images"
IMG_DST="$SHOWROOM_DIR/content/modules/en/modules/ROOT/images"

if [[ ! -d "$SHOWROOM_DIR/.git" ]]; then
  echo "ERROR: showroom repo not found at $SHOWROOM_DIR" >&2
  echo "Clone: git clone https://github.com/maximilianoPizarro/showroom-hybrid-mesh-ai.git" >&2
  exit 1
fi

mkdir -p "$IMG_DST"

copy() {
  local src="$1" dst="$2"
  if [[ ! -f "$src" ]]; then
    echo "WARN: missing $src" >&2
    return
  fi
  cp "$src" "$IMG_DST/$dst"
  echo "  $dst"
}

echo "== Architecture & platform diagrams =="
copy "$IMG_SRC/arch-hub-spoke-flow.png" "00-arch-hub-spoke-flow.png"
copy "$IMG_SRC/arch-overview.png" "00-arch-overview.png"
copy "$IMG_SRC/arch-data-flow.png" "13-arch-data-flow.png"
copy "$IMG_SRC/arch-skupper-topology.png" "11-arch-skupper-topology.png"
copy "$IMG_SRC/arch-spoke-gateway.png" "11-arch-spoke-gateway.png"
copy "$IMG_SRC/arch-sync-waves.png" "16-arch-sync-waves.png"
copy "$IMG_SRC/arch-observability-pipeline.png" "15-arch-observability.png"
copy "$IMG_SRC/arch-gitops-sync-sequence.png" "16-arch-gitops-sync.png"

echo "== AI & product visuals =="
copy "$IMG_SRC/openshift-ia.png" "22-openshift-ia-stack.png"
copy "$IMG_SRC/kairos-ia-agents.png" "14-kairos-ia-agents.png"

echo "== Legacy workshop hero images (module thumbnails) =="
LEGACY_ORPHANS=(
  "00-index-hybrid-mesh.png"
  "23-llm-rag.png"
  "25-neuroface-dashboard.png"
  "26-ai-end-user-apps.png"
  "27-full-verification.png"
)
if [[ -d "$IMG_SRC/workshop" ]]; then
  for f in "$IMG_SRC/workshop"/*.png; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    skip=0
    for o in "${LEGACY_ORPHANS[@]}"; do
      [[ "$base" == "$o" ]] && skip=1 && break
    done
    [[ "$skip" -eq 1 ]] && echo "  skip legacy orphan $base" && continue
    copy "$f" "$base"
  done
fi

echo "OK: images synced to $IMG_DST"
echo "Next: edit .adoc in showroom repo, commit, push — cluster picks up on showroom pod recycle or Argo sync."
