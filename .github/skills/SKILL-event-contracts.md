# Skill: Managing Event Contracts in BitVelocity

## Purpose
Create, update, version, and validate event contracts following BitVelocity conventions and ensuring cross-domain integration consistency.

## When to Use This Skill  
- Creating a new domain event to be published by a service
- Updating an existing event schema
- Validating event contracts in tests
- Managing event versioning and backward compatibility
- Publishing/consuming events across domain boundaries
- Adding PII lint checks for event contracts

---

## Step 1: Event Contract Design

### 1.1 Event Naming Convention

**Format**: `<domain>.<context>.<entity>.<eventType>.v<majorVersion>`

**Rules**:
- Use **snake_case** for multi-word components
- Include **domain** (ecommerce, chat, iot, social, security)
- Include **context** (bounded context or service name)
- Include **entity** (what domain object changed)
- Include **eventType** (created, updated, deleted, completed, failed, etc.)
- Increment **major version** on breaking changes only

**Examples**:
| Event | Domain | Context | Entity | Type | Version |
|-------|--------|---------|--------|------|---------|
| `ecommerce.orders.order.created.v1` | ecommerce | orders | order | created | 1 |
| `ecommerce.payments.payment.completed.v2` | ecommerce | payments | payment | completed | 2 |
| `chat.messaging.message.sent.v1` | chat | messaging | message | sent | 1 |
| `iot.devices.device.registered.v1` | iot | devices | device | registered | 1 |

### 1.2 Event Category Classification

**Persist Event**: Service state changed
- `order.created` - New order in system
- `payment.completed` - Payment processed
- `user.registered` - New user account

**Signal Event**: External signal received  
- `webhook.received` - Payment gateway callback
- `device.data_received` - Sensor reading
- `message.acknowledged` - Chat confirmation

**Alert Event**: Something unexpected happened
- `order.payment_failed` - Payment declined
- `inventory.shortage` - Stock depleted
- `service.error` - Exception occurred

---

## Step 2: Create Event Schema File

### 2.1 File Location & Naming

**Path**: 
```
BitVelocity-Docs/docs/event-contracts/
  [domain]/
    [service]/
      [entity].[action].v[major].[minor].json
```

**Example**:
```
BitVelocity-Docs/docs/event-contracts/
  ecommerce/
    order-service/
      order.created.v1.0.json
      order.cancelled.v1.0.json
      payment.completed.v2.0.json
```

### 2.2 JSON Schema Template

