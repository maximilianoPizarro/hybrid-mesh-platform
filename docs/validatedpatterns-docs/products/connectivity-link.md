---
title: Connectivity Link
weight: 20
---

# Connectivity Link

**Red Hat Connectivity Link (RHCL)** is an Application Foundation bundle that brings multi-cluster ingress and API policy using **Kubernetes Gateway API** with **Kuadrant** controllers (installed via `charts/all/rhcl-operator/`). Kuadrant CRDs such as **APIProduct**, **AuthPolicy**, **PlanPolicy**, and **TokenRateLimitPolicy** are part of RHCL — not a separate product alongside it.

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
