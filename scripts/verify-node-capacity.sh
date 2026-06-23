#!/usr/bin/env bash
# Verify worker allocatable CPU/memory meets workshop minimums.
#
# Usage:
#   bash scripts/verify-node-capacity.sh                    # hub, 30 users (default)
#   WORKSHOP_USERS=50 bash scripts/verify-node-capacity.sh  # hub, 50 users
#   ROLE=spoke bash scripts/verify-node-capacity.sh         # spoke recommended (AI CV + DevSpaces)
#   SPOKE_TIER=minimum ROLE=spoke bash scripts/verify-node-capacity.sh
#   CHECK_GPU=1 ROLE=spoke bash scripts/verify-node-capacity.sh
#
# Thresholds (allocatable sum across workers, excluding control plane):
#   hub 30 users:       >= 16 CPU, >= 64 GiB
#   hub 50 users:       >= 20 CPU, >= 80 GiB
#   spoke recommended:  >= 24 CPU, >= 96 GiB  (3×8×32 — NeuroFace + OVMS + YOLO + DevSpaces)
#   spoke minimum:      >=  8 CPU, >= 32 GiB  (2×4×16 — NeuroFace + OVMS only)
#
# Spoke CPU workload budget (approximate):
#   OVMS ModelMesh 1 CPU/2 GiB, YOLO PPE 0.2-2 CPU/1-3 GiB, NeuroFace 0.5/1 GiB,
#   Kafka 1/2 GiB, Skupper 0.2/0.5 GiB, ACS 0.5/1.5 GiB, DevSpaces 1/2 GiB per workspace
set -euo pipefail

ROLE="${ROLE:-hub}"
WORKSHOP_USERS="${WORKSHOP_USERS:-30}"
SPOKE_TIER="${SPOKE_TIER:-recommended}"
CHECK_GPU="${CHECK_GPU:-0}"
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
    if [[ -z "$MIN_CPU" ]]; then
      case "$SPOKE_TIER" in
        minimum)
          MIN_CPU=8
          MIN_MEM_GIB="${MIN_MEM_GIB:-32}"
          ;;
        recommended|*)
          MIN_CPU=24
          MIN_MEM_GIB="${MIN_MEM_GIB:-96}"
          ;;
      esac
    else
      MIN_MEM_GIB="${MIN_MEM_GIB:-96}"
    fi
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

echo "Role: ${ROLE} (workshop users: ${WORKSHOP_USERS}, spoke tier: ${SPOKE_TIER})"
echo "Workers: ${count}"
echo "Allocatable total: ${total_cpu} CPU, ${total_mem_gib} GiB"
echo "Required minimum:  ${MIN_CPU} CPU, ${MIN_MEM_GIB} GiB"

fail=0
awk -v have="$total_cpu" -v need="$MIN_CPU" 'BEGIN { exit (have+0 >= need+0) ? 0 : 1 }' || { echo "FAIL: CPU below minimum" >&2; fail=1; }
awk -v have="$total_mem_gib" -v need="$MIN_MEM_GIB" 'BEGIN { exit (have+0 >= need+0) ? 0 : 1 }' || { echo "FAIL: memory below minimum" >&2; fail=1; }

if [[ "$CHECK_GPU" == "1" ]]; then
  gpu_total=$(oc get nodes -l node-role.kubernetes.io/worker= \
    -o jsonpath='{range .items[*]}{.status.allocatable.nvidia\.com/gpu}{"\n"}{end}' 2>/dev/null \
    | awk '{sum += ($1 == "" ? 0 : $1+0)} END {print sum+0}')
  echo "GPU allocatable (nvidia.com/gpu): ${gpu_total}"
  if [[ "${gpu_total:-0}" -lt 1 ]]; then
    echo "FAIL: no nvidia.com/gpu allocatable on worker nodes (install NFD + NVIDIA GPU Operator)" >&2
    fail=1
  fi
fi

if (( fail > 0 )); then
  echo ""
  echo "Hint: hub workshop-50 = 4×16×64 GiB; spoke recommended = 3×8×32 GiB (see README cluster sizing)."
  exit 1
fi

echo "OK: node capacity meets ${ROLE} minimums."
