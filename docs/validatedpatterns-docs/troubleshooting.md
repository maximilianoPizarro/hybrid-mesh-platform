---
title: Troubleshooting
weight: 14
---

# Troubleshooting

Production lessons from fleet GitOps, ambient mesh, and centralized observability. See also ebook Ch.15 matrix (adapted below).

## Symptom matrix

| Symptom | Likely cause | Fix |
| ------- | ------------ | --- |
| `upstream connect error` / 503 on mesh routes | HBONE port 15008 not configured (pod before ztunnel) | Restart pods in ambient namespaces; ensure ambient labels at sync-wave **2** after Istio/ZTunnel |
| ApplicationSet Degraded: *both name and server* | Stale `destination.server` from older template (SSA) | Delete/recreate ApplicationSet or set `server: ""` in template |
| ACM UI: *no Argo applications created* | ApplicationSet missing `cluster.open-cluster-management.io/placement` label | Label ApplicationSet + child Apps; verify with `oc get applications -n openshift-gitops \| grep spoke` |
| Kiali: `Unauthorized` on east/west | Stale **`kiali-multi-cluster-secret`** or expired spoke token | Delete aggregate secret; run token-sync job; restart Kiali pod |
| Kafka Console: `/api/kafkas` 404 | External route hits UI only; Next.js does not proxy `/api` | Enable `apiRoute` in `charts/all/kafka-console`; verify HTTP 200 on `/api/kafkas` |
| Strimzi entity-operator CrashLoop | mTLS on 9091 conflicts with ztunnel | Exclude operator namespace from ambient or use documented Strimzi tuning |
| Skupper listener not Ready | Site or token not synced | Check `oc get site,listener -n service-interconnect` on hub and spoke |
| Kuadrant `/kuadrant`: failed to fetch APIProducts | K8s plugin lacks `devportal.kuadrant.io` RBAC | Sync `developer-hub`; verify `oc auth can-i list apiproducts.devportal.kuadrant.io --as=system:serviceaccount:developer-hub:developer-hub -A` |
| API Overview: Expected object at root, got string | Incomplete OpenAPI in catalog entity | Ensure API entities have valid `definition` with `paths`; fix `$text` file refs in `reading.allow` |
| TechDocs tab 404 / builder not local | `techdocs.builder: external` or missing mkdocs | Set `builder: local` in app-config; scaffolded repos need `mkdocs.yml` + `backstage.io/techdocs-ref: dir:.` |
| Quay org-setup Job failing | `/version` redirect, CSRF, or duplicate robot | Use GitOps `setup.py` with `/discovery` + bearer token; see [Quay](products/quay.md) |
| DevSpaces link on hub 404 | DevSpaces is spoke-only | Open `https://devspaces.<east-or-west-domain>` from template output |

---

## HBONE port 15008 not configured

**Symptom:** Routes return `upstream connect error` or 503; ztunnel logs show missing HBONE listener for pod IP.

**Cause:** Workloads started **before** ambient enrollment or before ztunnel programmed iptables.

**Fix:**

1. Ensure namespaces get `istio.io/dataplane-mode: ambient` **after** Istio + IstioCNI + ZTunnel (wave 2 in `servicemeshoperator3`, not wave 1 `namespaces`).
2. Restart affected Deployments after mesh is Ready.
3. `reconcileIptablesOnStartup: true` on IstioCNI helps new nodes but does not retrofix running pods.

```yaml
# charts/all/servicemeshoperator3 — ambient labels (wave 2)
metadata:
  labels:
    istio.io/dataplane-mode: ambient
  annotations:
    argocd.argoproj.io/sync-wave: "2"
```

---

## ApplicationSet: both `name` and `server` defined

**Symptom:**

```text
application destination spec is invalid: application destination can't
have both name and server defined: west https://kubernetes.default.svc
```

**Cause:** Older ApplicationSet template set `server`; Server-Side Apply does not remove fields the new manifest omits.

**Fix:**

```yaml
# charts/all/acm-hub-spoke/templates/applicationset.yaml
destination:
  name: '{{name}}'
  namespace: openshift-gitops
  server: ""   # explicit blank clears stale SSA
```

