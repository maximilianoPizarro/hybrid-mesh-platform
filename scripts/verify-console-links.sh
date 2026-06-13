#!/usr/bin/env bash
# Curl every ConsoleLink href and report HTTP status (hub or current oc context).
set -euo pipefail

TIMEOUT="${CURL_TIMEOUT:-5}"
MIN_OK="${MIN_OK_CODE:-200}"
MAX_OK="${MAX_OK_CODE:-399}"

if ! command -v oc >/dev/null 2>&1; then
  echo "ERROR: oc not found" >&2
  exit 1
fi

links="$(oc get consolelink -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.href}{"\n"}{end}' 2>/dev/null || true)"
if [[ -z "$links" ]]; then
  echo "ERROR: no ConsoleLink resources (are you logged in?)" >&2
  exit 1
fi

ok=0
warn=0
fail=0

printf '%-6s %-32s %s\n' "HTTP" "NAME" "URL"
printf '%-6s %-32s %s\n' "----" "----" "---"

while IFS=$'\t' read -r name url; do
  [[ -z "$url" ]] && continue
  code="$(curl -sk -o /dev/null -w '%{http_code}' --connect-timeout "$TIMEOUT" "$url" 2>/dev/null || echo "000")"
  printf '%-6s %-32s %s\n' "$code" "$name" "$url"
  if [[ "$code" =~ ^[0-9]+$ ]] && (( code >= MIN_OK && code <= MAX_OK )); then
    ((ok++)) || true
  elif [[ "$code" == "503" ]]; then
    ((warn++)) || true
  else
    ((fail++)) || true
  fi
done <<< "$links"

echo
echo "Summary: ${ok} OK (${MIN_OK}-${MAX_OK}), ${warn} 503 (route exists / pods down), ${fail} other"
# Exit 1 only on hard failures (404, 000, wrong host) — not on 503 from unsynced apps
if (( fail > 0 )); then
  exit 1
fi
