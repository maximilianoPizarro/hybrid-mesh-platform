---
title: Troubleshooting
weight: 14
---

# Troubleshooting

Production lessons from fleet GitOps, ambient mesh, and centralized observability. See also ebook Ch.15 matrix (adapted below).

**RHDP fleets:** Start with the [RHDP install playbook](install-improvements.md) for install order, spoke token anti-patterns, console-link 503s during the first hour, and operator bootstrap blockers.

## Symptom matrix

| Symptom | Likely cause | Fix |
| ------- | ------------ | --- |
| Hub console links **503** (Developer Hub, Gitea, ODS, Skupper) | Backends still syncing or missing deps (catalog CM, SCC, Site) | Wait 60–90 min; see [install playbook](install-improvements.md) sections per product |
| OpenShift AI link **403** in curl | OAuth-protected dashboard | Log in with `oc login`; script uses `oc whoami -t` bearer token |
| East/west namespaces **Terminating** / recreating | Spoke tokens in auto-syncing `field-content` while import fails, or **Namespace pre-created** with `managedCluster` label before `ManagedCluster` | Remove tokens from GitOps values; import via ACM UI or chart order (`ManagedCluster` first); `fleet-values-sync` = domains only |
| `acm-operator` stuck, no MCH | CRD not ready before PostSync | `helm template acm charts/all/acm-operator \| oc apply -f -` |
| RHODS / COO CSV *multiple operatorgroups* | Duplicate OG from subscription + `operatorGroup: true` | Remove duplicate OG flag in hub values |
| ArgoCD apps show **Unknown** sync status | ACM 2.16 CRD schema bug | Add resource exclusion for `clusterview.open-cluster-management.io`; see [below](#argocd-unknown-sync-status-acm-216) |
| `upstream connect error` / 503 on mesh routes | HBONE port 15008 not configured (pod before ztunnel) | Restart pods in ambient namespaces; ensure ambient labels at sync-wave **2** after Istio/ZTunnel |
| ApplicationSet Degraded: *both name and server* | Stale `destination.server` from older template (SSA) | Delete/recreate ApplicationSet or set `server: ""` in template |
| ACM UI: *no Argo applications created* | ApplicationSet missing `cluster.open-cluster-management.io/placement` label | Label ApplicationSet + child Apps; verify with `oc get applications -n openshift-gitops \| grep spoke` |
| Kiali: `Unauthorized` on east/west | Stale **`kiali-multi-cluster-secret`** or expired spoke token | Delete aggregate secret; run token-sync job; restart Kiali pod |
| Kafka Console: `/api/kafkas` 404 | External route hits UI only; Next.js does not proxy `/api` | Enable `apiRoute` in `charts/all/kafka-console`; verify HTTP 200 on `/api/kafkas` |
| Strimzi entity-operator CrashLoop | mTLS on 9091 conflicts with ztunnel | Exclude operator namespace from ambient or use documented Strimzi tuning |
| Skupper listener not Ready | Site or token not synced | Check `oc get site,listener -n service-interconnect` on hub and spoke |
| GitOpsCluster: *legacy secret not found* | ACM hasn't created cluster secret yet | Wait 5-10 min; check klusterlet on spoke; verify ManagedCluster is Joined |
| Kuadrant `/kuadrant`: failed to fetch APIProducts | K8s plugin lacks `devportal.kuadrant.io` RBAC | Sync `developer-hub`; verify `oc auth can-i list apiproducts.devportal.kuadrant.io --as=system:serviceaccount:developer-hub:developer-hub -A` |
| API Overview: Expected object at root, got string | Incomplete OpenAPI in catalog entity | Ensure API entities have valid `definition` with `paths`; fix `$text` file refs in `reading.allow` |
| TechDocs tab 404 / builder not local | `techdocs.builder: external` or missing mkdocs | Set `builder: local` in app-config; scaffolded repos need `mkdocs.yml` + `backstage.io/techdocs-ref: dir:.` |
| Quay org-setup Job failing | `/version` redirect, CSRF, or duplicate robot | Use GitOps `setup.py` with `/discovery` + bearer token; see [Quay](products/quay.md) |
| DevSpaces link on hub 404 | DevSpaces is spoke-only | Open `https://devspaces.<east-or-west-domain>` from template output |
| MCP Gateway **503** / `/mcp` 404 | Argo Unknown — CRDs never applied | `bash scripts/apply-mcp-gateway.sh` |
| Developer Hub **/lightspeed** chat 401 | Missing MaaS key or wrong vLLM URL | `bash scripts/apply-maas-secrets.sh`; default model `granite-3-2-8b-instruct` via MaaS |
| NeuroFace **/api/chat** 401 | Secret `neuroface-maas-api-key` placeholder | `apply-maas-secrets.sh` + rollout `neuroface` |
| workshop-apis **401** without key | Expected (Kuadrant AuthPolicy) | Request key at Developer Hub `/kuadrant` |
| Vault console link **307** | href points to route root | Use `/ui/` — see [install playbook](install-improvements.md#hashicorp-vault-hub) |
| Camel `mqtt-to-kafka` Error, Kafka metadata timeout | Missing advertised EndpointSlice or ambient ztunnel on Kafka TCP | EndpointSlice + `deployment` trait `istio.io/dataplane-mode: none`; see [below](#kafka-advertised-dns-endpointslice) |
| Stormshift MirrorMaker2 CrashLoop | Empty `clusterName` → `broker-0-.` | Set `clusterName: east|west` in spoke app values |

---

## ArgoCD Unknown sync status (ACM 2.16)

**Symptom:** All ArgoCD applications show "Unknown" sync status in the UI, even though they are healthy and syncing correctly.

**Error message:**

```text
SchemaError(github.com/stolostron/cluster-lifecycle-api/clusterview/v1alpha1.UserPermission.status): 
unknown model in reference
```

**Cause:** ACM 2.16 introduces CRDs that ArgoCD's cluster cache cannot parse correctly. This affects the OpenAPI schema loading but does not impact actual sync operations.

**Verification:** Applications still show `Healthy` health status and `operationState.phase: Succeeded`:

```bash
# Check actual operation state (should show "Succeeded")
oc get application <app-name> -n openshift-gitops \
  -o jsonpath='{.status.operationState.phase}'

# All apps healthy?
oc get applications -n openshift-gitops -o jsonpath='{range .items[*]}{.metadata.name}: {.status.health.status}{"\n"}{end}' | grep -v Healthy
```

**Automated fix (new installations):** The `openshift-gitops` chart now includes `resourceExclusions` for `clusterview.open-cluster-management.io` and `internal.open-cluster-management.io` by default. New installations are not affected.

**Manual workaround (existing installations):**

```bash
# Patch ArgoCD with resource exclusion
oc patch argocd openshift-gitops -n openshift-gitops --type merge -p '{
  "spec": {
    "resourceExclusions": "- apiGroups:\n  - clusterview.open-cluster-management.io\n  kinds:\n  - \"*\"\n  clusters:\n  - \"*\"\n- apiGroups:\n  - internal.open-cluster-management.io\n  kinds:\n  - \"*\"\n  clusters:\n  - \"*\"\n"
  }
}'

# Restart the application controller
oc rollout restart statefulset openshift-gitops-application-controller -n openshift-gitops

# Wait for restart
oc rollout status statefulset openshift-gitops-application-controller -n openshift-gitops --timeout=120s
```

**Note:** On **new** hubs, `acm-operator` disables MCE `cluster-proxy-addon` via PostSync/CronJob. On **existing** hubs stuck in Unknown, sync may remain blocked until reinstall — resource exclusions alone may not suffice. Monitor `health.status`, Routes, and pod counts — not only `sync.status`.

---

## MCE cluster-proxy-addon (ACM 2.16+)

**Symptom:** Argo CD spoke apps use `destination.server` = cluster-proxy URL; proxy add-on conflicts with hub cluster-wide proxy or complicates GitOps debugging.

**Default in ACM/MCE 2.16:** `cluster-proxy-addon` component is **enabled**.

**Automated fix (new installations):** Chart `charts/all/acm-operator` runs PostSync Job + CronJob (`acm-mce-disable-cluster-proxy`) that sets `MultiClusterEngine/spec.overrides.components[name=cluster-proxy-addon].enabled: false`.

**Verify:**

```bash
oc get mce multiclusterengine -o jsonpath='{range .spec.overrides.components[*]}{.name}={.enabled}{"\n"}{end}' | grep cluster-proxy
# expect: cluster-proxy-addon=false
```

**Disable automation:** set `mceDisableClusterProxyAddon: false` in `acm-operator` values (hub clustergroup override if needed).

**Limitation:** Disabling the add-on does **not** always remove `ocm-proxyserver` in `multicluster-engine` — that deployment is a separate MCE component. Spoke `ManagedClusterAddon/cluster-proxy` on local-cluster may also need manual review if pod-log-via-proxy features are required.

**Manual one-shot:**

```bash
oc patch mce multiclusterengine --type=merge -p '{"spec":{"overrides":{"components":[{"name":"cluster-proxy-addon","enabled":false}]}}}'
```

For a full component list merge without dropping other overrides, use the Job script in `charts/all/acm-operator/files/disable-cluster-proxy-addon.py`.

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

---

## Industrial Edge alerts not in Mailpit

**Symptom:** `ie-anomaly-alerter` logs show `Failed to send mail: HTTP Error 503` or Mailpit UI is empty while MQTT anomalies appear in pod logs.

**Causes:**

1. **Wrong hub domain on spokes** — `MAILPIT_URL` must be `https://mailpit.<hub-apps-domain>/api/v1/send`, not the spoke's own domain. Check:
   ```bash
   oc get deploy ie-anomaly-alerter -n industrial-edge-tst-all \
     -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="MAILPIT_URL")].value}{"\n"}'
   ```
2. **`ie-anomaly-alerter` not deployed** — Argo CD app **Missing** on east/west; apply with correct `hubClusterDomain`:
   ```bash
   helm template ie charts/all/ie-anomaly-alerter \
     --set hubClusterDomain=apps.cluster-<hub-id>.dynamic2.redhatworkshops.io \
     --set clusterName=east | oc apply -f -
   ```
3. **`fleet-values-sync` stale on ACM 2.16** — spoke domains were not derived when the job looked for `kube-apiserver` instead of `apiserverurl.openshift.io`. Re-run after chart fix:
   ```bash
   oc create job --from=cronjob/fleet-values-sync fleet-values-sync-manual -n openshift-gitops
   ```

**Verify:** Mailpit route returns 200 on POST `/api/v1/send`; alerter logs `Mail sent [...] -> 200`.

**Camel K `401 Unauthorized` / `ImagePullBackOff` on internal registry:** The PostSync Job `camel-k-registry-bootstrap` creates `camel-k-registry-docker` from the `builder` SA token and patches `IntegrationPlatform` + `pull-secret` trait. If the integration kit is stuck in Error, delete the Integration and IntegrationKit, then re-sync the app.

**Camel K + Istio ambient (MQTT → Kafka silent failure):** With `istio.io/dataplane-mode: ambient` on `industrial-edge-tst-all`, ztunnel intercepts Kafka broker TCP and Camel cannot complete metadata fetch. Git fix: `deployment` trait (not `pod`) sets `istio.io/dataplane-mode: none` on the integration Deployment.

```yaml
# charts/all/industrial-edge-tst/templates/camel-integrations.yaml
traits:
  deployment:
    configuration:
      metadata:
        labels:
          istio.io/dataplane-mode: none
```

---

## Kafka advertised DNS (EndpointSlice)

**Symptom:** Camel or MirrorMaker2 logs `UnknownHostException` for `dev-cluster-broker-0-<clusterName>.<namespace>.svc` or metadata request timeout.

**Cause:** Strimzi `Kafka` CR sets `advertisedHost` to a custom DNS name; clients resolve it via hub **EndpointSlice** objects that Skupper/kafka-console charts create. If `clusterName` is empty in spoke values, broker hostnames are invalid (`broker-0-.`).

**Fix:**

1. Set `clusterName: east|west` in `charts/region/east|west/values.yaml` for IE tst, stormshift, datalake apps.
2. Verify EndpointSlices exist on hub for each broker advertised name.
3. Re-sync `field-content-kafka-console` if west/east broker lists are stale.

```bash
oc get endpointslices -A | grep kafka-brokers-advertised
oc get kafka -n industrial-edge-tst-all -o yaml | grep -A2 advertisedHost
```

---

## MCP Gateway (Argo Unknown)

**Symptom:** `https://mcp-gateway.<hub-domain>/mcp` returns **503** or **404**; Argo app `mcp-gateway` sync **Unknown**.

**Cause:** ACM 2.16 schema bug blocks Application sync; MCPServerRegistration CRDs and routes never land.

**Fix:**

```bash
bash scripts/apply-mcp-gateway.sh
curl -sk -o /dev/null -w '%{http_code}\n' https://mcp-gateway.<hub-domain>/mcp
# Expect 200
```

---

## spoke-gateway Degraded (`modelmesh-serving` not found)

**Symptom:** Argo CD app `spoke-gateway-east` (on the **east** cluster) shows HTTPRoute `ie-anomaly-detection` Degraded.

**Cause:** Optional KServe/ModelMesh route points at a backend that is not Ready yet (or ML stack not installed).

**Fix (GitOps):** `charts/all/spoke-gateway/values.yaml` sets `inferenceRoute.enabled: false` by default. Enable only after `InferenceService` is Ready and set backend namespace to `redhat-ods-applications` when using cluster-scoped ModelMesh.

---

---

## MaaS / Lightspeed / NeuroFace 401

**Symptom:** Developer Hub `/lightspeed` loads but chat fails with **401** or empty response; NeuroFace `/api/chat` returns **401**.

**Cause:** MaaS API keys not injected — secrets contain `CHANGEME-inject-via-RHDP` or Lightspeed sync Job skipped.

**Fix:**

```bash
export MAAS_KEY_LLAMA='sk-...'
export MAAS_KEY_GRANITE='sk-...'
bash scripts/apply-maas-secrets.sh
oc rollout restart deployment/developer-hub -n developer-hub
oc rollout restart deployment/neuroface -n neuroface
```

Verify:

```bash
oc get secret kairos-ai-credentials -n kairos-system -o jsonpath='{.data.api-key}' | base64 -d | wc -c
curl -sk -X POST https://neuroface.<hub-domain>/api/chat \
  -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"hi"}]}'
```

**Lightspeed model:** defaults to **MaaS** `granite-3-2-8b-instruct` (`plugins.lightspeed.aiModel` in `developer-hub` chart). Requires valid key in `llama-stack-secrets` / Kairos sync.

---

## Camel Dashboard (spoke console plugin)

**Symptom:** No **Camel** tab in the OpenShift console on east/west, or Argo app `camel-dashboard-openshift-all-{east,west}` OutOfSync.

**GitOps:** Vendored wrapper `charts/all/camel-dashboard-openshift` (umbrella **4.20.2** in `charts/*.tgz`), namespace `camel-dashboard`, sync wave `3` (see `charts/region/east/values.yaml`, `charts/region/west/values.yaml`). Avoids Argo `DeadlineExceeded` when spokes cannot reach the public Helm repo in time.

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

**`east-spoke-components` stuck Progressing:** Usually waiting on `devspaces-east` (CheCluster `InstallOrUpdateFailed` while `chePhase: Active`). Fixes: delete orphan **`east-devspaces`** on the spoke (duplicate of `devspaces-east`, often with `deletionTimestamp`); ensure only `devspaces` from `charts/region/east/values.yaml` exists. Git: `ignoreDifferences` on `CheCluster` status + `argocd.argoproj.io/skip-health-check` on the CheCluster CR. Then `oc patch application east-spoke-components -n openshift-gitops --type json -p='[{"op":"remove","path":"/operation"}]'` and re-sync.

**Cannot find ApplicationSet in ACM UI:** ACM **Applications** lists `Application` CRs only. Use `oc get applicationset fleet-spoke-push -n openshift-gitops` on the hub, or open **OpenShift GitOps → ApplicationSets**. Child apps like `industrial-edge-tst` on the east spoke come from `charts/region/east/values.yaml` (PULL), not from the ApplicationSet template directly.

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

- [Validation Guide](../validation-guide.md) — quick health checks and component validation
- [Bill of Materials](../bill-of-materials.md) — operator versions and compatibility
- [Service Mesh sync waves](products/service-mesh.md#sync-wave-ordering-ambient)
- [Architecture sync-wave table](architecture.md#spoke-sync-wave-reference)
- [Getting Started](getting-started.md)
- [Support Policy](../../SUPPORT.md) — community support channels
