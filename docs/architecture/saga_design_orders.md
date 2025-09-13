# Saga Design – Order Fulfillment
Version: 1.0  
Status: Draft  
Scope: Payment + Inventory + Notification orchestration

## 1. Business Flow (Simplified)
1. Customer places order.
2. Reserve inventory.
3. Authorize payment.
4. Finalize order (state = CONFIRMED).
5. Trigger fulfillment / notification.

Failure compensation:
- If inventory fails → order CANCELLED.
- If payment fails after inventory reserved → release inventory → CANCELLED.

## 2. Approaches
| Approach | Pros | Cons | When |
|----------|------|------|------|
| Choreography (events) | Loose coupling; easy initial | Harder global visibility; ordering complexity | Simple 3–4 steps |
| Orchestration (central saga) | Clear control, timeout handling | Central coordinator becomes dependency | Complex branching / retries |

Decision: Start with Choreography; evolve to Orchestrator after adding payment retries & fraud checks.

## 3. Choreography Flow (Events)
```
OrderService emits: order.created
InventoryService consumes → emits inventory.reserved or inventory.rejected
PaymentService consumes inventory.reserved → emits payment.authorized or payment.failed
OrderService consumes payment.* → updates state & emits order.confirmed or order.cancelled
```

Event Sequence Example:
1. `ecommerce.order.created.v1`
2. `inventory.reservation.requested.v1` (optional internal)
3. `inventory.reserved.v1`
4. `payment.authorization.requested.v1`
5. `payment.authorized.v1`
6. `ecommerce.order.confirmed.v1`

Failure:
1. `inventory.rejected.v1` → `ecommerce.order.cancelled.v1`
OR
2. `payment.failed.v1` → `inventory.release.requested.v1` → `inventory.released.v1` → `ecommerce.order.cancelled.v1`

## 4. Orchestrator Evolution
Introduce `OrderSagaService`:
- Maintains saga state machine (persist in Postgres table `order_saga`).
- Dispatches commands (gRPC or events).
- Handles timeouts (e.g., payment must respond in 30s).
- Issues compensation commands on failure.

State Table:
| order_id | saga_state | last_event | started_at | updated_at | timeout_at |
|----------|------------|------------|------------|------------|------------|

## 5. State Machine (High Level)
```
NEW -> PENDING_INVENTORY
PENDING_INVENTORY -> PENDING_PAYMENT (on inventory.reserved)
PENDING_INVENTORY -> CANCELLED (on inventory.rejected)
PENDING_PAYMENT -> CONFIRMED (on payment.authorized)
PENDING_PAYMENT -> COMPENSATING (on payment.failed)
COMPENSATING -> CANCELLED (after inventory.release confirmation)
```

## 6. Timeout Handling
- Inventory reservation timeout (e.g., 10s) triggers cancellation.
- Payment authorization timeout triggers compensation (release inventory).
Use scheduled executor or durable timer events (future: workflow engine).

## 7. Idempotency & Re-entrancy
Event handlers:
- Store processed event id in `saga_event_log`.
- If duplicate event arrives (delivery semantics at-least-once), ignore if already applied.

## 8. Observability
Metrics:
- `saga_orders_inflight`
- `saga_step_latency_seconds{step}`
- `saga_compensation_count`
Traces:
- Root span: order.saga
- Child spans per step (inventory.reserve, payment.auth, inventory.release)
Logging:
- Correlation via `orderId`, `sagaId`.

## 9. Failure Injection (Testing)
Chaos scenarios:
- Drop payment.auth response.
- Delay inventory.reserved beyond timeout.
- Emit duplicate payment.authorized.
Expected outcome: Saga transitions correct states & compensations trigger.

## 10. Data Model (Orchestrator Mode)
Table `order_saga`:
```sql
CREATE TABLE order_saga (
  order_id UUID PRIMARY KEY,
  saga_state TEXT NOT NULL,
  inventory_reserved BOOLEAN DEFAULT false,
  payment_authorized BOOLEAN DEFAULT false,
  compensation_initiated BOOLEAN DEFAULT false,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## 11. Migration Plan
1. Implement choreography events with clear domain boundaries.
2. Add metric: average steps per completed order.
3. Identify complexity threshold (e.g., add fraud check = orchestrator trigger).
4. Introduce orchestrator in parallel (shadow mode).
5. Flip primary control to orchestrator after validation.

## 12. Backlog Seeds
- Story: Implement inventory reserved/rejected events.
- Story: Payment service publishes authorized/failed.
- Story: Add compensation event inventory.release.requested.
- Story: Build saga metrics dashboard.
- Spike: Evaluate lightweight orchestration (Temporal vs custom).

## 13. Risks & Mitigation
| Risk | Mitigation |
|------|------------|
| Event storm / loops | Event naming & handler guard (state check) |
| Partial compensation failure | Dead-letter + manual reprocess tool |
| Orchestrator single point of failure | Stateless orchestrator with DB persistence |
| Duplicate events causing invalid transitions | Idempotency event log |

## 14. Future
- Replace custom orchestrator with Temporal / Cadence for durable timers and retries.
- Add outbox integration natively for orchestrator commands.

---