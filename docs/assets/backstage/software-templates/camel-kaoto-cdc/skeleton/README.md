# ${{ values.name }}

Apache Camel CDC route with Kaoto visual designer — consumes Change Data Capture events from Kafka and sends notifications via Mailpit.

## Open in DevSpaces

1. From **Red Hat Developer Hub**, click **Open in DevSpaces** in the component page.
   Alternatively, open this URL directly:

   ```
   https://devspaces.<cluster-domain>/#https://gitea-gitea.<cluster-domain>/ws-<user>/${{ values.name }}
   ```

2. Wait for the workspace to start (~2 min on first launch). The `devfile.yaml` automatically:
   - Provisions a container with Maven, JDK, and Camel tooling
   - Downloads and installs **Kaoto** and **Apache Camel** VS Code extensions

3. If the extensions don't appear immediately, open the **Extensions** panel (`Ctrl+Shift+X`) and search for `Kaoto` — it should be listed under *Installed*.

## Edit the route visually

1. Open `routes/cdc-to-mail.camel.yaml`
2. Click the **Kaoto** tab (Design view) at the top of the editor
3. The visual canvas shows the full route: Kafka source → log → unmarshal → choice → marshal → HTTP sink → log
4. Click any node to edit its properties in the right panel
5. Use **+ Add step** to insert new EIPs (Content Based Router, Transform, Filter, etc.)
6. Changes in the visual editor are saved back to the YAML file automatically

## Route overview

| Step | Component | Description |
|------|-----------|-------------|
| Source | `kafka:cdc.public.customers` | Consumes CDC events from the Debezium topic |
| Log | `log` | Logs the raw CDC event body |
| Unmarshal | `json (jackson)` | Parses the JSON payload |
| Choice | `choice / simple` | Routes based on operation type (`c` = create) |
| SetBody | `simple` | Builds the Mailpit email JSON payload |
| Marshal | `json (jackson)` | Serializes the email payload back to JSON |
| HTTP Sink | `http` | Sends the email to Mailpit API |

## Build & run

From the DevSpaces terminal (or the devfile command palette):

```bash
# Build
mvn package -DskipTests

# Run in dev mode (hot reload)
mvn quarkus:dev
```

## Project structure

```
.
├── devfile.yaml          # DevSpaces workspace definition
├── catalog-info.yaml     # Backstage catalog entity
├── routes/
│   └── cdc-to-mail.camel.yaml   # Camel route (Kaoto-editable)
└── README.md
```

## Kafka configuration

| Property | Value |
|----------|-------|
| Bootstrap server | `${{ values.kafkaBootstrap }}` |
| Source topic | `${{ values.kafkaTopic }}` |
| Consumer group | `camel-cdc-${{ values.name }}` |
| Deserializer | `StringDeserializer` |

## Useful links

- [Apache Camel documentation](https://camel.apache.org/camel-quarkus/latest/)
- [Kaoto visual designer](https://kaoto.io/)
- [Camel YAML DSL reference](https://camel.apache.org/camel-k/latest/languages/yaml.html)
