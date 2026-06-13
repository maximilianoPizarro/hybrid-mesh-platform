---
title: Validation Guide
nav_order: 11
layout: default
---

# Pattern Validation Guide

This guide describes how to validate the Hybrid Mesh Platform pattern is working correctly, with or without the optional Showroom workshop components.

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

### Console Links Verification

The pattern creates Console Links for easy access:

```bash
# List all platform links
oc get consolelink -o custom-columns='NAME:.metadata.name,URL:.spec.href'
```

Expected links include:
- `argocd` - Cluster ArgoCD
- `platform-grafana` - Grafana dashboards
- `platform-kiali` - Service mesh visualization
- `platform-developer-hub` - Developer portal (hub only)

Verify HTTP reachability (accepts 200–399; reports 503 when route exists but pods are down):

```bash
bash scripts/verify-console-links.sh
```

Cross-check ConsoleLink hostnames against cluster Routes:

```bash
oc get consolelink -o custom-columns='NAME:.metadata.name,URL:.spec.href'
oc get routes -A -o custom-columns='NS:.metadata.namespace,HOST:.spec.host' | grep -E 'grafana|developer-hub|kafka-console|neuroface|skupper'
```

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

The Workshop Showroom (`showroom-hybrid-mesh-ai`) is optional. Without it:

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
