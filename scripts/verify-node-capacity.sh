#!/usr/bin/env bash
# Verify worker allocatable CPU/memory meets workshop minimums.
#
# Usage:
#   bash scripts/verify-node-capacity.sh          # hub, 30 users (default)
#   WORKSHOP_USERS=50 bash scripts/verify-node-capacity.sh
#   ROLE=spoke bash scripts/verify-node-capacity.sh
#
# Thresholds (allocatable sum across workers, excluding control plane):
#   hub 30 users: >= 16 CPU, >= 64 GiB
#   hub 50 users: >= 20 CPU, >= 80 GiB
#   spoke:        >= 10 CPU, >= 40 GiB
set -euo pipefail

ROLE="${ROLE:-hub}"
WORKSHOP_USERS="${WORKSHOP_USERS:-30}"
MIN_CPU="${MIN_CPU:-}"
MIN_MEM_GIB="${MIN_MEM_GIB:-}"

case "$ROLE" in
  hub)
    if [[ -z "$MIN_CPU" ]]; then
      if [[ "$WORKSHOP_USERS" -le 30 ]]; then
        MIN_CPU=16
        MIN_MEM_GIB="${MIN_MEM_GIB:-64}"
      else
        MIN_CPU=20
        MIN_MEM_GIB="${MIN_MEM_GIB:-80}"
      fi
    else
      MIN_MEM_GIB="${MIN_MEM_GIB:-64}"
    fi
    ;;
  spoke)
    MIN_CPU="${MIN_CPU:-10}"
    MIN_MEM_GIB="${MIN_MEM_GIB:-40}"
    ;;
  *)
    echo "ERROR: ROLE must be hub or spoke (got: $ROLE)" >&2
    exit 1
    ;;
esac

if ! command -v oc >/dev/null 2>&1; then
  echo "ERROR: oc not found" >&2
  exit 1
fi

nodes="$(oc get nodes -l node-role.kubernetes.io/worker= -o name 2>/dev/null || true)"
if [[ -z "$nodes" ]]; then
  echo "ERROR: no worker nodes found" >&2
  exit 1
fi

total_cpu_m=0
total_mem_ki=0
count=0

while read -r line; do
  cpu_m="$(echo "$line" | awk '{print $1}')"
  mem_ki="$(echo "$line" | awk '{print $2}')"
  total_cpu_m=$((total_cpu_m + cpu_m))
  total_mem_ki=$((total_mem_ki + mem_ki))
  ((count++)) || true
done < <(
  oc get nodes -l node-role.kubernetes.io/worker= \
    -o custom-columns=CPU:.status.allocatable.cpu,MEM:.status.allocatable.memory \
    --no-headers 2>/dev/null | while read -r cpu mem; do
      cpu_m=$(echo "$cpu" | sed 's/m$//' | awk '{printf "%.0f", $1}')
      if [[ "$cpu" == *m ]]; then cpu_m="${cpu%m}"; else cpu_m=$((cpu * 1000)); fi
      mem_ki=$(echo "$mem" | sed 's/Ki$//' | awk '{printf "%.0f", $1}')
      if [[ "$mem" == *Gi ]]; then
        mem_ki=$(echo "$mem" | sed 's/Gi$//' | awk '{printf "%.0f", $1 * 1024 * 1024}')
      elif [[ "$mem" == *Mi ]]; then
        mem_ki=$(echo "$mem" | sed 's/Mi$//' | awk '{printf "%.0f", $1 * 1024}')
      elif [[ "$mem" == *Ki ]]; then
        mem_ki="${mem%Ki}"
      fi
      echo "$cpu_m $mem_ki"
    done
)

total_cpu=$(awk "BEGIN {printf \"%.1f\", ${total_cpu_m}/1000}")
total_mem_gib=$(awk "BEGIN {printf \"%.1f\", ${total_mem_ki}/1024/1024}")

echo "Role: ${ROLE} (workshop users: ${WORKSHOP_USERS})"
echo "Workers: ${count}"
echo "Allocatable total: ${total_cpu} CPU, ${total_mem_gib} GiB"
echo "Required minimum:  ${MIN_CPU} CPU, ${MIN_MEM_GIB} GiB"

fail=0
awk -v have="$total_cpu" -v need="$MIN_CPU" 'BEGIN { exit (have+0 >= need+0) ? 0 : 1 }' || { echo "FAIL: CPU below minimum" >&2; fail=1; }
awk -v have="$total_mem_gib" -v need="$MIN_MEM_GIB" 'BEGIN { exit (have+0 >= need+0) ? 0 : 1 }' || { echo "FAIL: memory below minimum" >&2; fail=1; }

if (( fail > 0 )); then
  echo ""
  echo "Hint: hub workshop-50 tier = 4 workers × 16 vCPU × 64 GiB (see README cluster sizing)."
  exit 1
fi

echo "OK: node capacity meets ${ROLE} minimums."
