# ${{ values.name }}

${{ values.description }}

## Overview

This component implements an **Apache Camel CDC route** using the Kaoto visual designer. It connects to Kafka topics that receive Change Data Capture (CDC) events from Debezium and processes them through configurable Camel routes.

## Architecture

```
PostgreSQL ─ WAL ─▶ Debezium ─ CDC ─▶ Kafka ─▶ Camel Route ─▶ Downstream
```

## Key Technologies

| Technology | Purpose |
|---|---|
| Apache Camel | Integration framework |
| Kaoto | Visual route designer |
| Kafka | Event streaming |
| Debezium | Change Data Capture |
| Quarkus | Runtime platform |

## Quick Start

1. Open in **DevSpaces** using the link in the component overview
2. Use **Kaoto** visual editor to modify routes in `routes/`
3. Run locally: `mvn quarkus:dev`
4. Build: `mvn package -DskipTests`

## Kafka Topics

- **Input**: `cdc.public.customers` — CDC events from PostgreSQL
- **Consumer Groups**: `camel-k-enricher`, `connect-mailpit-http-sink`

## Project Structure

```
├── routes/
│   └── cdc-to-mail.camel.yaml    # Camel route definition
├── src/main/resources/
│   └── application.properties     # Quarkus config
├── pom.xml                        # Maven build
├── devfile.yaml                   # DevSpaces config
└── catalog-info.yaml              # Backstage entity
```
