# Troubleshoot Skill

**RHDP fleets:** start with `docs/validatedpatterns-docs/install-improvements.md` — install order, token anti-patterns, first-hour 503s.

## Common Issues and Solutions

### 0. Hub console links 503 / verify fails

**Symptom:** `verify-console-links.sh` shows 503 or non-200 on hub links.

**First:** Ensure logged in — OpenShift AI returns **403** without bearer token:

```bash
oc login --token=<token> --server=<hub-api-url>
MIN_OK_CODE=200 bash scripts/verify-console-links.sh
```

**Likely causes (check in order):**

| Link | Blocker |
|------|---------|
| Developer Hub | Missing `developer-hub-catalog-demos`; TechDocs CM keys with `/`; Backstage still Init |
| Gitea | PostgreSQL/Valkey blocked by SCC — need **`privileged`** (not `anyuid`); Route must target **`gitea-http`** |
| OpenShift AI | RHODS OG must be **AllNamespaces** (`spec: {}`); needs DSCInitialization; **403** without `oc login` |
| Kubecost | Duplicate OG or wrong domain (`example.com`) — OG name **`kubecost-operator-group`** |
| Kairos | Duplicate OperatorGroup in namespace |
| Skupper observer | OCI chart in `default`; missing wrapper Route **passthrough** — use `charts/all/skupper-network-observer` in **`service-interconnect`** |
| Industrial Edge | Spokes not imported or Skupper VAN incomplete; or missing hub-gateway Service until Istio/mesh ready |

**Action:** Wait 60–90 min; fix specific blocker per `install-improvements.md`; re-run with `MIN_OK_CODE=200`. Target: **19 OK, 0 503**.

---

### 0b. East/west namespaces Terminating / recreating

**Symptom:** `oc get ns east` shows **Terminating** repeatedly.

**Causes:**

1. Spoke API tokens in auto-syncing `field-content` / `acm-hub-spoke` while ACM import fails
2. **Pre-created `Namespace`** with `cluster.open-cluster-management.io/managedCluster` label **before** `ManagedCluster` CR exists

**Fix:** Remove tokens from GitOps values; import with **`ManagedCluster` first** (chart `acm-hub-spoke` fixed order); use `fleet-values-sync` for **domains only**:

```bash
oc create job --from=cronjob/fleet-values-sync fleet-values-sync-manual -n openshift-gitops
```

---

### 0c. ACM operator stuck (no MCH Running)

**Symptom:** `acm-operator` app retries; `multiclusterhub` CRD missing.

**Fix:**

```bash
helm template acm charts/all/acm-operator | oc apply -f -
```

Wait for MCH **Running** before spoke import.

---

### 0d. RHODS / observability CSV — OperatorGroup issues

**Symptom:** `csv created in namespace with multiple operatorgroups` or `UnsupportedOperatorGroup` in `redhat-ods-operator`.

**Fix:** Remove `operatorGroup: true` from hub values for namespaces that already get OG from subscriptions. RHODS OG must be **AllNamespaces** (`spec: {}`), not `targetNamespaces: [redhat-ods-operator]`. Chart includes DSCInitialization + DataScienceCluster `RawDeployment`.

---

### 1. MCE cluster-proxy-addon (ACM 2.16+)

**Default:** MCE enables `cluster-proxy-addon` (apiserver-network-proxy for managed clusters).

**Git automation:** `charts/all/acm-operator` PostSync Job + CronJob `acm-mce-disable-cluster-proxy` patches `MultiClusterEngine/multiclusterengine` to set `cluster-proxy-addon.enabled: false`.

```bash
oc get mce multiclusterengine -o jsonpath='{range .spec.overrides.components[*]}{.name}={.enabled}{"\n"}{end}' | grep cluster-proxy
oc get cronjob acm-mce-disable-cluster-proxy -n open-cluster-management
```

**Limitation:** `ocm-proxyserver` in `multicluster-engine` may persist — not controlled by this add-on flag.

**Opt out:** `mceDisableClusterProxyAddon: false` in acm-operator values.

---

### 2. ArgoCD "Unknown" / ComparisonError (ACM 2.16)

**Symptom:** All or most Argo CD apps show **Unknown** sync; UI may still show some **Healthy**.

**Error:**

```
SchemaError(github.com/stolostron/cluster-lifecycle-api/clusterview/v1alpha1.UserPermission.status)
```

**Cause:** ACM 2.16 CRDs break Argo CD OpenAPI schema loading during cluster cache sync.

**New installations (Git fix):** `charts/all/openshift-gitops/templates/argocd.yaml` includes:

- `resourceExclusions` for `clusterview.open-cluster-management.io` and `internal.open-cluster-management.io`
- Controller memory limits (8Gi)

