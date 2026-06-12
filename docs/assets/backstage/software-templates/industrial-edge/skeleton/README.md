---
nav_exclude: true
search_exclude: true
---

# Industrial Edge — ${{ values.name }} (${{ values.targetCluster }})

IoT edge instance scaffolded from Developer Hub.

## Cluster

- **Target spoke:** `${{ values.targetCluster }}`
- **Namespace:** `${{ values.namespace }}`
- **Image (deploy):** `image-registry.openshift-image-registry.svc:5000/${{ values.namespace }}/${{ values.uniqueName }}:latest`
- **Quay (public catalog):** `quay.io/maximilianopizarro/${{ values.uniqueName }}`

## Components

- Namespace under OSSM3 ambient mesh (ztunnel L4 metrics, Prometheus `istio_tcp_*` series)
- Tekton pipeline (git-clone → buildah → internal registry)
- Deployment + Service

## Links

- [Gitea repo](https://gitea-gitea.${{ values.clusterDomain }}/ws-${{ values.owner }}/${{ values.name }}-${{ values.targetCluster }})
- [Open in DevSpaces](https://devspaces.${{ values.spokeAppsDomain }}/#https://gitea-gitea.${{ values.clusterDomain }}/ws-${{ values.owner }}/${{ values.name }}-${{ values.targetCluster }}-${{ values.environment }})
