# Validate Deployment Skill

## Product outcomes (validate first)

Before diving into Argo sync status, prove the platform delivers value:

| Outcome | Check |
| ------- | ----- |
| Fleet inventory | `oc get managedclusters` — east/west **Available** |
| One-click access | `MIN_OK_CODE=200 bash scripts/verify-console-links.sh` on hub — **19** links HTTP 200 |
| Workshop + AI surfaces | `bash scripts/verify-workshop-http200.sh` — showroom, MCP, IE, DevSpaces spokes, **workshop-apis (401)**, **vault /ui/** |
| Private mesh | `oc get site hub -n service-interconnect -o jsonpath='sitesInNetwork={.status.sitesInNetwork}{"\n"}'` → **3** |
| Edge ingress | `curl -sk -o /dev/null -w '%{http_code}\n' https://industrial-edge.apps.<hub-domain>/` |
| Fleet GitOps | `oc get applicationset fleet-spoke-push -n openshift-gitops` |

Allow **60–90 min** after hub sync for all console links to reach HTTP 200. RHDP playbook: `docs/validatedpatterns-docs/install-improvements.md`

## Quick Health Check

```bash
oc whoami && oc cluster-info | head -1

echo "Running pods: $(oc get pods -A --field-selector=status.phase=Running --no-headers | wc -l)"
echo "Failed pods: $(oc get pods -A --no-headers | grep -v 'Running\|Completed' | wc -l)"

oc get csv -A | grep -v Succeeded | head -10
oc get applications -n openshift-gitops --no-headers | wc -l
```

## Hub Cluster Validation

### ACM Status

```bash
oc get multiclusterhub -n open-cluster-management -o jsonpath='{.items[0].status.phase}{"\n"}'
oc get managedclusters -o wide
oc get gitopscluster -A
oc get applicationset fleet-spoke-push -n openshift-gitops
oc get placementdecisions -n openshift-gitops -l cluster.open-cluster-management.io/placement=hub-spoke-placement
```

### ArgoCD Applications

```bash
oc get applications -n openshift-gitops

# Unhealthy apps
oc get applications -n openshift-gitops -o jsonpath='{range .items[?(@.status.health.status!="Healthy")]}{.metadata.name}: {.status.health.status}{"\n"}{end}'

# Sync errors (ComparisonError = often ACM 2.16 schema bug)
oc get applications -n openshift-gitops -o jsonpath='{range .items[*]}{.metadata.name}: {.status.conditions[0].message}{"\n"}{end}' | head -20
```

### Console Links (primary smoke test)

**Run from hub** (must be logged in — OpenShift AI needs bearer token):

```bash
oc login --token=<token> --server=<hub-api-url>
MIN_OK_CODE=200 bash scripts/verify-console-links.sh
bash scripts/verify-workshop-http200.sh
bash scripts/verify-fleet.sh
```

**Success criteria:** `Summary: 19 OK (200-399), 0 503 (route exists / pods down), 0 other` — exit code **0**.

Script behavior: uses `oc whoami -t` for OAuth routes; excludes operator duplicate **`rhodslink`** ConsoleLinks.

#### Hub console links (19 expected)

| ConsoleLink | Surface |
| ----------- | ------- |
| `argocd` | Argo CD |
| `platform-acm-clusters` | ACM fleet |
| `platform-acs-central` | ACS Central |
| `platform-developer-hub` | Developer Hub |
| `platform-gitlab` | GitLab SCM |
| `platform-grafana` | Grafana |
| `platform-hybrid-mesh-workshop` | Workshop registration |
| `platform-industrial-edge` | IE hub-gateway |
| `platform-kafka-console` | Kafka Console |
| `platform-kairos-console` | Kairos |
| `platform-kiali` | Kiali |
| `platform-kubecost` | Kubecost |
| `platform-mailpit` | Mailpit |
| `platform-minio` | MinIO |
| `platform-neuroface` | NeuroFace |
| `platform-openshift-ai` | OpenShift AI (OAuth) |
| `platform-quay-registry` | Quay |
| `platform-skupper-console` | Skupper observer |
| `platform-workshop-apis` | Workshop APIs (Kuadrant) — curl needs APIKEY |
| `vault-link` | Vault `/ui/` |

Interpret results:

| HTTP | Meaning |
|------|---------|
| **200–399** | Route + backend OK — product surface reachable |
| **503** | Route exists; pods/operators still syncing (**common first hour**) — or wrong backend |
| **403** | OAuth route without token — run `oc login` first |
| **404 / 000** | Wrong hostname or no Route |

**Known hostname / backend fixes (in Git):**

- Skupper: wrapper `charts/all/skupper-network-observer`; host `skupper-network-observer-service-interconnect.<domain>`; Route **TLS passthrough**; namespace **`service-interconnect`**
- NeuroFace: Route host `neuroface.<domain>` via clustergroup `overrides` on hub `neuroface` app
- Vault: ConsoleLink href **`/ui/`** (root returns 307)
- GitLab: approve Manual InstallPlans; verify `oc get gitlab -n gitlab`; scaffolder uses `GITLAB_TOKEN`
- OpenShift AI: AllNamespaces OG; DSC v2 + RawDeployment; URL `rh-ai.apps.<domain>`; bearer token for curl
- Kubecost: OG **`kubecost-operator-group`**; Route from `global.localClusterDomain`
- Developer Hub: `developer-hub-catalog-demos`; TechDocs CM keys without `/`; mounts `.../ie` vs `.../ie/techdocs`

After Git fix, refresh:

```bash
oc annotate application console-links -n openshift-gitops argocd.argoproj.io/refresh=hard --overwrite
oc annotate application neuroface -n openshift-gitops argocd.argoproj.io/refresh=hard --overwrite
```

### Key CRs

```bash
oc get backstage -n developer-hub 2>/dev/null
oc get kiali -A 2>/dev/null
oc get central -n stackrox 2>/dev/null
oc get site -n service-interconnect 2>/dev/null
oc get console.streamshub.github.com -n kafka-console 2>/dev/null
```

## Spoke Cluster Validation

```bash
oc get application hybrid-mesh-platform-east -n openshift-gitops   # or -west
oc get pods -n industrial-edge-tst-all
oc get site -n service-interconnect
oc get pods -n open-cluster-management-agent
```

## Component Validation Matrix

| Component | Hub | Spoke | Check |
|-----------|-----|-------|-------|
| Clustergroup root | ✓ | ✓ | `oc get application hybrid-mesh-platform-{hub,east,west}` |
| ACM / fleet | ✓ | - | `oc get managedclusters` |
| ApplicationSet PUSH | ✓ | - | `oc get applicationset fleet-spoke-push` |
| Skupper VAN | ✓ | ✓ | `oc get site,link -n service-interconnect` |
| Industrial Edge | - | ✓ | `oc get pods -n industrial-edge-tst-all` |
| fleet-values-sync | ✓ | ✓ | `oc get cronjob -n openshift-gitops \| grep fleet-values` |

## ArgoCD Sync Status

| Status | Meaning |
|--------|---------|
| Synced | Resources match Git |
| Unknown | Often ACM 2.16 schema bug — **may block real sync on existing hubs** |
| Healthy | Resource health OK (can coexist with Unknown sync) |
| ComparisonError | Schema load failure — apps won't sync until fixed |

```bash
# Distinguish cosmetic vs blocked
oc get application acm-hub-spoke -n openshift-gitops \
  -o jsonpath='sync={.status.sync.status} health={.status.health.status} op={.status.operationState.phase}{"\n"}'
oc get routes -n developer-hub 2>/dev/null   # empty = sync never applied chart
```

## Post-install day-2 (GitOps PostSync Jobs)

Argo app **`hub-post-install-bootstrap`** (sync wave 9) runs phased Jobs in `openshift-gitops`. Facilitator secrets:

```bash
oc create secret generic acs-init-credentials -n stackrox --from-literal=ROX_ADMIN_PASSWORD='...'
oc create secret generic maas-facilitator-seed -n vault \
  --from-literal=api-key='sk-...' \
  --from-literal=granite-api-key='sk-...' \
  --from-literal=deepseek-api-key='sk-...'
oc annotate application hub-post-install-bootstrap -n openshift-gitops argocd.argoproj.io/refresh=hard --overwrite
```

See `install-improvements.md#post-install-day-2-gitops-postsync-jobs`.

### Showroom content + heroes

After hub HTTP 200 gate passes:

```bash
SHOWROOM_DIR=../showroom-hybrid-mesh-ai bash scripts/sync-showroom-content.sh
# push showroom repo, then:
oc rollout restart deployment/showroom -n showroom
curl -sk -o /dev/null -w '%{http_code}\n' "https://showroom-showroom.apps.${HUB_DOMAIN}/"
```

Spot-check module heroes in Showroom UI (live captures, not placeholders): **13** Realtime Data, **20** ACS unchanged, **26** Mailpit, **29** Argo CD (facilitator). Guide: `docs/validatedpatterns-docs/workshop/index.md`.

### MaaS secrets and AI chat gates

After hub sync, inject keys (never commit `sk-*` to Git):

```bash
oc create secret generic maas-facilitator-seed -n vault \
  --from-literal=api-key='sk-...' \
  --from-literal=granite-api-key='sk-...' \
  --from-literal=deepseek-api-key='sk-...'
oc annotate application vault-maas-external-secrets -n openshift-gitops argocd.argoproj.io/refresh=hard --overwrite
```

Verify ESO + Vault path:

```bash
oc get clustersecretstore vault-workshop-maas -o jsonpath='{.status.conditions[0].status}{"\n"}'   # True
oc get netpol allow-vault-maas-egress-8200 -n external-secrets
oc get externalsecret -A
```

Verify:

```bash
# NeuroFace chat — expect 200 (401 = placeholder secret)
curl -sk -X POST "https://neuroface.${HUB_DOMAIN}/api/chat" \
  -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"Hello"}]}' | head -c 200

# Kuadrant gateway — 401 without API key is OK (route protected)
curl -sk -o /dev/null -w '%{http_code}\n' "https://workshop-apis.${HUB_DOMAIN}/httpbin/get"

# Vault UI — use /ui/ not root
curl -sk -o /dev/null -w '%{http_code}\n' "https://vault-vault.${HUB_DOMAIN}/ui/"

# Lightspeed route
curl -sk -o /dev/null -w '%{http_code}\n' "https://developer-hub.${HUB_DOMAIN}/lightspeed"
```

Developer Hub Kuadrant keys: log in as `userN` → `/kuadrant` → **My API Keys** → `Authorization: APIKEY <key>`.

### Kuadrant policy enforcement

After `workshop-kuadrant-apis` and mesh sync:

```bash
oc get kuadrant kuadrant -n kuadrant-system -o jsonpath='Ready={.status.conditions[?(@.type=="Ready")].status}{"\n"}'
oc get authpolicy -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,ACCEPTED:.status.conditions[?(@.type=="Accepted")].status,ENFORCED:.status.conditions[?(@.type=="Enforced")].status'
oc get deployment kuadrant-operator-controller-manager -n redhat-connectivity-link-operator \
  -o jsonpath='ISTIO_GATEWAY_CONTROLLER_NAMES={.spec.template.spec.containers[0].env[?(@.name=="ISTIO_GATEWAY_CONTROLLER_NAMES")].value}{"\n"}'
```

Expect **Ready=True**, all AuthPolicies **Enforced=True**, controller names include `istio.io/gateway-controller`. If **Not Accepted**, refresh `hub-post-install-bootstrap` or restart kuadrant operator pod.

## Offline validation

```bash
bash scripts/argocd-preflight.sh
python scripts/verify-gitops-strategies.py
bash scripts/verify-workshop-e2e.sh
```

## Reference

- **RHDP playbook:** `docs/validatedpatterns-docs/install-improvements.md`
- Full guide: `docs/validation-guide.md`
- Troubleshooting: `docs/validatedpatterns-docs/troubleshooting.md`
