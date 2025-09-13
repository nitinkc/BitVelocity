# Event Contracts Usage Guide

## Quick Reference
For detailed specifications, see [CROSS_EVENT_CONTRACTS_AND_VERSIONING.md](docs/CROSS_EVENT_CONTRACTS_AND_VERSIONING.md)

## Naming Convention
`<domain>.<context>.<entity>.<eventType>.v<majorVersion>`

Examples:
- `ecommerce.order.order.created.v1`
- `chat.message.message.sent.v1`
- `iot.telemetry.telemetry.raw.v1`

## Workflow
1. **Draft Phase**: Add new event schema under appropriate domain path in `event-contracts/`
2. **Validation**: Run `./scripts/validate-events.sh` to check:
   - Schema compatibility and naming conventions
   - Field naming rules: snake_case in payload; envelope camelCase
   - Required fields validation and eventType format compliance
3. **Documentation**: Update `CHANGELOG.md` in event-contracts repo
4. **Integration**: Reference event in service README with producer & consumers
5. **Testing**: Add integration test publishing example event

## Repository Structure
```
event-contracts/
  ecommerce/
    order/order.created.v1.json
    order/order.paid.v1.json
    inventory/stock.adjusted.v1.json
    product/product.updated.v1.json
  chat/
    message/message.sent.v1.json
  social/
    post/post.created.v1.json
  iot/
    telemetry/telemetry.raw.v1.json
  ml/
    fraud/order.scored.v1.json
  security/
    policy/policy.updated.v1.json
  schema/
    envelope.schema.json
```

## Required Fields (Minimum)
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

## Compatibility Rules
- **Additive changes only** within same major version
- **Remove or rename field** → bump major version
- **Consumers must tolerate unknown fields**
- **All events include traceId, correlationId**
- **Major version bump requires dual-publish transitional period**

## Version Lifecycle
| Stage | Description |
|-------|-------------|
| Draft | In PR with contract file |
| Accepted | Merged & published |
| Deprecated | Replacement exists; warn consumers |
| Retired | No longer emitted |

## Breaking Change Procedure
1. Propose new major (v2) contract
2. Provide dual publishing period
3. Mark v1 deprecated in README
4. After consumer migration, retire

## Anti-Patterns to Avoid
| Anti-Pattern | Alternative |
|--------------|------------|
| Overloading eventType meaning | Different eventType per semantic outcome |
| Embedding large blobs | Store reference key & fetch from store |
| Using events for RPC | Use gRPC or REST |
| Emitting row-level churn as domain events | Use CDC layer |

## Exit Criteria
- All producing services generate contract artifacts
- CI pipeline rejects incompatible schema modifications
- Documentation for each event includes: purpose, producer, consumer list, retention hint
