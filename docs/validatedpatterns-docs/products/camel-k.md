---
title: Camel K
weight: 18
---

# Apache Camel (Camel K)

The Red Hat build of **Apache Camel K** runs lightweight integration code as Kubernetes resources, ideal for **MQTT-to-Kafka** bridging and **Kafka-to-object storage** (for example S3-compatible **MinIO**) pipelines.

## Patterns here

| Flow | Description |
| ---- | ----------- |
| **MQTT → Kafka** | Normalize factory telemetry into Kafka topics with schema discipline. |
| **Kafka → S3** | Archive cold paths or feed batch analytics without blocking real-time dashboards. |

Camel K is typically installed via Operator Lifecycle Manager subscription; see `connectivityLink.operators.subscriptions` for channel pinning.

## Operator discovery

**Camel K operator** watches **`IntegrationPlatform`** (cluster or namespace scope), **`Integration`**, **`KameletBinding`**, **`Pipe`**, … CRDs installed via subscription (`charts/all/camel-k`). Namespaces gain Camel runtime capabilities once **`IntegrationPlatform`** references point there — applications declare integrations via CRDs rather than Pod annotations.

## Links

- [Red Hat build of Apache Camel K](https://developers.redhat.com/products/red-hat-build-of-apache-camel/overview)
- [Apache Camel K documentation](https://camel.apache.org/camel-k/next/)
