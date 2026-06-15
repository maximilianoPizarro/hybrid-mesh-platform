#!/usr/bin/env bash
# Copy PlanPolicy tiers into APIProduct status.discoveredPlans (Kuadrant edit UI requires this).
set -euo pipefail

echo "== Sync APIProduct status.discoveredPlans from PlanPolicy =="

if ! oc whoami &>/dev/null; then
  echo "ERROR: log in to hub" >&2
  exit 1
fi

python3 <<'PY'
import json, subprocess

def oc(*args):
    return subprocess.check_output(["oc", *args], text=True)

products = json.loads(oc("get", "apiproducts.devportal.kuadrant.io", "-A", "-o", "json"))["items"]
policies = json.loads(oc("get", "planpolicies.extensions.kuadrant.io", "-A", "-o", "json"))["items"]
by_route = {}
for p in policies:
    ref = p.get("spec", {}).get("targetRef") or {}
    if ref.get("kind") == "HTTPRoute" and ref.get("name"):
        by_route[(p["metadata"]["namespace"], ref["name"])] = p

synced = 0
for prod in products:
    meta = prod["metadata"]
    ns, name = meta["namespace"], meta["name"]
    ref = prod.get("spec", {}).get("targetRef") or {}
    route = ref.get("name")
    if not route:
        print(f"skip {ns}/{name}: no targetRef HTTPRoute")
        continue
    pol = by_route.get((ns, route))
    if not pol:
        print(f"skip {ns}/{name}: no PlanPolicy for route {route}")
        continue
    plans = []
    for plan in pol.get("spec", {}).get("plans") or []:
        entry = {"tier": plan.get("tier")}
        if plan.get("limits"):
            entry["limits"] = plan["limits"]
        plans.append(entry)
    patch = json.dumps({"status": {"discoveredPlans": plans}})
    subprocess.run(
        ["oc", "patch", "apiproduct", name, "-n", ns, "--type=merge", "--subresource=status", "-p", patch],
        check=True,
    )
    print(f"OK {ns}/{name}: {len(plans)} plan(s)")
    synced += 1

print(f"Synced {synced} APIProduct(s)")
PY

echo "Done"
