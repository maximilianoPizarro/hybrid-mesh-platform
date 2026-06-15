# Kuadrant API keys (userN)

Dedicated **workshop-apis** and **ai-gateway** Gateways expose ExternalName backends with Kuadrant API Products, PlanPolicy, and TokenRateLimit.

## Gateways

| Gateway | Host | APIs |
|---------|------|------|
| **workshop-apis** | `https://workshop-apis.<hub-domain>/` | httpbin, REST Countries, MCP |
| **ai-gateway** | `https://ai-gateway.<hub-domain>/` | MaaS LLM `/v1/chat/completions` |

Console: **Platform Hub-Spoke → Workshop APIs (Kuadrant)** and **AI Gateway (MaaS + Kuadrant)**.

## API Products (Developer Hub → Kuadrant)

| Product | Gateway | External backend |
|---------|---------|------------------|
| httpbin | workshop-apis | `httpbin.org` (ExternalName) |
| REST Countries | workshop-apis | `restcountries.com` |
| MCP Gateway | workshop-apis | `mcp-gateway-istio` (ExternalName → in-cluster) |
| MaaS LLM | ai-gateway | MaaS RHDP (ExternalName) |

## Flow (Developer Hub)

1. Log in as `userN` / `Welcome123!` (or `platformadmin` for admin tasks)
2. **Kuadrant** sidebar → **API Products**
3. Click the **product name** (not the pencil / Edit icon) to open the product page
4. **Request API key** → choose plan (bronze/silver/gold or free/gold for LLM)
5. **My API Keys** (Kuadrant sidebar) → copy key
6. **Catalog** → API entities → **View API** (Swagger) for httpbin / MaaS
7. Call with: `Authorization: APIKEY <your-key>`

> **Edit API Product** (pencil icon) needs `status.discoveredPlans` on the APIProduct CR. After GitOps sync, run `bash scripts/sync-kuadrant-apiproduct-plans.sh` if the edit form shows `discoveredPlans` errors. For workshop use, **Request API key** on the product page is enough — you do not need Edit.

## Vault (optional)

| Path | Purpose |
|------|---------|
| `secret/workshop/maas` | Upstream MaaS Bearer (platform) |
| `secret/workshop/kuadrant/<user>/<product>` | Mirror consumer API keys for CI |

Kuadrant keys live as K8s Secrets (`kuadrant.io/api-key`); Vault mirror is optional.

## Examples

```bash
export KEY="<api-key-from-developer-hub>"
export WORKSHOP="https://workshop-apis.<hub-domain>"
export AI="https://ai-gateway.<hub-domain>"

curl -H "Authorization: APIKEY $KEY" "$WORKSHOP/httpbin/get"
curl -H "Authorization: APIKEY $KEY" "$WORKSHOP/countries/name/chile"
curl -H "Authorization: APIKEY $KEY" -H "Content-Type: application/json" \
  -X POST "$AI/v1/chat/completions" \
  -d '{"model":"llama-scout-17b","messages":[{"role":"user","content":"Hello"}],"max_tokens":50}'
```

## GitOps

- Chart: `charts/all/workshop-kuadrant-apis/`
- Day-2: `bash scripts/apply-workshop-kuadrant-apis.sh`
- Catalog: System **workshop-kuadrant-apis** (Components + OpenAPI for Swagger)