**Existing hub (important):** Manual patch + controller restart often **does not** recover sync if the hub was installed before the fix. Attempted without success: force sync all apps, delete APIServices, flush Redis, disable `cluster-proxy-addon`, delete `ocm-proxyserver`, invalidate APIServices during sync.

**Recovery options for blocked hub:**

1. Reinstall hub with current `main` (declarative exclusions from chart)
2. Wait for ACM/ArgoCD version with fix
3. Emergency: `helm template | oc apply` for critical charts (bypasses Argo sync — local `helm install/upgrade` may also fail with clusterview schema error after ACM)

**Do not assume Unknown is cosmetic** — verify Routes and pods for target apps exist.

**Manual workaround (try first on existing hub):**

```bash
oc patch argocd openshift-gitops -n openshift-gitops --type merge -p '{
  "spec": {
    "resourceExclusions": "- apiGroups:\n  - clusterview.open-cluster-management.io\n  kinds:\n  - \"*\"\n  clusters:\n  - \"*\"\n- apiGroups:\n  - internal.open-cluster-management.io\n  kinds:\n  - \"*\"\n  clusters:\n  - \"*\"\n"
  }
}'
oc rollout restart statefulset openshift-gitops-application-controller -n openshift-gitops
oc rollout status statefulset openshift-gitops-application-controller -n openshift-gitops
```

Docs: `docs/validatedpatterns-docs/troubleshooting.md#argocd-unknown-sync-status-acm-216`

---

### 3. Console Links — wrong hostname (404 / 503 "host doesn't exist")

**Symptom:** Console menu link fails; `curl` returns 503 with "The host doesn't exist"; Route list has different hostname.

| Link | Wrong (legacy) | Correct |
|------|----------------|---------|
| Skupper Network Observer | `field-content-skupper-network-observer-service-interconnect.<domain>` | `skupper-network-observer-service-interconnect.<domain>` |
| NeuroFace | ConsoleLink `neuroface.<domain>` but Route `neuroface-neuroface.<domain>` | Set clustergroup override `neuroface.route.host=neuroface.{{ $.Values.global.localClusterDomain }}` |

**Diagnose:**

```bash
bash scripts/verify-console-links.sh
oc get consolelink platform-skupper-console -o jsonpath='{.spec.href}{"\n"}'
oc get routes -n service-interconnect
oc get routes -n neuroface
```

**Fix:** Sync `console-links` and `neuroface` apps after Git update.

---

### 3b. Vault console link returns 307

**Symptom:** `verify-console-links.sh` fails on vault; curl to root returns redirect.

**Fix:** ConsoleLink href should use `https://vault.<domain>/ui/` — patch post-install or fix in `console-links` chart values.

---

### 3c. Gitea 503 — SCC denied or wrong Route

**Symptom:** Gitea postgres/valkey pods fail; Gitea console link 503.

**Fix:** Use **`privileged` SCC** — `charts/all/gitea/templates/clusterrolebinding-gitea-privileged.yaml` (not `anyuid`; upstream seccomp annotations reject anyuid). Route must target Service **`gitea-http`**, not `field-content-gitea-chart-http`.

```bash
oc get pods -n gitea
oc get route -n gitea -o jsonpath='{.items[0].spec.to.name}{"\n"}'
oc adm policy who-can use scc privileged -n gitea
```

---

### 3e. OpenShift AI 403 in verify script

**Symptom:** `platform-openshift-ai` returns 403; other links OK.

**Fix:** Run `oc login` on hub before `verify-console-links.sh` — script sends `Authorization: Bearer $(oc whoami -t)`. Exclude duplicate operator `rhodslink` from count (script filters automatically).

---

### 3f. Skupper observer 503 — wrong namespace or TLS

**Symptom:** Skupper console link 503; observer in `default` or Route uses edge TLS instead of passthrough.

**Fix:** Deploy wrapper `charts/all/skupper-network-observer` to **`service-interconnect`**. Route spec: `tls.termination: passthrough`, `port.targetPort: https`. Requires Skupper Site + TLS secrets on hub.

---

### 3d. Developer Hub stuck Init / 503

**Symptom:** Backstage pod `Init:2/3`; Developer Hub link 503.

**Checks:**

```bash
oc get configmap developer-hub-catalog-demos -n developer-hub
oc get pods -n developer-hub
oc logs -n developer-hub deploy/developer-hub -c backstage --tail=30
```

**Fixes:**

- Ensure `workshop-demos` chart synced (provides `developer-hub-catalog-demos`)
- TechDocs ConfigMap keys must not contain `/` (use flat keys like `index.md` not `docs/index.md`)
- Separate volume mounts: IE catalog at `.../ie`, techdocs at `.../ie/techdocs`

---

