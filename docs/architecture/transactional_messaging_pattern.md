# Transactional Messaging & Idempotency (Outbox Pattern)
Version: 1.0  
Status: Draft  

## 1. Problem
Need reliable event publication without dual-write inconsistency between DB state and messaging system (Kafka).

## 2. Solution Summary
Adopt Outbox pattern using single DB transaction to persist domain change + event record. Debezium (CDC) streams outbox inserts to Kafka. Consumers implement idempotent processing.

## 3. Outbox Table Schema (Orders Example)
| Column | Type | Notes |
|--------|------|------|
| id | UUID | Primary key |
| aggregate_type | TEXT | e.g. ORDER |
| aggregate_id | TEXT | Business key |
| event_type | TEXT | ecommerce.order.created.v1 |
| payload_json | JSONB | Canonical event body |
| occurred_at | TIMESTAMPTZ | Domain event time |
| published_at | TIMESTAMPTZ NULL | Optional marking for fallback poller |
| trace_id | TEXT | Trace propagation |
| partition_key | TEXT | Deterministic Kafka partition field |
| schema_version | TEXT | Evolution control |

DDL (Postgres):
```sql
CREATE TABLE order_outbox (
  id UUID PRIMARY KEY,
  aggregate_type TEXT NOT NULL,
  aggregate_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  payload_json JSONB NOT NULL,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  published_at TIMESTAMPTZ NULL,
  trace_id TEXT,
  partition_key TEXT,
  schema_version TEXT DEFAULT '1.0'
);
CREATE INDEX idx_order_outbox_unpublished ON order_outbox(published_at) WHERE published_at IS NULL;
```

## 4. Write Flow
1. Service receives command (CreateOrder).
2. DB transaction:
   - Insert `orders` row.
   - Insert `order_outbox` row (no publish yet).
3. Commit guarantees atomicity.
4. CDC (Debezium) captures row → publishes to Kafka `ecommerce.order.events`.
5. Optional fallback poller (if CDC is unavailable) picks unpublished rows.

## 5. Event Envelope Standard
```json
{
  "eventId": "uuid",
  "eventType": "ecommerce.order.created.v1",
  "occurredAt": "2025-01-01T12:00:00Z",
  "producer": "order-service",
  "traceId": "trace-ctx",
  "correlationId": "corr-id",
  "partitionKey": "orderId",
  "schemaVersion": "1.0",
  "payload": { ... }
}
```

## 6. Consumer Idempotency
Approach:
- Maintain Redis set or Postgres table `processed_events (event_id PK)`.
- Before processing: check existence; if present → skip.
- After success: insert event_id; atomic via upsert.

Alternative: Use Kafka consumer offsets + exactly-once semantics (heavier).

## 7. Failure Scenarios
| Scenario | Issue | Mitigation |
|----------|-------|------------|
| CDC lag | Delayed events | Alert on lag metric; fallback poller |
| Duplicate consumption | Reprocessing events | Idempotency store |
| Poison event (schema error) | Consumer crash loop | Dead-letter topic with alert |
| Partition key change | Reordering | Strict contract in schema governance |
| Payload evolution | Incompatibility | Backward-compatible additive fields only |

## 8. Observability
Metrics:
- `outbox_unpublished_count`
- `cdc_lag_seconds`
- `event_publish_latency_seconds` (occurred_at → Kafka timestamp)
- `consumer_idempotency_hit_ratio`

Tracing:
- Include traceId in outbox payload.
- Consumer spans link via traceparent header reconstruction if present.

## 9. Retry & Backpressure
- Consumers use exponential jitter backoff on transient failures.
- Hard failure after N attempts → send to DLQ topic `ecommerce.order.events.dlq`.
- Replay service consumes DLQ after fix.

## 10. Debezium Connector Config (Snippet)
```json
{
  "name": "orders-outbox-connector",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "postgres",
    "database.port": "5432",
    "database.user": "debezium",
    "database.password": "****",
    "database.dbname": "orders",
    "database.server.name": "ordersdb",
    "table.include.list": "public.order_outbox",
    "tombstones.on.delete": "false",
    "slot.name": "orders_outbox_slot",
    "publication.autocreate.mode": "filtered",
    "schema.include.list": "public"
  }
}
```

## 11. Testing Strategy
- Unit: Wrap transaction boundary; assert outbox row created.
- Integration: Use Testcontainers Postgres + Debezium; assert Kafka event publish.
- Contract: Schema registry compatibility test for event payload.
- Replay test: Inject duplicate event; ensure consumer processes once.

## 12. Backlog Seeds
- Story: Create base outbox schema & repository.
- Story: Integrate Debezium container into docker-compose dev.
- Story: Add consumer idempotency module.
- Story: Implement metrics & dashboard.
- Story: Build replay CLI for DLQ.

## 13. Future Enhancements
- Multi-tenant outbox (separate partition_key semantics).
- Batch outbox compaction (archive older processed events).
- Encryption of sensitive payload fields (Vault transit).

---