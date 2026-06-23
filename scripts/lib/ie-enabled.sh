#!/usr/bin/env bash
# Industrial Edge is optional (disabled by default in charts/region/*/values.yaml).
# Set VERIFY_IE=1 to require IE surfaces in validation scripts.
ie_enabled() {
  [[ "${VERIFY_IE:-0}" == "1" ]] && return 0
  oc get gateway hub-gateway -n hub-gateway-system &>/dev/null
}

ie_skip_msg() {
  echo "SKIP: Industrial Edge disabled (hub-gateway not deployed). Set VERIFY_IE=1 to require IE checks."
}
