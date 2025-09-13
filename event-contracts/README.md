# Event Contracts Repository

Structure:
```
event-contracts/
  ecommerce/order/order.created.v1.json
  ecommerce/order/order.paid.v1.json
  ecommerce/inventory/stock.adjusted.v1.json
  ecommerce/product/product.updated.v1.json
  chat/message/message.sent.v1.json
  social/post/post.created.v1.json
  iot/telemetry/telemetry.raw.v1.json
  security/policy/policy.updated.v1.json
  schema/
    envelope.schema.json
```

All payload schemas are additive-only per major version.

Validation pipeline:
1. Envelope schema validation
2. Backward compatibility check
3. Lint: required fields, naming conventions, no PII leakage