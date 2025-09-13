# Domain Architecture – E-Commerce

## 1. Purpose
Primary backbone domain to exercise transactional integrity (OLTP), event propagation, multi-protocol interaction, and derived data patterns.

## 2. Bounded Contexts & Services
| Context | Service | Responsibility | Initial Status |
|---------|---------|---------------|---------------|
| Catalog | product-service | Product CRUD, price versioning | Phase 1 |
| Pricing | pricing-service (optional merge into product early) | Flash sales, dynamic overrides | Phase 4 |
| Cart | cart-service | Manage session/user carts | Phase 1 |
| Order Lifecycle | order-service | Create, pay, cancel, fulfill | Phase 2 |
| Inventory | inventory-service | Reserve/release, stock adjustments, IoT feed | Phase 2–3 |
| Payment Integration | payment-adapter-service | Simulated SOAP legacy + REST fallback | Phase 4 |
| Notification | notification-service | WebSocket & SSE push for order & sale status | Phase 3 |
| Partner Integrations | partner-webhook-dispatcher | Outbound webhooks + retry queue | Phase 4 |
| Analytics Projection | analytics-streaming-service | Streams metrics & aggregates | Phase 5 |
| Replay (shared) | replay-service (cross repo) | Reconstruct projections/read models | Phase ≥7 |

## 3. Protocol Usage Matrix
| Use Case | Protocol | Rationale |
|----------|----------|-----------|
| Product CRUD | REST | Simplicity & ubiquity |
| Product + Inventory query | GraphQL federation | Aggregated read model |
| Stock reservation | gRPC | Low-latency internal call |
| Order lifecycle events | Kafka events | Decoupled downstream consumers |
| Flash sale broadcast | SSE | One-way scalable updates |
| Real-time order status | WebSocket | Bidirectional channel (future ack) |
| Payment gateway | SOAP + REST fallback | Legacy simulation & resilience |
| Outbound partner updates | Webhooks + RabbitMQ retry | External integration reliability |
| IoT stock adjustments | MQTT ingest → Kafka | Device realism |
| Batch sales summary | Batch job | Deferred computation |
| Streaming revenue metrics | Kafka Streams | Near real-time dashboard |

## 4. External Interfaces (Stable Contract Surfaces)
REST (simplified):
- POST /api/v1/products
- GET /api/v1/products/{id}
- POST /api/v1/orders  (Headers: Idempotency-Key, Correlation-Id)
- POST /api/v1/orders/{id}/pay
- POST /api/v1/orders/{id}/cancel
- GET /api/v1/orders/{id}

GraphQL (later):
```
type Query {
  product(id: ID!): Product
  products(filter: ProductFilter): [Product]
  productInventory(id: ID!): InventoryInfo
}
```

gRPC (inventory):
```
service Inventory {
  rpc ReserveStock(ReserveRequest) returns (ReserveResponse);
  rpc ReleaseStock(ReleaseRequest) returns (ReleaseResponse);
  rpc QueryStock(StockQuery) returns (StockStatus);
}
```

WebSocket Channels:
- /ws/orders (subscribe {orderId} or personal channel)
SSE:
- /sse/flash-sales

Outbound Webhooks:
- HMAC-SHA256 signature header: X-BV-Signature
- Retry schedule: 30s, 2m, 5m, 15m, 30m → DLQ event after max

SOAP Payment (WSDL simulated):
- Operation: ProcessPayment(orderId, amount, currency)

MQTT Topics:
- iot/inventory/{sku}/delta  (payload: { "delta": -2, "reason": "SENSOR" })

## 5. Data Architecture (OLTP → Derived → OLAP)
OLTP (Postgres):
- products, product_price_history (SCD2)
- orders, order_items, order_status_history
- carts, cart_items
- payments
- inventory_stock, inventory_adjustment
- webhook_subscriptions, webhook_delivery_attempts

CDC: Debezium captures orders, inventory_adjustment, product changes.

Derived Serving:
| Projection | Store | Built From |
|------------|-------|------------|
| orders_by_customer | Cassandra | domain events + CDC status |
| inventory_snapshot | Redis + Cassandra | inventory.adjusted events |
| product_search_index | OpenSearch (later) | product.updated event |
| flash_sale_price_map | Redis | pricing.* events |
| daily_revenue | ClickHouse / Streams state | order.paid / order.canceled |

OLAP / Warehouse:
- fact_orders, fact_inventory_adjustments, dim_product, dim_date

No Dual Write Rule: Application writes only to Postgres; all projections built via Kafka streams or connectors.

## 6. Events (Authoritative)
| Event Type | Purpose | Partition Key |
|------------|---------|---------------|
| ecommerce.order.order.created.v1 | Start lifecycle | orderId |
| ecommerce.order.order.paid.v1 | Payment success | orderId |
| ecommerce.order.order.canceled.v1 | Compensation | orderId |
| ecommerce.order.order.fulfilled.v1 | Completion | orderId |
| ecommerce.inventory.stock.adjusted.v1 | Stock delta broadcast | productId |
| ecommerce.product.product.updated.v1 | Cache/search invalidation | productId |
| ecommerce.pricing.flash_sale.started.v1 | Broadcast sale | productId or saleId |
| ecommerce.webhook.delivery.failed.v1 | Alert operations | subscriptionId |

