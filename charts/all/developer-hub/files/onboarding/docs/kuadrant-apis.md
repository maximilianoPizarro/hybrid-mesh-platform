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

1. Log in as `userN` / `Welcome123!` or `platformadmin`
2. **Option A — Kuadrant sidebar:** **Kuadrant** → **API Products** → click the **product name** → **Request API key** → choose plan
3. **Option B — Catalog API entity:** **Catalog** → System **workshop-kuadrant-apis** → open an **API** (e.g. `workshop-maas-openapi`) → **Kuadrant** tab → **Request API key**
4. **My API Keys** (Kuadrant sidebar) → copy key
5. **Definition** tab on the same API entity for Swagger / curl examples
6. Call with: `Authorization: APIKEY <your-key>`

> Do **not** use the pencil (Edit) icon on API Products — use the product **name** or the Catalog **API** entity **Kuadrant** tab instead.

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
  -d '{"model":"granite-3-2-8b-instruct","messages":[{"role":"user","content":"Hello"}],"max_tokens":50}'
```

## GitOps

- Chart: `charts/all/workshop-kuadrant-apis/`
- Day-2: `bash scripts/apply-workshop-kuadrant-apis.sh`
- Catalog: System **workshop-kuadrant-apis** (Components + OpenAPI for Swagger)
