#!/usr/bin/env bash
# Seed MaaS API keys into Vault KV (facilitator-only; keys never printed or committed).
#
# Prerequisites:
#   - Vault unsealed on hub (namespace vault)
#   - export MAAS_KEY_LLAMA='sk-...'
#
# Usage:
#   export MAAS_KEY_LLAMA='sk-...'
#   export MAAS_KEY_GRANITE='sk-...'    # optional
#   export MAAS_KEY_DEEPSEEK='sk-...'   # optional
#   bash scripts/seed-maas-vault.sh
set -euo pipefail

VAULT_NS="${VAULT_NS:-vault}"
VAULT_POD="${VAULT_POD:-vault-0}"
MAAS_PATH="${MAAS_VAULT_PATH:-secret/workshop/maas}"
MAAS_BASE="${MAAS_OPENAI_API_BASE:-https://maas-rhdp.apps.maas.redhatworkshops.io/v1}"

if [[ -z "${MAAS_KEY_LLAMA:-}" ]]; then
  echo "ERROR: export MAAS_KEY_LLAMA before seeding Vault"
  exit 1
fi

ROOT="$(oc get secret vaultkeys -n imperative -o jsonpath='{.data.vault_data_json}' \
  | python3 -c "import sys,json,base64; print(json.loads(base64.b64decode(sys.stdin.read()))['root_token'])")"
[[ -n "${ROOT}" ]] || { echo "ERROR: missing Vault root token (secret vaultkeys in imperative)"; exit 1; }

oc wait pod/"${VAULT_POD}" -n "${VAULT_NS}" --for=condition=Ready --timeout=120s

PUT_ARGS=(
  "api-key=${MAAS_KEY_LLAMA}"
  "openai-api-base=${MAAS_BASE}"
)
[[ -n "${MAAS_KEY_GRANITE:-}" ]] && PUT_ARGS+=("granite-api-key=${MAAS_KEY_GRANITE}")
[[ -n "${MAAS_KEY_DEEPSEEK:-}" ]] && PUT_ARGS+=("deepseek-api-key=${MAAS_KEY_DEEPSEEK}")

oc exec -n "${VAULT_NS}" "${VAULT_POD}" -- env \
  VAULT_ADDR=https://127.0.0.1:8200 VAULT_SKIP_VERIFY=1 VAULT_TOKEN="${ROOT}" \
  vault kv put "${MAAS_PATH}" "${PUT_ARGS[@]}"

echo "Seeded Vault path ${MAAS_PATH} (keys not printed)"
