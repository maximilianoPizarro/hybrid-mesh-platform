---
title: Kafka Console
weight: 25
---

# Kafka Console

**Git path:** `charts/all/kafka-console/`
{: .fs-3 .text-grey-dk-000 }

The **Streams for Apache Kafka Console** provides a unified UI on the **hub** for Kafka clusters running on east and west spokes, connected over Skupper.

## What ships

| Resource | Purpose |
| -------- | ------- |
| `amq-streams-console` operator | Hub OLM subscription |
| `Console` CR | Lists remote clusters with bootstrap URLs |
| `broker-dns.yaml` | Hub EndpointSlices for Skupper broker hostnames |
| Route + optional API route | `https://kafka-console.<hub-domain>` |

Console link in OpenShift: **Kafka Console (All Clusters)**.

## Connected clusters

| Console name | Bootstrap (hub Skupper service) |
| ------------ | ------------------------------- |
| dev-cluster-east | `kafka-east-tst.service-interconnect.svc:9092` |
| dev-cluster-west | `kafka-west-tst.service-interconnect.svc:9092` |
| factory-cluster-east | `kafka-east-stormshift.service-interconnect.svc:9092` |
| factory-cluster-west | `kafka-west-stormshift.service-interconnect.svc:9092` |

See [AMQ Streams](amq-streams.md) for broker advertised addresses and JMX metrics.

## Operator discovery

Discovery is **explicit** via the `Console` CR `spec.kafkaClusters[]` — not workload annotations. Each entry names the logical cluster, namespace context, and bootstrap URL.

## Verify

```bash
oc get console -n kafka-console
curl -sk "https://kafka-console.<hub-domain>/api/kafkas" | head
oc get endpointslices -n kafka-console
```

## Troubleshooting

| Symptom | Fix |
| ------- | --- |
| `/api/kafkas` 404 | Enable `apiRoute` in kafka-console chart; external route may serve UI only |
| `Timed out waiting for node assignment` | Re-sync after Skupper listeners Ready; verify `broker-dns` EndpointSlices |
| Empty cluster list | Check `Console` CR cluster entries and Skupper connectivity |

## Documentation

- [Red Hat Streams for Apache Kafka Console](https://docs.redhat.com/en/documentation/red_hat_streams_for_apache_kafka/)

**Next:** [AMQ Streams](amq-streams.md) for Strimzi clusters and Industrial Edge topic flow.