Then delete and let Argo CD recreate the ApplicationSet, or patch live spec to remove `server`.

---

## Kiali multi-cluster Unauthorized

**Symptom:** Hub Kiali logs: `Error fetching Namespaces for cluster [east]: Unauthorized`.

**Cause:**

1. Expired token in spoke `kiali-hub-export` ConfigMap.
2. Legacy **`kiali-multi-cluster-secret`** still labeled `kiali.io/multiCluster=true` alongside **`kiali-remote-*`** secrets.

**Fix:**

```bash
# Hub
oc delete secret kiali-multi-cluster-secret -n openshift-cluster-observability-operator --ignore-not-found
oc create job kiali-token-refresh --from=cronjob/kiali-multicluster-token-sync \
  -n openshift-cluster-observability-operator
oc delete pod -n openshift-cluster-observability-operator -l app=kiali
```

On spokes, confirm export ConfigMap exists:

```bash
oc get cm kiali-hub-export -n openshift-cluster-observability-operator -o jsonpath='{.data.updatedAt}'
```

---

## Kafka Console 404 on `/api/*`

**Symptom:** Browser or `curl` to `https://kafka-console.<hub-domain>/api/kafkas` returns Next.js HTML 404; in-pod `console-api` returns 200.

**Cause:** Operator Service targets UI port 3000 only; external route does not split `/api` to port 8080.

**Fix:** Deploy supplemental Route (GitOps: `charts/all/kafka-console/templates/api-route.yaml`):

```yaml
spec:
  host: kafka-console.apps.hub.example.com
  path: /api
  to:
    kind: Service
    name: kafka-console-api-service
  port:
    targetPort: http   # 8080 on console-api container
```

Do **not** set `haproxy.router.openshift.io/rewrite-target` — the API expects the `/api` prefix.

### Blank UI / NextAuth 404 on `/api/auth/*`

**Symptom:** Kafka Console page loads partially or stays blank; browser network tab shows **404** on `/api/auth/providers`; `console-api` logs show `GET /api/auth/providers ... 404`.

**Cause:** The supplemental `/api` Route sends **all** `/api/*` traffic to Quarkus. NextAuth runs in the **UI** container (Next.js) on port **3000**, not in `console-api`.

**Fix:** Add a more specific Route **`/api/auth`** → `kafka-console-console-service` with `port.targetPort: **3000**` (not `80` — the Service’s EndpointSlice exposes pod port 3000). GitOps: `charts/all/kafka-console/templates/api-route.yaml` (`kafka-console-ui-auth`).

```bash
curl -sk -o /dev/null -w '%{http_code}\n' \
  https://kafka-console.<hub-domain>/api/auth/providers
# Expect 200
```

### JSON `404` / code `4041` on cluster detail

**Symptom:** UI shows `{"errors":[{"title":"Resource not found","status":"404","code":"4041"}]}` when opening a Kafka cluster.

**Cause:** Valid API route, but the cluster id is unknown **or** the console-api cannot reach brokers (often west spoke offline → Skupper listener has no connector).

**Checks:**

```bash
# List works?
curl -sk https://kafka-console.<hub-domain>/api/kafkas

# Detail per cluster (replace id from list response)
curl -sk -o /dev/null -w '%{http_code}\n' https://kafka-console.<hub-domain>/api/kafkas/<id>

# West spoke up?
oc config use-context west
oc get applications spoke-interconnect-west -n openshift-gitops
oc get link -n service-interconnect
```

**Fix:** Restore west (or east) spoke apps and Skupper link; resync `field-content-kafka-console` for broker DNS EndpointSlices.

---

## industrial-edge-tst Degraded (Camel / KServe)

**Symptom:** Argo CD app `industrial-edge-tst-east` (or `-west`) is **Degraded** with:

- `Integration/mqtt-to-kafka`: `dependency camel:mqtt not found in Camel catalog`
- `InferenceService/anomaly-detection`: stuck **Progressing**; sync waits for healthy state

