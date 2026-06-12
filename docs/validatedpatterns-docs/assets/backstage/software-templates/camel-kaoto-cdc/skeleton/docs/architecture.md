# Architecture

## CDC Pipeline Flow

The Camel CDC route is part of the Event-Driven Architecture pipeline:

1. **PostgreSQL** — Source database with WAL enabled
2. **Debezium** — Captures row-level changes via CDC
3. **Kafka** — Streams CDC events as CloudEvents
4. **Camel Route** — Processes, transforms and routes events
5. **Downstream** — Email notifications, APIs, other systems

## Camel Route Design

Routes are defined in YAML DSL and can be visually edited with Kaoto:

- `from`: Kafka consumer listening to CDC topics
- `choice/when`: Content-based routing by operation type
- `setBody`: Transform CDC payload to target format
- `to`: Send to downstream HTTP endpoints

## Configuration

Key properties in `application.properties`:

| Property | Description |
|---|---|
| `camel.main.routes-include-pattern` | Route file location |
| `quarkus.http.port` | HTTP server port |
