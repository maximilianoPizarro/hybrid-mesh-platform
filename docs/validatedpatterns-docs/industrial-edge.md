---
title: Industrial Edge
weight: 10
---

# Industrial Edge

The **Industrial Edge** pattern models discrete manufacturing and operational technology (OT) connectivity to Kubernetes: sensors, MQTT, Kafka-centric pipelines, CI/CD for edge software, ML-assisted anomaly detection, and centralized data lakes.

After operators discover Kafka clusters (see **[AMQ Streams](products/amq-streams.md#operator-discovery)**) and mesh namespaces receive ambient labels (**[Service Mesh](products/service-mesh.md#operator-discovery)**), use this page as the **business narrative** tying workloads together. If you haven't yet installed, start with **[Getting Started](getting-started.md)** and scaffold new instances via **[Scaffolding](scaffolding.md)**.

## Factory pattern

Factories emit telemetry through MQTT brokers and Camel integrations. Kubernetes namespaces isolate teams while GitOps keeps spoke clusters aligned with approved revisions. Each spoke runs an identical stack independently — the hub aggregates metrics and provides gateway access.

## Data stack

| Stage | Component | Namespace |
| ----- | ---------- | --------- |
| Ingress | AMQ Broker (MQTT acceptors), machine sensors | `industrial-edge-tst-all` |
| Integration | Camel K routes (MQTT→Kafka, Kafka→S3) | `industrial-edge-tst-all` |
| Streaming | AMQ Streams / Kafka dev-cluster topics | `industrial-edge-tst-all` |
| Replication | Strimzi MirrorMaker (factory→data-lake) | `industrial-edge-stormshift-messaging` |
| Data lake | prod-cluster Kafka + Camel S3 archiver | `industrial-edge-data-lake` |
| Processing | OpenShift AI (KServe InferenceService) | `industrial-edge-tst-all` |
| CI/CD | Tekton pipelines (buildah + deploy) | `industrial-edge-ci` |
| Visualization | line-dashboard (WebSocket consumer) | `industrial-edge-tst-all` |

## Camel K integrations

The `mqtt-to-kafka` integration bridges sensor data from the AMQ Broker to Kafka topics. It runs as a Camel K `Integration` CR deployed by the `industrial-edge-tst` chart. The **Camel Kaoto** software template in Developer Hub scaffolds additional Camel routes with a DevSpaces-ready project including:

- MQTT→Kafka route (temperature, vibration)
- Kafka→S3/MinIO archiver (data lake)
- Alert→Mailpit route (anomaly notifications)
- Kaoto visual editor + Continue AI code assistant

To scaffold a Camel route: **Developer Hub → Create → Industrial Edge — Camel Routes (Kaoto + Continue AI)** → choose east or west.

## Spoke components (per cluster)

Each spoke (east/west) deploys the following Argo CD Applications:

| Application | Chart | Purpose |
| ----------- | ----- | ------- |
| `industrial-edge-tst` | `charts/all/industrial-edge-tst` | Sensors, broker, Kafka, Camel, dashboard, ML |
| `industrial-edge-stormshift` | `charts/all/industrial-edge-stormshift` | Factory Kafka + MirrorMaker |
| `industrial-edge-data-lake` | `charts/all/industrial-edge-data-lake` | prod-cluster + S3 archiver |
| `industrial-edge-pipelines` | `charts/all/industrial-edge-pipelines` | Tekton build-and-test pipeline |

## Service mesh (ambient mode)

Industrial Edge namespaces run under **OSSM3 ambient** mesh with ztunnel L4 metrics. The namespace `industrial-edge-tst-all` carries the label `istio.io/dataplane-mode: ambient`. Ztunnel captures `istio_tcp_connections_opened_total` and related L4 series; L7 `istio_requests_total` flows through waypoint gateways where deployed.

**Exception:** `spoke-gateway-system` and `industrial-edge-data-lake` stay **off** ambient to avoid TLS conflicts with MinIO and WebSocket routing.

## Links

- [Industrial Edge Validated Pattern](https://validatedpatterns.io/patterns/industrial-edge)

Related charts: `industrial-edge-tst`, `industrial-edge-stormshift`, `industrial-edge-pipelines`, hub-side data lake charts.

---

**Next →** [Red Hat Products](products/) for per-operator deep dives (Service Mesh, ACM, AMQ Streams, Developer Hub, etc.).