**Causes:**

1. **Camel K:** Routes use `paho:` URIs; the catalog dependency is **`camel:paho`**, not `camel:mqtt`.
2. **KServe:** Chart ships `InferenceService` only when `anomalyDetection.enabled: true`. Default is **`false`** because spokes need ODH **RawDeployment** (no Serverless Operator), a MinIO model at `s3://models/anomaly-detection/model`, and a Ready `DataScienceCluster`. Threshold alerts still work via `ie-anomaly-alerter` without KServe.

**Fix (GitOps):**

```yaml
# charts/all/industrial-edge-tst/templates/camel-integrations.yaml
dependencies:
  - camel:paho
  - camel:kafka

# charts/all/industrial-edge-data-science-cluster — edge RawDeployment
kserve:
  defaultDeploymentMode: RawDeployment
  serving:
    managementState: Removed
modelmeshserving:
  managementState: Removed
```

**Verify Camel integration:**

```bash
oc get integration mqtt-to-kafka -n industrial-edge-tst-all \
  -o jsonpath='{range .status.conditions[?(@.type=="Ready")]}{.status} {.message}{"\n"}{end}'
```

**Enable ML inference later:** upload model to MinIO, set `anomalyDetection.enabled: true` in spoke app values, sync `industrial-edge-data-science-cluster` then `industrial-edge-tst`.

**Camel K `401 Unauthorized` / `ImagePullBackOff` on internal registry:** The PostSync Job `camel-k-registry-bootstrap` creates `camel-k-registry-docker` from the `builder` SA token and patches `IntegrationPlatform` + `pull-secret` trait. If the integration kit is stuck in Error, delete the Integration and IntegrationKit, then re-sync the app.

---

## spoke-gateway Degraded (`modelmesh-serving` not found)

**Symptom:** Argo CD app `spoke-gateway-east` (on the **east** cluster) shows HTTPRoute `ie-anomaly-detection` Degraded.

**Cause:** Optional KServe/ModelMesh route points at a backend that is not Ready yet (or ML stack not installed).

**Fix (GitOps):** `charts/all/spoke-gateway/values.yaml` sets `inferenceRoute.enabled: false` by default. Enable only after `InferenceService` is Ready and set backend namespace to `redhat-ods-applications` when using cluster-scoped ModelMesh.

---

## Camel Dashboard (spoke console plugin)

**Symptom:** No **Camel** tab in the OpenShift console on east/west, or Argo app `camel-dashboard-openshift-all-{east,west}` OutOfSync.

**GitOps:** Vendored wrapper `charts/all/camel-dashboard-openshift` (umbrella **4.20.2** in `charts/*.tgz`), namespace `camel-dashboard`, sync wave `3` (see `east/values.yaml`, `west/values.yaml`). Avoids Argo `DeadlineExceeded` when spokes cannot reach the public Helm repo in time.

**Post-sync (cluster-admin, once per spoke):** **Administration → Cluster settings → Console** → enable the **Camel Dashboard** console plugin. Argo ignores `ConsolePlugin.spec.enablement` so manual enablement does not fight GitOps.

**Camel K vs CamelApp:** Industrial Edge uses Camel K `Integration` resources (e.g. `mqtt-to-kafka`). The dashboard operator primarily manages **`CamelApp`** CRs. Integrations may not appear in the Camel tab until you register them as `CamelApp` or add a bridge; use Topology/Kamelet views for Camel K workloads in the meantime.

**Symptom:** `Failed to get a valid plugin manifest from /api/plugins/camel-dashboard-console/`

**Cause:** The `camel-dashboard-console` Service has **no endpoints** — usually `app.kubernetes.io/instance` on the Service selector does not match the Deployment pod labels (e.g. after `helm template` + `oc apply` with release name `camel-dashboard` instead of `camel-dashboard-openshift-all-{east,west}`).

**Fix:**

