# BitVelocity Requirements Gathering & Analysis Guide

## Overview
Structured approach for gathering and analyzing requirements using Domain-Driven Design (DDD) principles. This guide ensures requirements are clear, testable, and properly specify event contracts before development begins.

---

## 1. Domain Exploration

### 1.1 Identify Bounded Context
Define the business capability boundary:

```markdown
## Order Management Bounded Context

**Responsibility**: Manage customer orders from creation through fulfillment

**Key Entities**:
- Order (aggregate root)
- LineItem (child entity)
- Customer (external reference)
- Inventory (external reference)

**Business Rules**:
- Order requires ≥1 item
- Inventory must be reserved before order creation
- Order status: Pending → Active → Fulfilled → Cancelled
```

### 1.2 Build Ubiquitous Language
Common vocabulary across team:

```markdown
| Business Term | Definition | Example |
|---|---|---|
| Order | Customer's instruction to purchase items | ORD-2024-00001 |
| LineItem | Single product in an order | 2x Widget Type-A |
| Reservation | Inventory held for order | RES-INV-00042 |
| Fulfillment | Shipment of order items | FUL-2024-00042 |
```

### 1.3 Map External Dependencies
Services this context depends on and is depended on:

```markdown
## Dependency Map

**Outbound** (this service calls):
- inventory-service: CheckStock, ReserveStock, ReleaseStock
- customer-service: ValidateCustomer, GetCustomerDimensions
- payment-service: AuthorizePayment, CapturePayment

**Inbound** (services call this):
- shipping-service: GetOrder, UpdateFulfillmentStatus
- analytics-service: Subscribe to OrderCreated, OrderFulfilled events
- notification-service: Subscribe to OrderConfirmed, OrderShipped events
```

### 1.4 State Machine Definition
Order lifecycle as state transitions:

```
         ┌─────────────┐
         │   PENDING   │
         └──────┬──────┘
                │ (ReserveStock + AuthorizePayment)
         ┌──────▼──────┐
         │   ACTIVE    │
         └──────┬──────┘
           │    │    │
    ┌──────▘    │    └──────┐
    │           │           │
┌───▼──┐    ┌───▼───┐   ┌───▼────┐
│CANCEL│    │FULFILL│   │TIMEOUT │
└──────┘    └───────┘   └────────┘
```

---

## 2. Requirements Analysis Framework

### 2.1 Functional Requirements (FRs)
What the system **must do**:

```markdown
## Order Service Functional Requirements

### FR-1: Create Order
- **Trigger**: Customer submits order request
- **Precondition**: Customer logged in, cart has items
- **Main Flow**:
  1. Validate customer account
  2. Check inventory availability
  3. Check payment authorization
  4. Create order in PENDING state
  5. Emit OrderCreated event
- **Postcondition**: Order created, inventory reserved, customer notified
- **Error Handling**: If reservation fails, return 409 Conflict

### FR-2: Cancel Order
- **Trigger**: Customer/Support cancels order
- **Precondition**: Order in PENDING or ACTIVE state
- **Main Flow**:
  1. Release inventory reservation
  2. Reverse payment authorization
  3. Set order to CANCELLED state
  4. Emit OrderCancelled event
- **Postcondition**: Inventory released, funds not charged

### FR-3: Get Order Details
- **Trigger**: Customer views order
- **Precondition**: Order exists
- **Response**: Full order with items, status, timeline
- **SLO**: Respond in <100ms
```

### 2.2 Non-Functional Requirements (NFRs)
How the system should **behave**:

```markdown
## Performance & Scalability

**Latency**:
- CreateOrder: p95 < 200ms (includes inventory check)
- GetOrder: p95 < 100ms
- ListOrders: p95 < 500ms for 1000 items

**Throughput**:
- Test with 100 concurrent users
- Minimum 100 orders/sec throughput
- Peak sustained load: 500 orders/sec for 2 hours

**Availability**:
- 99.9% uptime SLO
- Circuit breaker for inventory service (fallback: reject orders)
- Auto-recovery from pod restart

**Data Consistency**:
- Order state machine is source of truth
- Inventory reservation is eventual consistent
- Payment capture is synchronous (blocking)

**Security**:
- Orders visible only to customer and support
- All mutations logged with user ID
- Payment data never logged
- PII excluded from events

**Database**:
- Orders table indexed by (customerId, createdAt)
- 50GB estimated size at 10M orders
- Retention: 7 years (compliance)
```