### 4. Console Links — placeholder domain

**Symptom:** All links point to example.com domain.

**Cause:** `global.localClusterDomain` / `deployer.domain` not injected.

**Fix:**

```bash
# RHDP: verify field-content helm.values has deployer.domain
# Spokes: verify clusters.hub.domain (fleet-values-sync or manual patch)
oc annotate application console-links -n openshift-gitops argocd.argoproj.io/refresh=hard --overwrite
```

See `docs/validatedpatterns-docs/rhdp-field-content.md`.

---

### 5. ACM TooManyOperatorGroups

```bash
oc get operatorgroup -n open-cluster-management
oc delete operatorgroup <duplicate-name> -n open-cluster-management
```

---

### 6. Spoke Not Joining ACM

```bash
oc get managedclusters
oc get pods -n open-cluster-management-agent   # on spoke
oc get secret auto-import-secret -n <cluster-name> -o yaml   # on hub
```

---

### 7. ApplicationSet "both name and server defined"

Delete/recreate ApplicationSet or ensure template uses `destination.name` only (not `server` + `name`).

```bash
oc get applicationset fleet-spoke-push -n openshift-gitops -o yaml
```

---

### 8. Kafka Console `/api/kafkas` 404

External route hits UI only. Enable `apiRoute` in `charts/all/kafka-console`.

```bash
curl -sk -o /dev/null -w '%{http_code}\n' https://kafka-console.<hub-domain>/api/kafkas
```

---

### 9. Skupper AccessToken CA mismatch

Grant server uses `SkupperGrantServerCA`, not Ingress CA:

```bash
oc get secret skupper-grant-server-ca -n openshift-operators \
  -o jsonpath='{.data.ca\.crt}' | base64 -d
```

---

### 10. ACS Central unreachable after ambient mesh

Do **not** label `stackrox` namespace ambient — breaks Central ↔ PostgreSQL TLS.

---

### 11. ArgoCD Controller OOMKilled

Chart sets 8Gi limit; patch if needed:

```bash
oc patch argocd openshift-gitops -n openshift-gitops --type merge -p '{
  "spec": {"controller": {"resources": {"limits": {"memory": "8Gi"}, "requests": {"memory": "4Gi"}}}}
}'
```

---

### 12. Kuadrant AuthPolicy Not Accepted (MissingDependency)

**Symptom:** RHCL console or `oc get authpolicy` shows **Not Accepted** / `MissingDependency` — gateway provider not installed.

**Checks:**

```bash
oc get gatewayclass istio -o jsonpath='controller={.spec.controllerName} accepted={.status.conditions[?(@.type=="Accepted")].status}{"\n"}'
oc get deployment kuadrant-operator-controller-manager -n redhat-connectivity-link-operator \
  -o jsonpath='ISTIO_GATEWAY_CONTROLLER_NAMES={.spec.template.spec.containers[0].env[?(@.name=="ISTIO_GATEWAY_CONTROLLER_NAMES")].value}{"\n"}'
oc get kuadrant kuadrant -n kuadrant-system -o jsonpath='Ready={.status.conditions[?(@.type=="Ready")].status}{"\n"}'
```

**Fix:**

1. Sync `rhcl-operator` (subscription sets `istio.io/gateway-controller,openshift.io/gateway-controller/v1`)
2. Restart operator after mesh ready: `bash scripts/apply-workshop-kuadrant-apis.sh` or delete kuadrant operator pod
3. Verify AuthPolicy **Enforced=True**; curl httpbin returns **401** without key, **200** with `Authorization: APIKEY …`

**Developer Hub:** `/kuadrant` empty → sync `developer-hub` (ClusterRole `developer-hub-kuadrant`).

Docs: `docs/validatedpatterns-docs/products/connectivity-link.md`

---

## Diagnostic Commands

```bash
# Bootstrap chain
oc get application field-content hybrid-mesh-platform-hub -n openshift-gitops
oc get application acm-hub-spoke -n openshift-gitops
oc get applicationset fleet-spoke-push -n openshift-gitops

# Console + routes
oc login --token=<token> --server=<hub-api-url>
MIN_OK_CODE=200 bash scripts/verify-console-links.sh
oc get routes -A | wc -l

# ACM
oc get multiclusterhub -n open-cluster-management
oc get managedclusters
oc logs statefulset/openshift-gitops-application-controller -n openshift-gitops --tail=50 | grep -i schema
```

## Escalation

1. Collect `verify-console-links.sh` + `verify-fleet.sh` output + `oc get applications -n openshift-gitops`
2. Check `docs/validatedpatterns-docs/install-improvements.md` then `docs/validatedpatterns-docs/troubleshooting.md`
3. Open GitHub issue with hub/spoke domains and ACM version
