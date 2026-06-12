# Kuadrant API keys (userN)

Use **Developer Hub → Kuadrant** to request API keys for workshop APIs. Kuadrant is delivered by the **Red Hat Connectivity Link (RHCL)** bundle (`rhcl-operator`). Backends are **public web APIs** (no in-cluster Docker images) registered as Istio external services and exposed through **hub Gateway API** + RHCL/Kuadrant policies.

## API Products

| Product | Path | External host | Policy |
|---------|------|---------------|--------|
| httpbin | `/httpbin/*` | httpbin.org | PlanPolicy (bronze / silver / gold) |
| REST Countries | `/countries/*` | restcountries.com | PlanPolicy |
| LLM (MaaS) | `/llm/v1/chat/completions` | MaaS RHDP | **TokenRateLimitPolicy** (free / gold) |

Base URL: `https://workshop-apis.<hub-domain>/`

Architecture: `ServiceEntry` + `DestinationRule` (TLS origination) → `HTTPRoute` (`Hostname` backendRef) → Kuadrant `AuthPolicy` / `PlanPolicy` / `TokenRateLimitPolicy`.

## Flow

1. Log in as `userN` / `Welcome123!`
2. Open **Kuadrant** in the sidebar
3. Pick an API Product → **Request API key**
4. Choose a plan tier (auto-approved)
5. Copy the key and call the API:

```bash
export KEY="<api-key-from-developer-hub>"
export BASE="https://workshop-apis.<hub-domain>"

curl -H "Authorization: APIKEY $KEY" "$BASE/httpbin/get"
curl -H "Authorization: APIKEY $KEY" "$BASE/countries/name/chile"
```

## TokenRateLimit demo (LLM / MaaS)

Request a **free** or **gold** key on **Workshop LLM API**. The gateway validates your Kuadrant API key and forwards to external MaaS:

```bash
curl -H "Authorization: APIKEY $KEY" -H "Content-Type: application/json" \
  -X POST "$BASE/llm/v1/chat/completions" \
  -d '{
    "model": "llama-scout-17b",
    "messages": [{"role": "user", "content": "What is OpenShift?"}],
    "max_tokens": 80,
    "stream": false
  }'
```

Repeat until HTTP **429** — Kuadrant counts `usage.total_tokens` from the MaaS response.

## Tips

- Without `Authorization: APIKEY …` you get **401**
- Exceeding plan limits returns **429**
- GitOps manifests: `components/workshop-kuadrant-apis/` (external backends only)
