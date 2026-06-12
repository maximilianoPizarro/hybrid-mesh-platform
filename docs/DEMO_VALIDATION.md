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
| APIProduct (workshop) | workshop-httpbin, workshop-llm-tokens, workshop-restcountries |

## Pattern install

Full `./pattern.sh install` requires Podman (utility container). On Windows without Podman machine admin rights, run install from a Linux bastion or demo.redhat.com provisioning flow.

## Post-VP install checklist

After installing from `hybrid-mesh-platform`:

1. Hub clustergroup Application **Synced**
2. East/west clustergroup Applications on spokes **Synced** (ACM pull)
3. IE `line-dashboard` reachable on each spoke
4. Hub gateway + RHCL APIProduct cross-cluster
5. ACS Central shows hub + east + west

See [MIGRATION.md](../MIGRATION.md) for architecture differences.