**File**: `order.created.v1.json`

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Order Created",
  "description": "Published when a customer creates a new order",
  "type": "object",
  "examples": [
    {
      "orderId": "ORD-2024-00001",
      "customerId": "550e8400-e29b-41d4-a716-446655440000",
      "items": [
        {
          "productId": "SKU-001",
          "quantity": 2,
          "unitPrice": 49.99
        }
      ],
      "totalAmount": 99.98,
      "currency": "USD",
      "timestamp": "2024-01-15T10:30:00Z",
      "version": "1.0"
    }
  ],
  "required": [
    "orderId",
    "customerId",
    "totalAmount",
    "currency",
    "timestamp",
    "version"
  ],
  "properties": {
    "orderId": {
      "type": "string",
      "description": "Unique order identifier",
      "pattern": "^[A-Z0-9-]{10,}$"
    },
    "customerId": {
      "type": "string",
      "description": "UUID of the customer",
      "format": "uuid"
    },
    "items": {
      "type": "array",
      "description": "List of ordered items",
      "minItems": 1,
      "items": {
        "type": "object",
        "required": ["productId", "quantity"],
        "properties": {
          "productId": {
            "type": "string",
            "description": "SKU or product ID"
          },
          "quantity": {
            "type": "integer",
            "minimum": 1
          },
          "unitPrice": {
            "type": "number",
            "minimum": 0
          }
        }
      }
    },
    "totalAmount": {
      "type": "number",
      "description": "Order total including tax",
      "minimum": 0,
      "multipleOf": 0.01
    },
    "currency": {
      "type": "string",
      "description": "ISO 4217 currency code",
      "minLength": 3,
      "maxLength": 3,
      "pattern": "^[A-Z]{3}$"
    },
    "timestamp": {
      "type": "string",
      "description": "When order was created (ISO 8601)",
      "format": "date-time"
    },
    "version": {
      "type": "string",
      "description": "Schema version",
      "const": "1.0"
    }
  },
  "additionalProperties": false,
  "comments": {
    "design_rationale": "Customers uniquely identified by UUID, orders by order ID. No PII (no email, phone). Structured items list for inventory reconciliation.",
    "consumers": [
      "payment-service: Authorizes payment",
      "notification-service: Sends confirmation email",
      "analytics-service: Tracks order metrics"
    ],
    "published_by": "order-service"
  }
}
```

### 2.3 Schema Design Guidelines

**MUST Have**:
- ✅ `type: "object"` root
- ✅ `required: []` listing all mandatory fields
- ✅ `properties: {}` for each field with `description`
- ✅ `additionalProperties: false` (no unexpected fields)
- ✅ `examples: []` with realistic sample data
- ✅ `version: { const: "X.Y" }` field

**MUST NOT Have**:
- ❌ PII fields (email, phone, ssn, firstName, lastName, address)
- ❌ Internal system IDs (database row IDs) - use business IDs
- ❌ Passwords, tokens, API keys
- ❌ Unbounded arrays or strings (set maxLength, maxItems)
- ❌ Numeric values without min/max constraints

**Best Practices**:
- Use **UUIDs** for cross-domain references (customerId)
- Use **ISO 8601** for timestamps with timezone
- Use **enums** for status/category fields
- Use **multipleOf** for monetary amounts (0.01 for cents)
- Provide **description** on every field
- Include **format** hints (date-time, uuid, email, etc.)

---

## Step 3: Event Versioning Strategy

### 3.1 When to Increment Version

**MAJOR Version** (breaking change, v2.0):
- Remove a required field
- Change field type (string → number)
- Change field format (uuid → custom format)
- Restructure nested objects

**Example**: `order.created.v2.json`
```json
{
  "properties": {
    "orderId": { /* stays same */ },
    "customerId": { /* CHANGED: now string instead of uuid */ },
    "items": { /* stays same */ },
    "totalAmount": { /* stays same */ },
    "timestamp": { /* stays same */ },
    "version": { "const": "2.0" },
    // "currency" field REMOVED - breaking change!
  }
}
```

**MINOR Version** (backward compatible):
- Add optional field (doesn't break existing consumers)
- Deprecate field (keep but mark as obsolete)
- Loosen a constraint (e.g., allow longer string)

**Example**: `order.created.v1.1.json` or `order.created.v1.json`  (update in place)
```json
{
  "properties": {
    "orderId": { /* same */ },
    "customerId": { /* same */ },
    "items": { /* same */ },
    "totalAmount": { /* same */ },
    "currency": { "type": "string" },  // ADDED - optional
    "timestamp": { /* same */ },
    "version": { "const": "1.0" },  // Still 1.0!
    "shippingAddress": { /* NEW optional */ }
  },
  "required": [  /* currency NOT required */
    "orderId", "customerId", "totalAmount", "timestamp", "version"
  ]
}
```

### 3.2 Version Support Window

- **During Rollout**: Support **2 versions simultaneously**
  - Old publishers can still send v1
  - New publishers send v2
  - Consumers handle both
- **After Rollout** (v+1 released): Stop accepting v-1 events after 1 month
- **Deprecation Notice**: Update event contact 30 days before discontinuing

### 3.3 Compatibility Test

Create test to validate new version is compatible:

```java
@Test
void v1_EventShouldBeValidAgainstV2Schema() throws Exception {
  // Load v1 event
  String v1Event = """
    {
      "orderId": "ORD-001",
      "customerId": "550e8400-e29b-41d4-a716-446655440000",
      "totalAmount": 99.98,
      "timestamp": "2024-01-15T10:30:00Z",
      "version": "1.0"
    }
  """;
  
  // Validate against v2 schema (should fail: currency is now required)
  JsonSchema v2Schema = getSchema("order.created.v2.json");
  ProcessingReport report = v2Schema.validate(objectMapper.readTree(v1Event));
  
  // Either v2 accepts v1, OR you need migration logic
  if (!report.isSuccess()) {
    log.warn("v1 → v2 not backward compatible, need migration");
  }
}
```

---

## Step 4: Service Integration - Publishing Events

### 4.1 Define Publisher in Service

**File**: `src/main/java/com/bitvelo/[domain]/[service]/event/OrderEventPublisher.java`

```java
package com.bitvelo.[domain].[service].event;

import com.bitvelo.core.events.EventPublisher;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

@Slf4j
@Component
public class OrderEventPublisher {
  
  private final KafkaTemplate<String, String> kafkaTemplate;
  private final ObjectMapper objectMapper;
  private static final String TOPIC = "orders.order.created.v1";
  
  public OrderEventPublisher(KafkaTemplate<String, String> kafkaTemplate,
                            ObjectMapper objectMapper) {
    this.kafkaTemplate = kafkaTemplate;
    this.objectMapper = objectMapper;
  }
  
