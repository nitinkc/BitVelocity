# Cross-Cutting – Event Contracts & Versioning

## 1. Naming Convention
`<domain>.<context>.<entity>.<eventType>.v<majorVersion>`

## 2. Guidelines
- Additive changes only in same major.
- Remove or rename field → bump major.
- Consumers must tolerate unknown fields.
- All events include traceId, correlationId.

## 3. Contract Fields (Minimum)
| Field | Purpose |
|-------|---------|
| eventId | Uniqueness |
| eventType | Routing + version |
| occurredAt | Temporal ordering |
| producer | Source service |
| traceId | Tracing correlation |
| correlationId | Business transaction |
| partitionKey | Partition strategy |
| payload | Business data |
| schemaVersion | Envelope schema version |
| tenantId | Multitenancy future |

## 4. Version Lifecycle
| Stage | Description |
|-------|-------------|
| Draft | In PR with contract file |
| Accepted | Merged & published |
| Deprecated | Replacement exists; warn consumers |
| Retired | No longer emitted |

## 5. Repository Layout Suggestion (Shared)
```
event-contracts/
  ecommerce/
    order/
      order.created.v1.json
  chat/
    message/
      message.sent.v1.json
  social/
    post/
      post.created.v1.json
  iot/
    telemetry/
      telemetry.raw.v1.json
  ml/
    fraud/
      order.scored.v1.json
```

## 6. Validation Pipeline
- Schema compatibility check (CI)
- Field naming rules: snake_case in payload; envelope camelCase.
- Lint: required fields, no personally identifying raw values.

## 7. Breaking Change Procedure
1. Propose new major (v2) contract.
2. Provide dual publishing period.
3. Mark v1 deprecated in README.
4. After consumer migration, retire.

## 8. Event Evolution Anti-Patterns
| Anti-Pattern | Alternative |
|--------------|------------|
| Overloading eventType meaning | Different eventType per semantic outcome |
| Embedding large blobs | Store reference key & fetch from store |
| Using events for RPC | Use gRPC or REST |
| Emitting row-level churn as domain events | Use CDC layer |

## 9. Event to Projection Mapping Table
| Event | Primary Projection(s) |
|-------|-----------------------|
| order.created | orders_by_customer |
| inventory.stock.adjusted | inventory_snapshot |
| post.created | global_feed |
| chat.message.sent | room_message_log |
| telemetry.raw | anomaly_stream |
| fraud.order.scored | review_queue (future) |

## 10. Exit Criteria
- All producing services generate contract artifacts.
- CI pipeline rejects incompatible schema modifications.
- Documentation for each event includes: purpose, producer, consumer list, retention hint.
