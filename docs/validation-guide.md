---
title: Validation Guide
nav_order: 11
layout: default
---

# Pattern Validation Guide

This guide describes how to validate the Hybrid Mesh Platform pattern is working correctly — **from the user's perspective**, not only from Argo CD sync status. A healthy GitOps tree should unlock fleet observability, security, developer experience, and edge ingress.

For RHDP-specific install order, token handling, and first-hour 503s, see the [RHDP install playbook](validatedpatterns-docs/install-improvements.md).

When validation fails, start with [Verification scripts](validatedpatterns-docs/troubleshooting.md#verification-scripts--what-to-run-when-something-fails) in the troubleshooting guide.

## Product outcomes (what to prove)

| Outcome | Validation |
| ------- | ---------- |
| Fleet inventory | `oc get managedclusters` — east/west **Available** |
| One-click platform access | `MIN_OK_CODE=200 bash scripts/verify-console-links.sh` on hub — **20** links HTTP 200 (see [checklist](#hub-console-links-20-expected)) |
| Workshop + AI surfaces | `bash scripts/verify-workshop-http200.sh` — **20** surfaces (incl. DevSpaces, IE line-dashboard, AI gateway) |
| Kuadrant protection | `bash scripts/verify-workshop-kuadrant-curl.sh` — `workshop-apis` and `ai-gateway` return **401** without API key |
| Private hub↔spoke mesh | `bash scripts/verify-industrial-edge.sh` — Skupper `sitesInNetwork: 3`, hub IE route 200 |
| Fleet GitOps | `bash scripts/verify-fleet.sh` — east/west **Available** |
| VP Interop Tests | `make qe-tests` → `tests/interop/run_tests.sh` — subscription, pod health, HTTP surfaces |

Allow **60–90 minutes** after hub sync for all console links to converge; **503** usually means the route exists but backends are still starting (see playbook).

## Quick Validation Checklist

After deployment, verify these core components are operational:

### 1. Hub Cluster Validation

```bash
# Login to hub cluster
oc login --token=<token> --server=<api-url>

# Verify GitOps bootstrap
oc get application field-content -n openshift-gitops
# Expected: Synced, Healthy

# Verify clustergroup application
oc get application hybrid-mesh-platform-hub -n openshift-gitops
# Expected: Synced or OutOfSync, Healthy

# Verify ACM is running
oc get multiclusterhub -n open-cluster-management
# Expected: STATUS=Running

# Verify managed clusters
oc get managedclusters
# Expected: All clusters show JOINED=True, AVAILABLE=True

# Verify ArgoCD applications
oc get applications -n openshift-gitops --no-headers | wc -l
# Expected: 40+ applications
```

### 2. Spoke Cluster Validation

```bash
# Login to spoke cluster (east or west)
oc login --token=<token> --server=<api-url>

# Verify GitOps bootstrap
oc get application field-content -n openshift-gitops
# Expected: Synced, Healthy

# Verify clustergroup application
oc get application hybrid-mesh-platform-east -n openshift-gitops  # or -west
# Expected: Synced or OutOfSync, Healthy

# Verify spoke is connected to hub
oc get pods -n open-cluster-management-agent
# Expected: klusterlet pods Running
```

### 3. Multi-Cluster Connectivity

```bash
# On hub: Verify Skupper network
oc get pods -n service-interconnect
# Expected: skupper-router, network-observer Running

# Verify GitOpsCluster for ArgoCD
oc get gitopscluster -n openshift-gitops
# Expected: hub-spoke-gitops with status Ready
```

## Component Validation Matrix

| Component | Hub | East | West | Validation Command |
|-----------|-----|------|------|-------------------|
| OpenShift GitOps | ✅ | ✅ | ✅ | `oc get argocd -n openshift-gitops` |
| ACM (MCH) | ✅ | - | - | `oc get mch -n open-cluster-management` |
| ACS Central | ✅ | - | - | `oc get central -n stackrox` |
| ACS SecuredCluster | - | ✅ | ✅ | `oc get securedcluster -n stackrox` |
| Developer Hub | ✅ | - | - | `oc get backstage -n developer-hub` |
| Skupper Router | ✅ | ✅ | ✅ | `oc get pods -n service-interconnect` |
| RHCL Gateway | ✅ | ✅ | ✅ | `oc get gateway -n *-gateway-system` |
| Observability | ✅ | ✅ | ✅ | `oc get uiplugin -n openshift-cluster-observability-operator` |

## Standalone Demo Application

The pattern includes a minimal standalone demo that works without external dependencies:

### Industrial Edge Test Application

Located in `charts/all/industrial-edge-tst/`, this provides:
- Kafka producer/consumer test
- S3-compatible storage (MinIO)
- Basic ML inference pipeline

**Validation:**
```bash
# Verify Industrial Edge components
oc get pods -n industrial-edge-tst-all
oc get pods -n industrial-edge-ml-workspace

# Check Kafka topics
oc get kafkatopics -n industrial-edge-stormshift-messaging
```

### Console Links Verification (primary smoke test)

The pattern creates Console Links so operators reach GitOps, observability, security, and developer surfaces from the OpenShift console menu — the main **day-one product check** on the hub.

```bash
# Log in on the hub — OpenShift AI dashboard requires a bearer token (403 without it)
oc login --token=<token> --server=<hub-api-url>

# List all platform links
oc get consolelink -o custom-columns='NAME:.metadata.name,URL:.spec.href'

# HTTP reachability (200–399 = OK; 503 = route up, backend still syncing)
MIN_OK_CODE=200 bash scripts/verify-console-links.sh
```

Expected summary on a fully synced hub: **`20 OK (200-399), 0 503, 0 other`**, exit code **0**.

The script skips operator-created duplicate **`rhodslink`** ConsoleLinks and sends `Authorization: Bearer` when `oc whoami -t` succeeds.

#### Hub console links (20 expected)

| ConsoleLink name | Product surface |
| ---------------- | --------------- |
| `argocd` | OpenShift GitOps (Argo CD) |
| `platform-acm-clusters` | ACM fleet inventory |
| `platform-acs-central` | ACS Central |
| `platform-developer-hub` | Developer Hub (Backstage) |
| `platform-gitlab` | GitLab SCM |
| `platform-grafana` | Fleet Grafana |
| `platform-hybrid-mesh-workshop` | Workshop registration |
| `platform-industrial-edge` | Industrial Edge hub-gateway ingress |
| `platform-kafka-console` | Kafka Console (multi-cluster) |
| `platform-kairos-console` | Kairos AI console |
| `platform-kiali` | Kiali (mesh / observability) |
| `platform-kubecost` | Kubecost |
| `platform-mailpit` | Mailpit (workshop email) |
| `platform-minio` | MinIO console (IE ML workspace) |
| `platform-neuroface` | NeuroFace demo |
| `platform-neuroface-cv` | NeuroFace CV gateway |
| `platform-openshift-ai` | OpenShift AI dashboard (OAuth) |
| `platform-quay-registry` | Quay registry |
| `platform-skupper-console` | Skupper network observer |
| `vault-link` | Vault UI (`/ui/` — avoids 307 on route root) |

Cross-check ConsoleLink hostnames against cluster Routes:

```bash
oc get routes -A -o custom-columns='NS:.metadata.namespace,HOST:.spec.host' | grep -E 'grafana|developer-hub|kafka-console|neuroface|skupper|central-stackrox'
```

Strict CI gate (fail on 503): `MIN_OK_CODE=200 bash scripts/verify-console-links.sh`

## Automated Validation Script

Run the included validation script:

```bash
# From pattern root directory
./scripts/verify-fleet.sh

# Or for GitOps strategy validation
python scripts/verify-gitops-strategies.py
```

## Health Check Endpoints

### Hub Services

| Service | URL Pattern | Expected |
|---------|-------------|----------|
| ArgoCD | `https://openshift-gitops-server-openshift-gitops.<domain>` | Login page |
| Grafana | `https://grafana.<domain>` | Dashboard |
| Developer Hub | `https://developer-hub.<domain>` | Backstage UI |
| ACS Central | `https://central-stackrox.<domain>` | ACS dashboard |

### Spoke Services

| Service | URL Pattern | Expected |
|---------|-------------|----------|
| ArgoCD | `https://openshift-gitops-server-openshift-gitops.<domain>` | Login page |
| Grafana | `https://grafana.<domain>` | Dashboard |
| Kiali | `https://kiali-openshift-cluster-observability-operator.<domain>` | Service mesh UI |

## Troubleshooting

See the full [Troubleshooting guide](validatedpatterns-docs/troubleshooting.md) and [RHDP install playbook](validatedpatterns-docs/install-improvements.md) for production lessons (ACM 2.16, tokens, GitLab SCC, Developer Hub catalog).

### Common Issues

1. **Applications stuck in "Unknown" sync status**
   - Cause: ArgoCD schema cache issue with ACM CRDs
   - Fix: Restart ArgoCD application controller
   ```bash
   oc delete pod -n openshift-gitops -l app.kubernetes.io/name=openshift-gitops-application-controller
   ```

2. **Spoke not joining hub**
   - Verify klusterlet pods are running
   - Check hub-kubeconfig-secret points to correct hub API
   ```bash
   oc get secret hub-kubeconfig-secret -n open-cluster-management-agent -o jsonpath='{.data.kubeconfig}' | base64 -d | grep server:
   ```

3. **Console links showing wrong domain**
   - Verify global.localClusterDomain is set correctly
   - Refresh the console-links application

### Validation Without Showroom

The Workshop Showroom (`showroom-hybrid-mesh-ai`) is optional but recommended for RHDP labs. Maintainer guide: [Workshop docs](validatedpatterns-docs/workshop/index.md).

Without it:

1. **Skip these applications:**
   - `showroom`
   - `workshop-registration`
   - `workshop-demos` (partial)

2. **Core functionality remains:**
   - Multi-cluster GitOps (ACM + ArgoCD)
   - Service mesh (Skupper + RHCL)
   - Security (ACS)
   - Observability (Grafana + Tempo + OTel)
   - Industrial Edge pipelines

3. **Validate via CLI** instead of workshop UI using commands above

## Next Steps

After validation:
1. Review [Architecture Documentation](./architecture.md)
2. Explore [Bill of Materials](./bill-of-materials.md) for component versions
3. Check [Support Policy](../SUPPORT.md) for getting help
