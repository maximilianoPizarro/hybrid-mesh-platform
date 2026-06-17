---
title: Secrets configuration
nav_order: 7
parent: Hybrid Mesh Platform
---

# Secrets configuration (`values-secret.yaml`)

Hybrid Mesh Platform uses the **Validated Patterns secrets framework** (schema v2). Workshop facilitators copy the template locally; secrets are **never** committed to Git.

## Quick setup

```bash
cp values-secret.yaml.template values-secret.yaml
# Edit values-secret.yaml for your environment
./pattern.sh make install
```

`values-secret.yaml` is gitignored. CI validates the template against the upstream JSON schema (see `.github/workflows/jsonschema.yaml`).

Official VP reference: [Secrets management in the Validated Patterns framework](https://validatedpatterns.io/learn/secrets-management-in-the-validated-patterns-framework/).

## Schema overview

```yaml
version: "2.0"

secrets:
  - name: <kubernetes-secret-name>    # logical name VP Vault utils use
    vaultPrefixes:
      - global                        # Vault path prefix (VP hashicorp-vault chart)
    fields:
      - name: <key-in-secret>
        onMissingValue: generate      # generate | error | path | ini_file
        vaultPolicy: validatedPatternDefaultPolicy
```

| `onMissingValue` | When to use |
|------------------|-------------|
| `generate` | Demos / workshops — VP creates random values at install |
| `error` | Production — install fails until you provide the field |
| `path` | Read from a file on the install host (e.g. `~/.pullsecret.json`) |
| `ini_file` | Read from INI sections (e.g. AWS credentials) |

## Fields in this pattern

| Secret name | Keys | Required? | Notes |
|-------------|------|-----------|-------|
| `config-demo` | `secret` | No | Auto-generated demo secret |
| `kairos-ai-credentials` | `api-key` | Workshop | Use `error` + real MaaS key in production; RHDP may inject via `litemaas.apiKey` instead |
| `openshift-ai-maas-credentials` | `OPENAI_API_KEY`, `OPENAI_API_BASE` | Workshop | Same — prefer Vault+ESO path on hub (`vault-maas-external-secrets`) |
| `mcp-gateway-argocd` | `token` | Optional | Post-install; generate Argo CD token for MCP Gateway |
| `workshop-users` | `defaultPassword` | Optional | Demo user password; production should use OAuth |
| `aws` | `aws_access_key_id`, `aws_secret_access_key` | Only if provisioning clusters via ACM ClusterPools | Uncomment in template |
| `openshiftPullSecret` | `content` | Only for private cluster provisioning | Download from [console.redhat.com](https://console.redhat.com/openshift/install/pull-secret) |

## RHDP workshop vs standalone

| Scenario | What to configure |
|----------|-------------------|
| **RHDP field-content** (`existing_gitops: true`) | Often **no** `values-secret.yaml` on cluster — RHDP provisions the hub; MaaS keys flow via `litemaas.apiKey` and `maas-facilitator-rhdp-sync` |
| **Standalone `./pattern.sh install`** | Copy template → `values-secret.yaml`; set `onMissingValue: error` for MaaS keys or rely on Vault chart + facilitator seed |
| **Vault standalone** | VP `hashicorp-vault` chart + local `values-secret.yaml` for init/unseal tokens only — see [Vault product page](products/vault.md) |

## Example — production MaaS keys (standalone)

```yaml
version: "2.0"
secrets:
  - name: kairos-ai-credentials
    vaultPrefixes:
      - global
    fields:
      - name: api-key
        onMissingValue: error
        path: ~/.maas-api-key.txt
        vaultPolicy: validatedPatternDefaultPolicy

  - name: openshift-ai-maas-credentials
    vaultPrefixes:
      - global
    fields:
      - name: OPENAI_API_KEY
        onMissingValue: error
        path: ~/.maas-api-key.txt
        vaultPolicy: validatedPatternDefaultPolicy
      - name: OPENAI_API_BASE
        onMissingValue: error
        path: ~/.maas-api-base.txt
        vaultPolicy: validatedPatternDefaultPolicy
```

## Example — MCP Gateway Argo CD token

```bash
argocd account generate-token --account mcp-gateway > ~/.mcp-gateway-token
```

```yaml
  - name: mcp-gateway-argocd
    vaultPrefixes:
      - global
    fields:
      - name: token
        onMissingValue: error
        path: ~/.mcp-gateway-token
        vaultPolicy: validatedPatternDefaultPolicy
```

## Validate before install

```bash
cp values-secret.yaml.template values-secret.yaml
check-jsonschema --fill-defaults \
  --schemafile https://raw.githubusercontent.com/validatedpatterns/rhvp.cluster_utils/refs/heads/main/roles/vault_utils/values-secrets.v2.schema.json \
  values-secret.yaml
```

## Related

- [Getting started](getting-started.md) — install flow
- [Vault](products/vault.md) — Vault + External Secrets on hub
- [RHDP field content](rhdp-field-content.md) — runtime `litemaas.*` injection
