---
title: Amq Streams
weight: 17
---

# AMQ Streams

**Git path:** `charts/all/industrial-edge-*/` (Kafka clusters per environment)
{: .fs-3 .text-grey-dk-000 }

Red Hat **AMQ Streams** is the enterprise distribution of **Apache Kafka** on OpenShift, including operators for Kafka, KRaft mode, Kafka Connect, and **MirrorMaker 2** for geo replication.

![Kafka Console – 5 clusters connected]({{ site.baseurl }}/assets/images/product-kafka-console-amq-streams.png)
{: .mb-4 }
*Streams for Apache Kafka Console showing all connected clusters (hub + east/west spokes).*
{: .fs-2 .text-grey-dk-000 }

![Kafka Console – Topic messages]({{ site.baseurl }}/assets/images/product-kafka-console-amq-streams-2.png)
{: .mb-4 }
*Topic browser — `temperature` messages on `dev-cluster-west` via Skupper.*
{: .fs-2 .text-grey-dk-000 }

![Kafka Console – Cluster detail]({{ site.baseurl }}/assets/images/product-kafka-console-amq-streams-3.png)
{: .mb-4 }
*Kafka Console — cluster detail view with broker metrics and consumer group lag.*
{: .fs-2 .text-grey-dk-000 }

## Industrial Edge usage

- **Sensor and MQTT-derived topics** land in Kafka via integrations (often Camel K).
- **KRaft mode** (Kafka 4.x) with `KafkaNodePool` — no ZooKeeper.
- East and west spokes each run **dev-cluster** (`industrial-edge-tst-all`) and **factory-cluster** (`industrial-edge-stormshift-messaging`).
- Topics partition workload between east and west factories while observability aggregates lag and throughput metrics.

Charts: `charts/all/industrial-edge-tst`, `charts/all/industrial-edge-stormshift`, `charts/all/industrial-edge-data-lake`.

## Operator discovery

**Strimzi Cluster Operator** watches **`Kafka`**, **`KafkaNodePool`**, **`KafkaTopic`**, … wherever CRDs land — namespaces (`industrial-edge-tst-all`, `industrial-edge-stormshift-messaging`, `industrial-edge-data-lake`) simply host those manifests.

The hub **Kafka Console** ships via **`Console`** CR (`console.streamshub.github.com/v1alpha1` in **`charts/all/kafka-console/templates/all.yaml`**) with **`spec.kafkaClusters[]`** entries naming namespaces **plus bootstrap URLs** — discovery is **explicit GitOps**, not an annotation on random Deployments. Remote clusters still require **`metricsSources`** entries when Prometheus differs per spoke.

## Metrics (Grafana)

Kafka brokers expose JMX metrics via Strimzi's `jmxPrometheusExporter` ConfigMap. Scraping requires:

- **User Workload Monitoring** enabled on the cluster
- `PodMonitor` in `charts/all/istio-monitoring` selecting `strimzi.io/name: <cluster>-kafka`

Dashboard queries use `_objectname` regex filters for Kafka 4.x KRaft JMX layout (for example `kafka_server_brokertopicmetrics_*` with `.*OneMinuteRate.*`).

## Kafka Console (hub)

The **Streams for Apache Kafka Console** (`amq-streams-console` operator) runs on the **hub** only (`charts/all/kafka-console`). It lists four remote clusters:

| Console name | Skupper bootstrap (hub) |
| ------------ | ------------------------ |
| dev-cluster-east | `kafka-east-tst.service-interconnect.svc:9092` |
| dev-cluster-west | `kafka-west-tst.service-interconnect.svc:9092` |
| factory-cluster-east | `kafka-east-stormshift.service-interconnect.svc:9092` |
| factory-cluster-west | `kafka-west-stormshift.service-interconnect.svc:9092` |

OpenShift Console link: **Kafka Console (All Clusters)** → `https://kafka-console.<hub-domain>`.

### Broker advertised addresses

Brokers must advertise hostnames resolvable **on the hub** after metadata exchange. The platform uses:

- **Spoke** `advertisedHost`: `dev-cluster-broker-0-<east|west>.dev-cluster-kafka-brokers.industrial-edge-tst-all.svc.cluster.local`
- **Hub** `broker-dns.yaml`: **EndpointSlice** (not Endpoints — Argo CD excludes Endpoints) pointing each `advertisedHost` to the correct Skupper listener IP

Without this, the UI shows: `Timed out waiting for a node assignment` / `listNodes`.

## Documentation

- [Red Hat AMQ Streams documentation](https://docs.redhat.com/en/documentation/red_hat_amq_streams/)
- [Streams for Apache Kafka Console](https://docs.redhat.com/en/documentation/red_hat_streams_for_apache_kafka/)

Related: [Service Interconnect](../service-interconnect.md), [Observability](../observability.md).