Canonical Payload (example order.created):
```
{
  "eventId": "...",
  "eventType": "ecommerce.order.order.created.v1",
  "occurredAt": "...",
  "producer": "order-service",
  "traceId": "...",
  "correlationId": "...",
  "schemaVersion": "1.0",
  "partitionKey": "ORDER-123",
  "payload": {
    "orderId": "ORDER-123",
    "userId": "USER-9",
    "totalAmount": 129.50,
    "currency": "USD",
    "items": [{"productId":"P1","qty":2,"price":25.00}]
  }
}
```

## 7. Caching Strategy
| Cache | Key | Policy | Invalidation |
|-------|-----|--------|--------------|
| Product read | product:{id} | Read-through | product.updated |
| Inventory | inventory:{productId} | Event-driven set | inventory.stock.adjusted |
| Order status ephemeral | order_status:{orderId} | Write-through on event | fulfillment/cancel remove |
| Flash sale price | flash_price:{productId} | Cache authority TTL | sale end event/TTL |
| GraphQL aggregated | gql:product:{id} | Short TTL (30s) | Same as underlying components |

## 8. Resilience & Retry Matrix
| Operation | Pattern | Limits |
|-----------|---------|--------|
| Payment SOAP | Exponential w/ jitter + circuit breaker | 5 attempts |
| Inventory Reserve gRPC | Exponential (bounded) | 3 attempts |
| Webhook dispatch | Progressive schedule + DLQ | 5 attempts |
| Event publish | Async retry + DLQ fallback | configurable |
| Flash sale price update | Fast fail (no retry) | propagate error upward |
| MQTT ingestion | Buffer & batch after reconnect | device-level QoS simulation |

## 9. Security (Domain-Specific)
- Auth: JWT required on all mutations.
- Authorization: Customer may cancel only PENDING orders they own; OPA policy.
- Sensitive actions (price override) require ADMIN role.
- Idempotency: Hash Idempotency-Key + payload; reject duplicates within 24h window.
- Payment tokenization future: integrate Vault transit for card token (learning optional).

## 10. Observability Targets
Metrics:
- orders_created_total
- order_creation_latency_ms (histogram)
- inventory_reservation_failures_total
- webhook_retry_attempts_total
- product_cache_hit_ratio
Traces:
- POST /orders → gRPC ReserveStock → Kafka publish sequence
Logs:
- Correlation: orderId, traceId, userId, eventType

## 11. Testing Matrix
| Layer | Focus | Tooling |
|-------|-------|---------|
| Unit | Validation (SKU uniqueness) | JUnit |
| Integration | DB + Kafka + Redis | Testcontainers |
| Contract | REST (product/order), gRPC (inventory) | Pact / protobuf golden |
| BDD | Checkout flow | Cucumber |
| Performance | Order create p95 < 200ms | Gatling |
| Security | AuthZ tests (cancel path) | Spring Test + OPA test harness |
| Fuzz | Order JSON parser | Jazzer |
| Chaos (later) | Kill inventory pod mid-reserve | Chaos Mesh |

## 12. Implementation Phases
| Phase | Deliverables |
|-------|--------------|
| 1 | Product + Cart (REST + Postgres + basic tests) |
| 2 | Order + Inventory gRPC stub + Kafka events |
| 3 | WebSocket notifications + Redis caching |
| 4 | Payment SOAP + Partner webhooks + flash sale SSE |
| 5 | Pricing service + Kafka Streams metrics + CDC |
| 6 | IoT MQTT ingestion (inventory adjustments) |
| 7 | Cassandra projections + OpenSearch indexing |
| 8+ | DR replay + advanced resilience |

## 13. Interoperability Checklist (Before Declaring Stable)
- [ ] All events validated vs schema registry
- [ ] GraphQL fields do not leak internal table names
- [ ] gRPC proto version pinned & published
- [ ] REST endpoints documented with status codes & error model
- [ ] Cache invalidation tied to event consumption only (no side-channels)
- [ ] Idempotency semantics documented & test present
- [ ] Replay procedure tested on sample dataset
- [ ] Security (OPA) denies invalid cancellation scenario

## 14. Backlog Seed (Chronological by Complexity)
1. Product CRUD + migrations + unit tests
2. Order creation + event envelope lib usage
3. Inventory gRPC proto + in-memory stub
4. Redis product cache + invalidation test
5. WebSocket notification skeleton
6. Payment adapter mock + SOAP client stub
7. Webhook dispatcher + retry queue (RabbitMQ)
8. Pricing flash sale event emission
9. Kafka Streams order revenue aggregation
10. Debezium CDC capture for orders/products
11. Cassandra orders_by_customer projection
12. Replay CLI skeleton
13. OpenSearch indexing pipeline

## 15. Cost Controls
- Defer Cassandra & OpenSearch until after stable events (Phase 5+).
- Use single-broker Kafka or Redpanda early.
- Run SOAP + RabbitMQ only when working that phase (compose profile).
- Edge resources (ingress/gateway) consolidated early to one load balancer.

## 16. Risks & Mitigations
| Risk | Mitigation |
|------|------------|
| Event schema churn | Freeze MVP schema early; additive evolution only |
| Cache staleness bugs | Integration tests with consumer-driven expectations |
| Payment circuit thrashing | Configure conservative sliding window for breaker |
| Webhook backlog growth | DLQ monitoring & alert threshold |

## 17. Exit Criteria for Domain “MVP Complete”
- Order→Notification real-time path traced
- Stock adjustment via event updates inventory snapshot
- Payment failure path triggers retries & circuit open
- Replay reconstructs orders_by_customer with parity
- GraphQL resolved aggregated product + inventory
