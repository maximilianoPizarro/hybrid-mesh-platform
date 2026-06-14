#!/usr/bin/env bash
# Enable Vault userpass demo users (admin, user1) — idempotent day-2 apply.
# Requires: oc logged in on hub; Vault running; imperative/vaultkeys present.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NS=vault
POD=vault-0
PASSWORD="${VAULT_DEMO_PASSWORD:-Welcome123!}"

if ! oc get pod "$POD" -n "$NS" >/dev/null 2>&1; then
  echo "ERROR: $NS/$POD not found — sync vault chart first" >&2
  exit 1
fi

echo "== Apply vault-demo-auth =="
helm template vault-demo-auth "$ROOT/charts/all/vault-demo-auth" \
  --set defaultPassword="$PASSWORD" \
  | oc apply -f -

echo "== Run configure job =="
oc delete job vault-demo-auth-hook -n "$NS" --ignore-not-found
helm template vault-demo-auth "$ROOT/charts/all/vault-demo-auth" \
  --set defaultPassword="$PASSWORD" \
  | oc apply -f -
oc wait job/vault-demo-auth-hook -n "$NS" --for=condition=complete --timeout=180s

echo ""
echo "Vault UI: https://vault-vault.$(oc get ingresses.config/cluster -o jsonpath='{.spec.domain}')/ui/"
echo "Method: userpass (Username)"
echo "  admin / $PASSWORD  — read/write secret/workshop/*"
echo "  user1 / $PASSWORD  — read secret/workshop/*"
