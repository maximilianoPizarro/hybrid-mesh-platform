---
title: Connectivity Link
weight: 20
---

# Connectivity Link

**Red Hat Connectivity Link (RHCL)** is an Application Foundation bundle that brings multi-cluster ingress and API policy using **Kubernetes Gateway API** with **Kuadrant** controllers (installed via `charts/all/rhcl-operator/`). Kuadrant CRDs such as **APIProduct**, **AuthPolicy**, **PlanPolicy**, and **TokenRateLimitPolicy** are part of RHCL — not a separate product alongside it.

## What problem does it solve?

Industrial Edge and workshop APIs need **consistent north-south ingress** with optional **rate limits**, **API keys**, and **tiered plans** — the same problems F5 or Apigee solve, but native to Kubernetes Gateway API. RHCL + Kuadrant attach policy to **`HTTPRoute`** objects instead of bolting on a separate API gateway VM.

| Gateway | Namespace | Role |
| ------- | --------- | ---- |
| **Hub gateway** | `hub-gateway-system` | Central VIP-style routing to hub and spoke backends ([Hub Gateway](../hub-gateway.md)) |
| **Spoke gateway** | per spoke | Aggregates IE services behind one entry (`charts/all/spoke-gateway`) |
| **Workshop APIs** | `workshop-kuadrant-apis` | Demo **AuthPolicy** + **TokenRateLimitPolicy** on MaaS and httpbin routes |

### Example policies in this repo

Workshop chart `charts/all/workshop-kuadrant-apis` deploys dedicated **Gateway API** gateways (`workshop-apis`, `ai-gateway`) with Kuadrant policies:

| API Product | HTTPRoute | Plans | Policy types |
| ----------- | --------- | ----- | -------------- |
| `workshop-httpbin` | `workshop-httpbin` | bronze / silver / gold | AuthPolicy + PlanPolicy |
| `workshop-restcountries` | `workshop-restcountries` | bronze / silver / gold | AuthPolicy + PlanPolicy |
| `workshop-mcp-gateway` | `workshop-mcp` | bronze / gold | AuthPolicy + PlanPolicy |
| `workshop-llm-tokens` | `ai-maas` | free / gold | AuthPolicy + PlanPolicy + TokenRateLimitPolicy |

- **`AuthPolicy`** — API key authentication (`Authorization: APIKEY …`); secret selector label `app` must match **APIProduct.metadata.name**
- **`PlanPolicy`** — tiered limits keyed off `secret.kuadrant.io/plan-id` annotation on the API key secret
- **`TokenRateLimitPolicy`** — token-bucket limits on `POST /v1/chat/completions` (MaaS proxy)

Policies target **`spec.targetRef`** → `HTTPRoute` in `workshop-kuadrant-apis` or `ai-gateway-system`. Tune tiers in `charts/all/workshop-kuadrant-apis/values.yaml`.

### RHCL + Sail/Istio mesh (required)

RHCL CSV defaults `ISTIO_GATEWAY_CONTROLLER_NAMES` to `openshift.io/gateway-controller/v1`. This platform uses Sail/Istio **`GatewayClass` `istio`** with controller **`istio.io/gateway-controller`**. The chart `charts/all/rhcl-operator` sets the subscription override:

```yaml
spec.config.env:
  - name: ISTIO_GATEWAY_CONTROLLER_NAMES
    value: istio.io/gateway-controller,openshift.io/gateway-controller/v1
```

Kuadrant detects the gateway provider **only at operator pod startup**. After mesh is ready, `workshop-kuadrant-apis` runs a PostSync Job to restart `kuadrant-operator-controller-manager` (or use `bash scripts/apply-workshop-kuadrant-apis.sh`).

**Symptom:** AuthPolicy / PlanPolicy **Invalid (Not Accepted)** — `MissingDependency: Gateway API provider (istio / envoy gateway) is not installed`. Fix subscription env + restart operator; verify `oc get kuadrant kuadrant -n kuadrant-system` → **Ready=True**.

![Connectivity Link – Policy Topology]({{ site.baseurl }}/assets/images/connectivity-link-hub.png)
{: .mb-4 }
*Gateway API policy topology — hub-gateway, HTTPRoute, and route rules in OpenShift Console.*
{: .fs-2 .text-grey-dk-000 }

## In this platform

- Gateway API `Gateway` and `HTTPRoute` objects align with **hub gateway** style routing (including weighted splits similar to hardware ADC behavior).
- **Policies may be disabled initially** to reduce rollout friction; enable Kuadrant `AuthPolicy`, `RateLimitPolicy`, and DNS TLS strategies as you harden environments.

### Hub gateway

![Connectivity Link – Hub Gateway]({{ site.baseurl }}/assets/images/connectivity-link-hub-gateway.png)
{: .mb-4 }
*Hub cluster Gateway API resources and HTTPRoute attachment.*
{: .fs-2 .text-grey-dk-000 }

### Spoke connectivity

![Connectivity Link – Spoke]({{ site.baseurl }}/assets/images/connectivity-link-spoke.png)
{: .mb-4 }
*Spoke cluster Gateway API and backend services exposed through the mesh.*
{: .fs-2 .text-grey-dk-000 }

![Connectivity Link – Spoke Gateway]({{ site.baseurl }}/assets/images/connectivity-link-spoke-gateway.png)
{: .mb-4 }
*Spoke gateway aggregating Industrial Edge services for cross-cluster exposure.*
{: .fs-2 .text-grey-dk-000 }

## Operator discovery

Connectivity Link (RHCL) / Kuadrant controllers reconcile **Gateway API** **`Gateway`**, **`HTTPRoute`**, **`GatewayClass`**, plus Kuadrant **`DNSPolicy`**, **`TLSPolicy`**, **`AuthPolicy`**, **`PlanPolicy`**, **`TokenRateLimitPolicy`**, and **`APIProduct`** — controllers watch clusters via operator subscriptions (`charts/all/rhcl-operator`), **not** via blanket Deployment annotations.

Typical hub/spoke wiring attaches **`HTTPRoute`** `spec.parentRefs` to Gateway objects (`hub-gateway-system`, …); verify reconciliation by inspecting **`Gateway`** status conditions rather than Pod labels alone.

## Links

- [Connectivity Link documentation](https://docs.redhat.com/en/documentation/red_hat_connectivity_link/)
- [Kuadrant documentation](https://docs.kuadrant.io/)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)

Chart path: `charts/all/rhcl-operator`.
