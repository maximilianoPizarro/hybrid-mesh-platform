---
title: Cnv
weight: 19
---

# OpenShift Virtualization (CNV)

**Git path:** `charts/all/cnv-example/`
{: .fs-3 .text-grey-dk-000 }

Red Hat **OpenShift Virtualization** (KubeVirt) runs virtual machines alongside containers. This platform ships a workshop example VM and a Developer Hub software template for hands-on CNV labs.

## What ships

| Resource | Purpose |
| -------- | ------- |
| KubeVirt / CNV operator | OLM subscription on hub |
| Example VM `workshop-cnv-demo` | Cirros-based demo in `cnv-example` namespace |
| Software template **CNV VM Workshop** | Scaffolds VM manifests into user Gitea org |

The example VM uses cloud-init with user `cirros` for console login (see [`charts/all/cnv-example/templates/all.yaml`](https://github.com/maximilianoPizarro/hybrid-mesh-platform/tree/main/charts/all/cnv-example/templates/all.yaml)).

## Software template

**CNV VM Workshop** (`docs/assets/backstage/software-templates/cnv-vm-workshop/`) publishes VM YAML to Gitea and registers a catalog Component. Users deploy via Argo CD or `oc apply` from their repo.

## Operator discovery

CNV workloads surface in Developer Hub when catalog entities include:

```yaml
annotations:
  backstage.io/kubernetes-id: <vm-name>
  backstage.io/kubernetes-namespace: <namespace>
  backstage.io/kubernetes-cluster: hub
```

KubeVirt CRs (`VirtualMachine`, `DataVolume`) are reconciled by the CNV operator — no namespace mesh or ACM placement labels required.

## Verify

```bash
oc get kubevirt -n openshift-cnv
oc get vm -n cnv-example
virtctl console workshop-cnv-demo -n cnv-example
```

## Documentation

- [Red Hat OpenShift Virtualization](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/virtualization/)

**Next:** [Developer Hub](developer-hub.md) → Create → CNV VM Workshop template.
