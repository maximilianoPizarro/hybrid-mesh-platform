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

# OAuth-protected routes (e.g. OpenShift AI dashboard) return 403 without a token.
CURL_AUTH=()
if TOKEN="$(oc whoami -t 2>/dev/null || true)" && [[ -n "$TOKEN" ]]; then
  CURL_AUTH=(-H "Authorization: Bearer ${TOKEN}")
fi

links="$(oc get consolelink -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.href}{"\n"}{end}' 2>/dev/null | grep -v '^rhodslink	' || true)"
if [[ -z "$links" ]]; then
  echo "ERROR: no ConsoleLink resources (are you logged in?)" >&2
  exit 1
fi

ok=0
warn=0
fail=0

curl_code() {
  local url=$1
  local code
  code="$(curl -sk "${CURL_AUTH[@]}" -o /dev/null -w '%{http_code}' --connect-timeout "$TIMEOUT" "$url" 2>/dev/null || echo "000")"
  code="${code//$'\r'/}"
  echo "$code"
}

link_ok() {
  local name=$1 code=$2
  if [[ "$code" =~ ^[0-9]+$ ]] && (( code >= MIN_OK && code <= MAX_OK )); then
    return 0
  fi
  case "$name" in
    platform-workshop-apis)
      [[ "$code" == "401" || "$code" == "403" ]] && return 0
      ;;
    vault-link)
      [[ "$code" == "302" || "$code" == "303" || "$code" == "307" || "$code" == "401" || "$code" == "403" ]] && return 0
      ;;
  esac
  return 1
}

printf '%-6s %-32s %s\n' "HTTP" "NAME" "URL"
printf '%-6s %-32s %s\n' "----" "----" "---"

while IFS=$'\t' read -r name url; do
  [[ -z "$url" ]] && continue
  # Vault chart href is route root (307); check UI path for strict 200 gate.
  if [[ "$name" == "vault-link" && "$url" != */ui/* ]]; then
    url="${url%/}/ui/"
  fi
  code="$(curl_code "$url")"
  printf '%-6s %-32s %s\n' "$code" "$name" "$url"
  if link_ok "$name" "$code"; then
    ((ok++)) || true
  elif [[ "$code" == "401" || "$code" == "403" ]]; then
    # Other Kuadrant / OAuth routes without API key or token
    ((ok++)) || true
  elif [[ "$code" == "503" ]]; then
    ((warn++)) || true
  else
    ((fail++)) || true
  fi
done <<< "$links"

echo
echo "Summary: ${ok} OK (${MIN_OK}-${MAX_OK}), ${warn} 503 (route exists / pods down), ${fail} other"
if (( fail > 0 )); then
  exit 1
fi
# Strict gate: MIN_OK_CODE=200 also fails on 503 (backend not ready)
if (( MIN_OK <= 200 && warn > 0 )); then
  exit 1
fi