---

## 3. User Story Decomposition

### 3.1 Epic → Story → Task Hierarchy

```markdown
## Epic: Checkout Experience

### Story 1: Create Order from Cart
**Priority**: P0 (Critical path)

**Scenario 1.1: Happy Path**
```gherkin
Given customer has items in cart
When customer submits order
Then order is created in PENDING state
And inventory is reserved
And payment is authorized
And OrderCreated event is emitted
```

**Scenario 1.2: Insufficient Inventory**
```gherkin
Given cart has 5 Widget-A
And inventory has only 3 Widget-A
When customer submits order
Then order is NOT created
And error "Insufficient stock for Widget-A (need 5, have 3)" is returned
```

**Scenario 1.3: Payment Declined**
```gherkin
Given inventory is available
And payment gateway declines card
When customer submits order
Then order is NOT created
And error "Payment declined" is returned
And inventory is not reserved
```

**Tasks**:
- [ ] Task 1: Add reserveInventory() RPC call to order-service
- [ ] Task 2: Add authorizePayment() RPC call to payment-service
- [ ] Task 3: Implement CreateOrderRequest validation
- [ ] Task 4: Implement state machine transition PENDING
- [ ] Task 5: Emit OrderCreated event with required fields
- [ ] Task 6: Add instrumentation for latency tracking
- [ ] Task 7: Write integration tests with Testcontainers
- [ ] Task 8: Add metrics/alerts for p95 latency

### Story 2: Cancel Order
**Priority**: P1 (Nice to have)

**Scenario 2.1: Cancel in PENDING**
```gherkin
Given order in PENDING state
When support cancels order
Then inventory reservation is released
And payment authorization is reversed
And order moved to CANCELLED state
And OrderCancelled event emitted
```

**Tasks**:
- [ ] Task 1: Add releaseReservation() call
- [ ] Task 2: Add reverseAuthorization() call
- [ ] Task 3: Implement state machine transition
- [ ] Task 4: Emit OrderCancelled event
```

### 3.2 Definition of Done Checklist

For **each story/task** completion verify:

```markdown
## Definition of Done

**Code**:
- [ ] Code review approved by 1 architect
- [ ] Unit test coverage ≥ 80%
- [ ] Integration tests with real databases (Testcontainers)
- [ ] Contract tests match event schema

**Quality**:
- [ ] No checkstyle violations
- [ ] No security warnings (OWASP scan)
- [ ] No new PII in logs/events
- [ ] Performance within SLO (p95 latency)

**Documentation**:
- [ ] Code comments on business logic
- [ ] Event contract documented
- [ ] API docs updated (Swagger/OpenAPI)
- [ ] ADR created if architectural decision

**Testing**:
- [ ] Manual smoke test on dev environment
- [ ] Integration test passes with docker-compose
- [ ] Contract tests with downstream services pass

**Deployment**:
- [ ] CI/CD pipeline green (all checks pass)
- [ ] Ready for staging deployment
```

---

## 4. Event Specification

Define **what happened** at service boundaries:

### 4.1 Event Naming Convention

```
<domain>.<context>.<entity>.<event_type>.v<major_version>

Example: ecommerce.order.order.created.v1
```

### 4.2 Event Contract Template