  public void publishOrderCreated(Order order) {
    try {
      OrderCreatedEvent event = OrderCreatedEvent.builder()
        .orderId(order.getOrderId())
        .customerId(order.getCustomerId())
        .totalAmount(order.getTotalAmount())
        .currency(order.getCurrency())
        .timestamp(OffsetDateTime.now())
        .version("1.0")
        .build();
      
      String payload = objectMapper.writeValueAsString(event);
      
      kafkaTemplate.send(TOPIC, order.getOrderId(), payload);
      log.info("Published order.created event for orderId={}", order.getOrderId());
      
    } catch (Exception e) {
      log.error("Failed to publish order.created event", e);
      // Decide: fail fast or queue for retry?
      throw new EventPublishingException("Could not publish order event", e);
    }
  }
}
```

### 4.2 Event DTO Class

**File**: `src/main/java/com/bitvelo/[domain]/[service]/event/OrderCreatedEvent.java`

```java
package com.bitvelo.[domain].[service].event;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OrderCreatedEvent {
  
  @JsonProperty("orderId")
  private String orderId;
  
  @JsonProperty("customerId")
  private String customerId;
  
  @JsonProperty("items")
  private java.util.List<OrderItem> items;
  
  @JsonProperty("totalAmount")
  private BigDecimal totalAmount;
  
  @JsonProperty("currency")
  private String currency;
  
  @JsonProperty("timestamp")
  private OffsetDateTime timestamp;
  
  @JsonProperty("version")
  private String version;
}
```

### 4.3 Call Publisher from Service

Update `OrderService.java`:

```java
@Service
public class OrderService {
  
  private final OrderRepository orderRepository;
  private final OrderEventPublisher eventPublisher;
  
  @Transactional
  public Order createOrder(CreateOrderRequest request) {
    // Create and save order...
    Order saved = orderRepository.save(order);
    
    // Publish event
    eventPublisher.publishOrderCreated(saved);
    
    return saved;
  }
}
```

---

## Step 5: Service Integration - Consuming Events

### 5.1 Define Listener

**File**: `src/main/java/com/bitvelo/[domain]/[service]/event/PaymentCompletedListener.java`

```java
package com.bitvelo.[domain].[service].event;

import com.bitvelo.[domain].[service].service.OrderService;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.rebalance.ConsumerSeekToCurrentErrorHandler;
import org.springframework.stereotype.Component;

@Slf4j
@Component
public class PaymentCompletedListener {
  
  private final OrderService orderService;
  private final ObjectMapper objectMapper;
  
  public PaymentCompletedListener(OrderService orderService,
                                 ObjectMapper objectMapper) {
    this.orderService = orderService;
    this.objectMapper = objectMapper;
  }
  
  @KafkaListener(
    topics = "orders.payment.completed.v1",
    groupId = "orders-service",
    errorHandler = "ConsumerSeekToCurrentErrorHandler"
  )
  public void onPaymentCompleted(String message) {
    try {
      PaymentCompletedEvent event = objectMapper.readValue(
        message,
        PaymentCompletedEvent.class
      );
      
      log.info("Received payment.completed for orderId={}", event.getOrderId());
      
      // Update order status
      orderService.markOrderAsPaid(
        event.getOrderId(),
        event.getTransactionId()
      );
      
    } catch (Exception e) {
      log.error("Failed to process payment.completed event: {}", message, e);
      // Failed message handling: send to DLQ or log
      throw new EventProcessingException("Cannot process payment event", e);
    }
  }
}
```

---

## Step 6: Event Contract Validation in Tests

### 6.1 Schema Validation Test

**File**: `src/test/java/com/bitvelo/[domain]/[service]/event/OrderEventIntegrationTest.java`

```java
@SpringBootTest
@Testcontainers
class OrderEventValidationTest {
  
  @Container
  static KafkaContainer kafka = new KafkaContainer();
  
  @Autowired
  private KafkaTemplate<String, String> kafkaTemplate;
  
  @Autowired
  private ObjectMapper objectMapper;
  
  @Test
  void shouldPublishOrderCreatedWithValidSchema() throws Exception {
    // Arrange
    Order order = new Order()
      .setOrderId("ORD-001")
      .setCustomerId("550e8400-e29b-41d4-a716-446655440000")
      .setTotalAmount(99.98f)
      .setCurrency("USD");
    
    OrderCreatedEvent event = OrderCreatedEvent.builder()
      .orderId(order.getOrderId())
      .customerId(order.getCustomerId())
      .totalAmount(new BigDecimal("99.98"))
      .currency("USD")
      .timestamp(OffsetDateTime.now())
      .version("1.0")
      .build();
    
    String eventJson = objectMapper.writeValueAsString(event);
    
    // Act - Validate against schema
    JsonSchema schema = loadSchemaFromFile(
      "BitVelocity-Docs/docs/event-contracts/ecommerce/order-service/order.created.v1.json"
    );
    
    // Assert
    ProcessingReport report = schema.validate(
      objectMapper.readTree(eventJson)
    );
    
    assertThat(report.isSuccess())
      .withFailMessage(report.toString())
      .isTrue();
  }
  
