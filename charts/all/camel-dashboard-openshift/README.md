# Camel Dashboard (spoke wrapper)

Vendored Helm wrapper for [camel-dashboard-openshift-all](https://camel-tooling.github.io/camel-dashboard/) on **east** and **west** spokes only (not hub).

## Why a wrapper chart?

- Argo CD on spokes must not depend on live access to `camel-tooling.github.io` during every sync (avoids `DeadlineExceeded`).
- The umbrella chart `.tgz` is committed under `charts/` (see root `.gitignore` exception).
- Hawtio is disabled by default; stub ports in `values.yaml` avoid upstream test-template nil-pointer errors when Hawtio is off.

## OCP version pin

| OpenShift | Umbrella chart version | `kubeVersion` (upstream) |
| --------- | ---------------------- | ------------------------- |
| 4.20.x    | **4.20.2**             | `>= 1.33`                 |
| 4.21.x    | 4.21.0+                | `>= 1.33` / `>= 1.34`     |

Do not use 4.21.x charts on OCP 4.20 clusters.

## GitOps wiring

- `east/values.yaml` and `west/values.yaml`: app `camel-dashboard-openshift-all`, `path: components/camel-dashboard-openshift`, `syncWave: "3"`, namespace `camel-dashboard`.
- Spoke templates: `{{- if .chart }}` for optional external charts; Camel uses git path + `helm: {}` (chart defaults).

## Fresh install checklist

1. Hub `field-content-acm-hub-spoke` synced → persistent ApplicationSet `industrial-edge-spoke` creates `{east,west}-spoke-components` (see [GitOps deployment chain](../../docs/gitops-deployment-chain.md)).
2. Spoke Argo syncs `camel-dashboard-openshift-all-{east,west}`.
3. **Cluster admin:** enable **Camel Dashboard** under **Administration → Cluster settings → Console**.
4. Expect **CamelApp** CRs in the dashboard, not Camel K `Integration` workloads (see [Troubleshooting](../../docs/troubleshooting.md)).

## Upgrade upstream version

From repo root:

```bash
./scripts/vendor-camel-dashboard-chart.sh 4.20.2
```

Commit `Chart.lock`, `Chart.yaml` (if version changed), and `charts/*.tgz`, then sync spoke Argo apps.

## Functional note

Industrial Edge uses Camel K `Integration` resources. The console plugin lists **CamelApp** CRs managed by the Camel Dashboard operator. Bridging or separate `CamelApp` objects are required for full visibility in the Camel tab.