```json
{
  "name": "ecommerce.order.order.created.v1",
  "description": "Emitted when customer successfully creates order",
  "category": "business_event",
  "source_service": "order-service",
  "consumers": [
    "shipping-service (fulfillment planning)",
    "notification-service (email receipt)",
    "analytics-service (reporting)"
  ],
  "schema": {
    "type": "object",
    "properties": {
      "orderId": {"type": "string", "pattern": "^ORD-[0-9]{4}-[0-9]{5}$"},
      "customerId": {"type": "string", "pattern": "^CUST-[0-9]+$"},
      "totalAmount": {"type": "number", "minimum": 0.01},
      "lineItems": {
        "type": "array",
        "items": {
          "properties": {
            "productId": {"type": "string"},
            "quantity": {"type": "integer", "minimum": 1},
            "unitPrice": {"type": "number"}
          }
        }
      },
      "createdAt": {"type": "string", "format": "date-time"},
      "shippingAddress": {"type": "string"},
      "_metadata": {
        "correlationId": {"type": "string"},
        "timestamp": {"type": "string", "format": "date-time"}
      }
    },
    "required": ["orderId", "customerId", "totalAmount", "lineItems", "createdAt"],
    "additionalProperties": false
  },
  "pii_check": {
    "fields_excluded": ["shippingAddress (PII)"],
    "allowed_fields": ["orderId", "customerId", "amounts", "timestamps"]
  }
}
```

### 4.3 Event Versioning Strategy

```markdown
## Version Evolution

### v1 (Current)
- orderId, customerId, totalAmount, lineItems, createdAt

### v2 (Planned)
- Add: discountCode, promoId, shippingMethodId
- Maintain backwards compatibility

## Version Support Window
- v1: Deprecated after 6 months (v2 release)
- v1: Removed after 12 months
- v2: Supported for 18 months

## Migration Path
1. Services emit BOTH v1 and v2 events (3 months)
2. All consumers migrated to v2
3. v1 events stopped
```

---

## 5. API Contract Definition

### 5.1 REST API Contract

```yaml
POST /api/v1/orders:
  description: Create new order
  requestBody:
    required: true
    content:
      application/json:
        schema:
          type: object
          required: [customerId, lineItems]
          properties:
            customerId:
              type: string
              pattern: "^CUST-[0-9]+$"
            lineItems:
              type: array
              minItems: 1
              items:
                type: object
                required: [productId, quantity]
                properties:
                  productId: {type: string}
                  quantity: {type: integer, minimum: 1}
  responses:
    201:
      description: Order created successfully
      content:
        application/json:
          schema:
            type: object
            properties:
              orderId: {type: string}
              status: {enum: [PENDING]}
              createdAt: {type: string, format: date-time}
    400:
      description: Invalid request (validation error)
    409:
      description: Conflict (insufficient inventory)
    500:
      description: Internal server error

GET /api/v1/orders/{orderId}:
  parameters:
    - name: orderId
      in: path
      required: true
      schema: {type: string}
  responses:
    200:
      description: Order found
    404:
      description: Order not found
    403:
      description: Not authorized to view order
```

### 5.2 gRPC Service Contract

```protobuf
service OrderService {
  rpc CreateOrder(CreateOrderRequest) returns (CreateOrderResponse) {}
  rpc GetOrder(GetOrderRequest) returns (Order) {}
  rpc CancelOrder(CancelOrderRequest) returns (CancelOrderResponse) {}
}

message CreateOrderRequest {
  string customer_id = 1; // required
  repeated LineItem line_items = 2; // required, minItems=1
  string correlation_id = 3; // for tracing
}

message CreateOrderResponse {
  string order_id = 1;
  OrderStatus status = 2;
  google.protobuf.Timestamp created_at = 3;
}
```

---

## 6. Performance & Scalability Requirements

### 6.1 Load Profile

```yaml
users:
  daily_active_users: 100000
  peak_concurrent_users: 10000
  peak_hours: "8am-10am, 12pm-1pm, 6pm-8pm"

transactions:
  orders_per_day: 50000
  avg_orders_per_second: 0.58
  peak_orders_per_second: 500

growth:
  yoy_growth_rate: 1.5x (50% growth per year)
  peak_day_estimate_24m: 75000 orders
```

### 6.2 SLI/SLO Definition

```yaml
# Service Level Indicators & Objectives

endpoints:
  CreateOrder:
    latency_sli:
      p50: 50ms
      p95: 200ms
      p99: 500ms
    slo: "p95 < 200ms for 99.9% of requests"
    
    error_rate_sli: 0.1%
    slo: "error_rate < 0.1% (99.9% success)"
    
    availability_slo: 99.9%

  GetOrder:
    latency_sli:
      p50: 20ms
      p95: 100ms
      p99: 250ms
    slo: "p95 < 100ms for 99.95% of requests"

database:
  response_time: p95 < 50ms
  connection_pool: 50 connections
  storage_estimate: 500MB per 1M orders
```

