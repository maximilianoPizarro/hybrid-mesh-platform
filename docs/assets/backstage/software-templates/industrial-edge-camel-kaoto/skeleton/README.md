---
nav_exclude: true
search_exclude: true
---

# Camel Kaoto — ${{ values.name }} (${{ values.targetCluster }})

Camel Quarkus routes with Kaoto and Continue AI in DevSpaces.

## Integration endpoints

| Setting | Value |
|---------|-------|
| MQTT | `${{ values.mqttBrokerUri }}` |
| Kafka | `${{ values.kafkaBrokerUri }}` |
| MinIO S3 | `${{ values.s3Endpoint }}` / `${{ values.s3Bucket }}` |
| Mailpit | `${{ values.mailpitApiUrl }}` |

## Image

- **Deploy:** internal registry `image-registry.openshift-image-registry.svc:5000/${{ values.namespace }}/${{ values.uniqueName }}:latest`
- **Quay (public):** `quay.io/maximilianopizarro/${{ values.uniqueName }}`

## Links

- [Gitea repo](https://gitea-gitea.${{ values.clusterDomain }}/ws-${{ values.owner }}/${{ values.name }}-${{ values.targetCluster }})
- [Open in DevSpaces (Kaoto)](https://devspaces.${{ values.spokeAppsDomain }}/#https://gitea-gitea.${{ values.clusterDomain }}/ws-${{ values.owner }}/${{ values.name }}-${{ values.targetCluster }}-${{ values.environment }})