```bash
# Endpoints must be non-empty
oc get endpointslices -n camel-dashboard -l kubernetes.io/service-name=camel-dashboard-console -o yaml | grep -A3 addresses

# Align selector with running pods (or re-sync Argo with helm.releaseName set in spoke templates)
oc get svc camel-dashboard-console -n camel-dashboard -o jsonpath='selector={.spec.selector}{"\n"}'
oc get pod -n camel-dashboard -l app=camel-dashboard-console -o jsonpath='instance={.items[0].metadata.labels.app\.kubernetes\.io/instance}{"\n"}'

# Test manifest from inside the cluster
oc run curl-camel --rm -i --restart=Never -n camel-dashboard \
  --image=registry.redhat.io/ubi9/ubi-minimal:latest -- \
  curl -sk https://camel-dashboard-console.camel-dashboard.svc:9443/plugin-manifest.json
```

Prefer **Argo CD sync** (not manual `helm apply`) so `releaseName: camel-dashboard-openshift-all-{cluster}` matches Service and Deployment labels.

**Checks:**

```bash
oc get application camel-dashboard-openshift-all-east -n openshift-gitops -o jsonpath='{.status.sync.status}{" "}{.status.health.status}{"\n"}'
oc get deployment -n camel-dashboard
oc get consoleplugin | grep -i camel
```

**Air-gapped spokes:** mirror the Helm repo or chart tgz internally and point `repoURL` / `targetRevision` in spoke `values.yaml`.

**Helm template error (Hawtio disabled):** If Argo reports `index of nil pointer` on `hawtio-online-console-plugin`, ensure spoke `valuesObject` includes stub `plugin.service.port` and `gateway.service.port` (see `east/templates/component-applications.yaml`).

**East spoke `Unknown` apps:** If `east-spoke-components` was removed from the hub, re-sync `field-content-acm-hub-spoke` so ApplicationSet `fleet-spoke-push` recreates it (see [GitOps deployment chain](gitops-deployment-chain.md)).

**`east-spoke-components` stuck Progressing:** Usually waiting on `devspaces-east` (CheCluster `InstallOrUpdateFailed` while `chePhase: Active`). Fixes: delete orphan **`east-devspaces`** on the spoke (duplicate of `devspaces-east`, often with `deletionTimestamp`); ensure only `devspaces-east` from `values-east.yaml` (ACM PULL) chart exists. Git: `ignoreDifferences` on `CheCluster` status + `argocd.argoproj.io/skip-health-check` on the CheCluster CR. Then `oc patch application east-spoke-components -n openshift-gitops --type json -p='[{"op":"remove","path":"/operation"}]'` and re-sync.

**Cannot find ApplicationSet in ACM UI:** ACM **Applications** lists `Application` CRs only. Use `oc get applicationset fleet-spoke-push -n openshift-gitops` on the hub, or open **OpenShift GitOps → ApplicationSets**. Child apps like `industrial-edge-tst-east` come from the `values-east.yaml` (ACM PULL) chart, not from the ApplicationSet template directly.

---

## Argo CD: where applications live

| Cluster | Namespace | Examples |
| ------- | --------- | -------- |
| Hub | `openshift-gitops` | `field-content-*`, `east-spoke-components`, `west-spoke-components` |
| East spoke | `openshift-gitops` | `camel-dashboard-openshift-all-east`, `operators-east`, `spoke-gateway-east`, `spoke-interconnect-east` |
| West spoke | `openshift-gitops` | `camel-dashboard-openshift-all-west`, `operators-west`, `spoke-gateway-west`, `spoke-interconnect-west` |

Parent apps use `destination.server` = cluster-proxy URL. Child apps on spokes use `https://kubernetes.default.svc`.

---


**Symptom:** `entity-operator` CrashLoopBackOff after enabling ambient on Kafka namespaces.

**Cause:** Double encryption or ztunnel intercept on internal replication port 9091.

**Fix:** Keep Kafka control-plane namespaces off ambient where documented, or follow Strimzi + OSSM ambient guidance for your version.

---

## Related docs

- [Service Mesh sync waves](products/service-mesh.md#sync-wave-ordering-ambient)
- [Architecture sync-wave table](architecture.md#spoke-sync-wave-reference)
- [Getting Started](getting-started.md)