---

## 7. Requirements Validation Checklist

Before development starts, verify:

```markdown
## Pre-Development Review

**Completeness**:
- [ ] All user stories have acceptance criteria
- [ ] Happy path AND error cases specified
- [ ] Edge cases identified (empty cart, max quantity, etc.)
- [ ] Data format/constraints documented

**Testability**:
- [ ] Requirements can be automated (Cucumber, unit tests)
- [ ] Success/failure criteria are measurable
- [ ] Performance targets are quantified
- [ ] Security requirements are testable

**Design Feasibility**:
- [ ] External dependencies identified
- [ ] Synchronous vs async calls determined
- [ ] Circuit breaker strategy defined
- [ ] Fallback behavior specified

**Event Contracts**:
- [ ] Event schema is complete
- [ ] PII fields identified and excluded
- [ ] Versioning strategy clear
- [ ] Consumers identified

**Performance**:
- [ ] SLI/SLO targets are realistic
- [ ] Load profile data is current
- [ ] Database scaling plan exists
- [ ] Caching strategy identified (if needed)

**Documentation**:
- [ ] Bounded context clearly defined
- [ ] State machine diagram provided
- [ ] Dependency map complete
- [ ] All terms in ubiquitous language documented
```

---

## 8. Requirements Document Template

Use this template for **every new feature**:

```markdown
# Feature: [Feature Name]

## Overview
[2-3 sentence description of what this feature delivers]

## Business Motivation
[Why are we building this? Business value, market opportunity]

## Bounded Context
- **Name**: [Context name]
- **Responsibility**: [Single responsibility]
- **Aggregate Root**: [Primary entity]

## Functional Requirements

### FR-1: [Requirement Name]
- **Trigger**: [What causes this]
- **Precondition**: [System state before]
- **Main Flow**: 
  1. [Step 1]
  2. [Step 2]
- **Postcondition**: [System state after]
- **Error Case**: [What if something fails]

## Non-Functional Requirements

**Performance**:
- [Latency targets]
- [Throughput requirements]

**Availability**:
- [Uptime SLO]
- [Disaster recovery approach]

**Security**:
- [Authentication/Authorization]
- [Data protection]
- [PII handling]

## Event Contracts
- [Event name and schema]
- [Event consumers]

## API Contracts
- [Endpoint definitions]
- [Request/Response schemas]

## User Stories

### Story 1: [Story Title]
[Acceptance criteria in Gherkin format]

## Definition of Done
[Link to standard DoD checklist]

## Validation Checklist
[Verify all items before coding]
```

---

## 9. Requirements Elicitation Techniques

### 9.1 User Interview Template

```markdown
## Interview Questions

1. **Process**: "Walk me through how you currently [do this task]"
   - Listen for pain points, errors, workarounds
   
2. **Volume**: "How often do you [action]? Peak times?"
   - Understand frequency and load profile
   
3. **Failure**: "What happens if [system fails]?"
   - Identify criticality and fallback needs
   
4. **Integration**: "What other systems depend on [this]?"
   - Map dependencies
   
5. **Metrics**: "How do you measure success?"
   - Define success criteria before coding
```

### 9.2 Acceptance Criteria Template

```gherkin
Feature: Order Management
  
  Scenario: Customer successfully creates order
    Given customer has logged in
    And cart contains 2 widgets
    And payment method is valid
    When customer clicks "Create Order"
    Then order should be created in PENDING state
    And inventory reservation should be confirmed
    And payment should be authorized
    And customer should receive confirmation email
    And order ID should be displayed
```

---

## References

- **BitVelocity Docs**: `BitVelocity-Docs/docs/00-OVERVIEW/README.md`
- **Event Contracts Standard**: `BitVelocity-Docs/docs/event-contracts/README.md`
- **DDD Patterns**: Evans, E. (2003). Domain-Driven Design
- **User Stories**: Cohn, M. (2004). User Stories Applied
