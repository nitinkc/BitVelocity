# Event Contracts Repository

This repository contains all event schemas for the BitVelocity platform, organized by domain.

## Repository Structure
```
event-contracts/
  ecommerce/
    order/
      order.created.v1.json
      order.paid.v1.json
    inventory/
      stock.adjusted.v1.json
    product/
      product.updated.v1.json
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
  security/
    policy/
      policy.updated.v1.json
  schema/
    envelope.schema.json
```

## Guidelines
- All payload schemas are **additive-only per major version**
- Use naming convention: `<domain>.<context>.<entity>.<eventType>.v<majorVersion>`
- Field naming: snake_case in payload; envelope camelCase
- All events must include required envelope fields (see schema/envelope.schema.json)

## Validation Pipeline
The CI pipeline automatically validates:
1. **Envelope schema validation** against schema/envelope.schema.json
2. **Backward compatibility check** within major versions
3. **Lint checks**: required fields, naming conventions, no PII leakage
4. **Schema compatibility** with existing consumers

## Usage
1. Add new event schema file in appropriate domain directory
2. Follow naming convention for file and eventType
3. Ensure schema includes all required envelope fields
4. Submit PR - validation pipeline runs automatically
5. After merge, update consuming services

## Event to Projection Mapping
| Event | Primary Projection(s) |
|-------|-----------------------|
| order.created | orders_by_customer |
| inventory.stock.adjusted | inventory_snapshot |
| post.created | global_feed |
| chat.message.sent | room_message_log |
| telemetry.raw | anomaly_stream |
| fraud.order.scored | review_queue (future) |

For detailed specifications, see [../docs/CROSS_EVENT_CONTRACTS_AND_VERSIONING.md](../docs/CROSS_EVENT_CONTRACTS_AND_VERSIONING.md)