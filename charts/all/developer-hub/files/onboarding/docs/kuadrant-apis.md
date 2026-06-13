# Kuadrant API keys (userN)

Use **Developer Hub → Kuadrant** to request API keys for workshop APIs. Kuadrant is delivered by the **Red Hat Connectivity Link (RHCL)** bundle (`rhcl-operator`). Backends are **public web APIs** registered via Istio **ExternalName** + **ServiceEntry** and exposed through **hub Gateway API** + RHCL/Kuadrant policies.

## API Products

| Product | Path | External host | Policy |
|---------|------|---------------|--------|
| httpbin | `/httpbin/*` | httpbin.org | PlanPolicy (bronze / silver / gold) |
| REST Countries | `/countries/*` | restcountries.com | PlanPolicy |
| LLM (MaaS) | `/llm/v1/chat/completions` | MaaS RHDP | **TokenRateLimitPolicy** (free / gold) |

Base URL: `https://workshop-apis.<hub-domain>/`

Console: **Platform Hub-Spoke → Workshop APIs (Kuadrant)** (route exists; calls need API key).

## Flow (Developer Hub)

1. Log in as `userN` / `Welcome123!`
2. Open **Kuadrant** in the sidebar (or Catalog → **workshop-api-consumer**)
3. **API Products** → pick httpbin, REST Countries, or MaaS LLM
4. **Request API key** → choose plan tier (auto-approved)
5. **My API Keys** → copy key
6. Call APIs with header: `Authorization: APIKEY <your-key>`

## OpenShift Console (optional)

- **Administration → Custom resources → APIProduct** in namespace `hub-gateway-system`
- Namespace **view** for `userN` on `workshop-kuadrant-apis`, `kuadrant-system`

Primary UX for keys remains **Developer Hub `/kuadrant`**.

## Examples

```bash
export KEY="<api-key-from-developer-hub>"
export BASE="https://workshop-apis.<hub-domain>"

curl -H "Authorization: APIKEY $KEY" "$BASE/httpbin/get"
curl -H "Authorization: APIKEY $KEY" "$BASE/countries/name/chile"
```

## TokenRateLimit demo (LLM / MaaS)

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

- Without `Authorization: APIKEY …` you get **401** (expected — gateway is protected)
- Exceeding plan limits returns **429**
- GitOps: `charts/all/workshop-kuadrant-apis/`; day-2: `bash scripts/apply-workshop-kuadrant-apis.sh`
- Catalog entities: System **workshop-kuadrant-apis** (Components + OpenAPI API entities)
