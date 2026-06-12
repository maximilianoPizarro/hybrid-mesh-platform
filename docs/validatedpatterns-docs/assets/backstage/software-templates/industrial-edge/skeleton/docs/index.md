# ${{ values.name }}

Industrial Edge IoT instance on spoke **${{ values.targetCluster }}** (environment: `${{ values.environment }}`).

## Namespace

`${{ values.namespace }}`

## Components

- Machine sensors (MQTT)
- Kafka streaming
- Line dashboard deployment
- Tekton CI pipeline

See the Gitea repository README for build and deploy details.
