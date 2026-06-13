#!/usr/bin/env bash
# Resize workshop hero PNGs to Antora width (960px) and optimize.
# Usage: bash scripts/normalize-workshop-screenshots.sh [file-or-dir...]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WIDTH="${WORKSHOP_IMG_WIDTH:-960}"
TARGETS=("$@")

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  TARGETS=("$ROOT/docs/assets/images/workshop" "$ROOT/docs/assets/images")
fi

resize_one() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  [[ "$f" == *.png ]] || return 0
  if command -v magick >/dev/null 2>&1; then
    magick "$f" -resize "${WIDTH}x" -strip "$f"
  elif command -v magick.exe >/dev/null 2>&1; then
    magick.exe "$f" -resize "${WIDTH}x" -strip "$f"
  elif command -v convert >/dev/null 2>&1 && convert -version 2>/dev/null | grep -qi imagemagick; then
    convert "$f" -resize "${WIDTH}x" -strip "$f"
  elif command -v ffmpeg >/dev/null 2>&1; then
    local tmp="${f}.tmp.png"
    ffmpeg -y -i "$f" -vf "scale=${WIDTH}:-1" "$tmp" >/dev/null 2>&1
    mv "$tmp" "$f"
  else
    echo "WARN: no ImageMagick/ffmpeg — skip resize for $f" >&2
    return 0
  fi
  echo "  $(basename "$f") → ${WIDTH}px wide"
}

echo "== Normalizing workshop screenshots (width=${WIDTH}) =="
for t in "${TARGETS[@]}"; do
  if [[ -d "$t" ]]; then
    while IFS= read -r -d '' f; do
      resize_one "$f"
    done < <(find "$t" -maxdepth 1 -name '*.png' -print0)
  else
    resize_one "$t"
  fi
done
echo "OK"
