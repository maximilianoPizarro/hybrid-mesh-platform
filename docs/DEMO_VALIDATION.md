# Demo validation (cluster-r7964)

Recorded against the live RHDP hub-spoke fleet while the workshop still runs the legacy App-of-Apps deployment. Use this as a baseline before cutover to `./pattern.sh install` from this repo.

## Fleet (hub — cluster-r7964)

```bash
./scripts/verify-fleet.sh
```

| Check | Result |
|-------|--------|
| `oc get managedcluster` east/west | **Available** |
| Skupper hub site | **Ready**, 3 sites in network |
| RHCL operator | **Installed** (stable channel) |
| APIProduct (workshop) | workshop-httpbin, workshop-llm-tokens, workshop-restcountries (via countriesnow.space) |

## Pattern install

Full `./pattern.sh install` requires Podman (utility container). On Windows without Podman machine admin rights, run install from a Linux bastion or demo.redhat.com provisioning flow.

## NeuroFace CV

```bash
curl -sk "https://neuroface-cv.<hub-domain>/api/ppe/status"
oc get httproute -n neuroface-gateway-system
oc get listener -n service-interconnect | grep neuroface-cv
```

## Post-VP install checklist

After installing from `hybrid-mesh-platform`:

1. Hub clustergroup Application **Synced**
2. ApplicationSet `fleet-spoke-push` present; `east-spoke-components` / `west-spoke-components` **Synced**
3. East/west clustergroup (PULL) **Synced** on spokes
4. `operators-ci-*` (PUSH) and `industrial-edge-*` (PULL) visible in spoke Argo CD by AppProject
5. IE `line-dashboard` reachable on each spoke

```bash
python scripts/verify-gitops-strategies.py
bash scripts/argocd-preflight.sh
./scripts/verify-fleet.sh
```