  @Test
  void shouldNotContainPIIFields() throws Exception {
    // Validate no email, phone, names, addresses
    OrderCreatedEvent event = /* ... */;
    String eventJson = objectMapper.writeValueAsString(event);
    JsonNode root = objectMapper.readTree(eventJson);
    
    List<String> piiFields = List.of(
      "email", "phone", "firstName", "lastName", "address", "ssn"
    );
    
    piiFields.forEach(field -> {
      assertThat(root.has(field))
        .as("Event should not contain PII field: " + field)
        .isFalse();
    });
  }
}
```

### 6.2 Linting Gradle Task (Optional)

Create `lint-events.gradle`:

```gradle
task lintEventContracts {
  doLast {
    fileTree("BitVelocity-Docs/docs/event-contracts").eachFile { file ->
      if (file.name.endsWith('.json')) {
        // Check for PII patterns in schema
        def content = file.text
        def piiPatterns = ['email', 'phone', 'firstName', 'lastName', 'ssn']
        piiPatterns.each { pattern ->
          if (content.contains("\"$pattern\"")) {
            println("WARNING: Potential PII in ${file.path}")
          }
        }
      }
    }
  }
}
```

---

## Step 7: Documentation in Service README

Update `[service]-README.md`:

```markdown
## Events

### Published Events

#### order.created (v1.0)
- **Schema**: `BitVelocity-Docs/docs/event-contracts/ecommerce/order-service/order.created.v1.json`
- **Trigger**: POST /orders succeeds
- **Consumers**: PaymentService, NotificationService, AnalyticsService
- **Payload**:
  - orderId (string): Unique order ID
  - customerId (UUID): Customer reference
  - totalAmount (decimal): Order total
  - currency (string): ISO 4217 code
  - timestamp (ISO 8601): Creation time
- **Notes**: No PII included; ordered item details in order object, not event

### Consumed Events

#### payment.completed (v1.0)
- **Source**: PaymentService
- **Schema**: `BitVelocity-Docs/docs/event-contracts/ecommerce/payment-service/payment.completed.v1.json`
- **Handler**: Updates order status to PAID
- **Topic**: orders.payment.completed.v1

## Event Versioning

- Current schema versions: order.created.v1.0, payment.completed.v1.0
- Support window: Current + 1 prior version (2 versions)
- Deprecation notice: Given 30 days before discontinuing
```

---

## Step 8: Update Event Contracts Directory

Create `BitVelocity-Docs/docs/event-contracts/[domain]/[service]/README.md`:

```markdown
# [Domain] - [Service] Event Contracts

## Overview
Events published and consumed by the [Service Name].

## Published Events

### order.created.v1 (Active)
- Location: `order.created.v1.json`
- Published when: Customer creates a new order
- Primary consumers: Payment Service, Notification Service
- Last updated: 2024-01-15

## Consumed Events

### payment.completed.v1 (Active)
- From: payment-service
- Location: (external reference)
- Handler: Updates order status

## Deprecation Log

### order.created.v2 (Deprecated)
- Discontinued: 2024-06-01
- Reason: Removed currency field
- Migration: See v2→v3 guide
```

---

## Step 9: Include in CI/CD Pipeline

Add to `.github/workflows/validate-events.yml`:

```yaml
name: Validate Event Contracts

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Validate Event Schemas
        run: |
          cd BitVelocity-Docs
          python scripts/validate_event_schemas.py \
            docs/event-contracts
      
      - name: Check for PII Leakage
        run: |
          python scripts/lint_event_contracts.py \
            docs/event-contracts
      
      - name: Test Event Contract Compliance
        run: |
          cd bv-ecommerce-core
          ./mvnw test -Dtest=*EventValidation*
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Event not published | Check Kafka config, verify topic exists, check logs for serialization error |
| Consumer not receiving | Verify consumer group offset, check Kafka topic partitions |
| Schema validation fails | Print actual event JSON, compare against schema constraints |
| Version conflict | Downgrade producer to output v1 while consumer handles both v1 and v2 |
| PII detected in review | Remove field from schema, update all publishers, test backward compatibility |

---

## References

- **Event Contract Guide**: `BitVelocity-Docs/docs/event-contracts/README.md`
- **JSON Schema Docs**: https://json-schema.org/
- **Spring Kafka**: https://spring.io/projects/spring-kafka
- **Kafka Schema Registry**: https://docs.confluent.io/platform/current/schema-registry/
