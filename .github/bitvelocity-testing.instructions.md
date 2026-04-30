# BitVelocity Testing & QA Strategies Guide

## Overview
Comprehensive testing guide covering unit, integration, contract, E2E, and performance testing using the test pyramid pattern: 70% unit tests, 20% integration tests, 5% contract tests, 5% E2E tests.

---

## 1. Test Strategy Overview

### 1.1 Test Pyramid

```
           E2E (5%)
        /          \
       / Contract    \
      / (5%)          \
     / Integration    \
    / (20%)            \
   /_ _ _ _ _ _ _ _ _ _ \
   Unit Tests (70%)
```

**Execution Speed**: 
- Unit: 1-10ms each (fast feedback)
- Integration: 100-500ms each (database operations)
- Contract: 200-1000ms each (service mocks)
- E2E: 2-10s each (full system)

**Total Test Suite**: <2 minutes from `mvn test`

### 1.2 Coverage Targets

```yaml
# Coverage targets per layer

Unit Tests:
  target: 80% code coverage
  focus: business logic, edge cases, error handling
  
Integration Tests:
  target: 60% coverage (subset of unit test paths)
  focus: database interactions, Kafka, external calls
  
Contract Tests:
  target: 100% of public APIs
  focus: request/response contracts
  
E2E Tests:
  target: 20 critical user journeys
  focus: happy path (one test per story)
```

### 1.3 Test Environment Setup

```bash
# Local development
mvn clean test  # Unit only
mvn verify      # Unit + Integration + Contract

# CI/CD Pipeline
./gradlew test                    # Unit only (fast)
./gradlew integrationTest         # Integration (slower)
./gradlew contractTest            # Contracts
./gradlew test -Dgroups=e2e       # E2E (optional in CI)
```

---

## 2. Unit Testing

### 2.1 Unit Test Structure (JUnit 5 + Mockito)

```java
@DisplayName("OrderService")
class OrderServiceTest {
  
  // Setup
  @Mock private InventoryClient inventoryClient;
  @Mock private PaymentClient paymentClient;
  @Mock private OrderRepository orderRepository;
  
  @InjectMocks private OrderService orderService;
  
  @BeforeEach
  void setup() {
    MockitoAnnotations.openMocks(this);
  }
  
  // Happy path test
  @DisplayName("should create order when inventory and payment available")
  @Test
  void createOrderSuccess() {
    // Arrange
    CreateOrderRequest request = new CreateOrderRequest(
      customerId = "CUST-001",
      items = List.of(
        new LineItem(productId = "SKU-A", quantity = 2)
      )
    );
    
    when(inventoryClient.reserve(any())).thenReturn(ReservationResponse.success());
    when(paymentClient.authorize(any())).thenReturn(AuthResponse.success());
    when(orderRepository.save(any())).thenReturn(new Order(orderId = "ORD-001"));
    
    // Act
    Order result = orderService.createOrder(request);
    
    // Assert
    assertThat(result.getOrderId()).isEqualTo("ORD-001");
    assertThat(result.getStatus()).isEqualTo(OrderStatus.PENDING);
    verify(inventoryClient).reserve(argThat(r -> r.getProductId().equals("SKU-A")));
    verify(paymentClient).authorize(any());
  }
  
  // Error case test
  @DisplayName("should reject order when inventory unavailable")
  @Test
  void createOrderInsufficientInventory() {
    // Arrange
    when(inventoryClient.reserve(any())).thenThrow(
      new InsufficientInventoryException("Need 2, have 1")
    );
    
    // Act & Assert
    assertThatThrownBy(() -> orderService.createOrder(request))
      .isInstanceOf(InsufficientInventoryException.class)
      .hasMessage("Need 2, have 1");
    
    verify(paymentClient, never()).authorize(any());  // Payment not attempted
  }
  
  // Edge case test
  @DisplayName("should validate order has minimum 1 item")
  @Test
  void createOrderEmptyCart() {
    CreateOrderRequest request = new CreateOrderRequest(
      customerId = "CUST-001",
      items = List.of()  // Empty
    );
    
    assertThatThrownBy(() -> orderService.createOrder(request))
      .isInstanceOf(ValidationException.class)
      .hasMessage("Order must have at least 1 item");
  }
}
```

### 2.2 Naming Convention

```java
// Pattern: methodName_condition_expectedResult

createOrder_validRequest_returnsOrder()
createOrder_emptyCart_throwsValidationException()
cancelOrder_activePending_releasesInventory()
getOrder_orderExists_returnsOrderData()
getOrder_orderNotFound_throws404()
```

### 2.3 Mocking Best Practices

```java
// ✅ Good: Mock external dependencies
@Mock private InventoryClient inventoryClient;
@InjectMocks private OrderService orderService;

// ❌ Avoid: Mocking domain objects
@Mock private Order order;  // DON'T - test real Order class

// ✅ Good: Use ArgumentCaptor for verification
ArgumentCaptor<CreateOrderRequest> captor = 
  ArgumentCaptor.forClass(CreateOrderRequest.class);
verify(inventoryClient).reserve(captor.capture());
CreateOrderRequest captured = captor.getValue();
assertThat(captured.getCustomerId()).isEqualTo("CUST-001");

// ✅ Good: Spy for partial mocking
OrderService spyService = spy(new OrderService(deps));
when(spyService.validateOrder(any())).thenReturn(true);
```

---

## 3. Integration Testing

### 3.1 Testcontainers Setup

```java
@DisplayName("OrderServiceIntegration")
@SpringBootTest
@Testcontainers  // Automatically manage containers
class OrderServiceIntegrationTest {
  
  // Static containers (shared across tests)
  @Container
  static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>()
    .withDatabaseName("orders_test")
    .withUsername("test")
    .withPassword("test")
    .withInitScript("db/init.sql");
  
  @Container
  static KafkaContainer kafka = new KafkaContainer(
    DockerImageName.parse("confluentinc/cp-kafka:7.4.0")
  );
  
  // Dependencies
  @Autowired private OrderRepository orderRepository;
  @Autowired private OrderService orderService;
  @Autowired private KafkaTemplate<String, OrderEvent> kafkaTemplate;
  @Autowired private TestcontainersProperties testProps;
  
  @BeforeEach
  void setup() {
    orderRepository.deleteAll();  // Clean state
  }
  
  // Integration test
  @DisplayName("should persist order to database")
  @Test
  void createOrderPersistsToDb() {
    // Arrange
    CreateOrderRequest request = new CreateOrderRequest(
      customerId = "CUST-001",
      items = List.of(new LineItem(productId = "SKU-A", quantity = 2))
    );
    
    // Act
    Order createdOrder = orderService.createOrder(request);
    
    // Assert - query database directly
    Order dbOrder = orderRepository.findById(createdOrder.getOrderId()).orElseThrow();
    assertThat(dbOrder.getStatus()).isEqualTo(OrderStatus.PENDING);
    assertThat(dbOrder.getLineItems()).hasSize(1);
  }
  
  // Kafka integration test
  @DisplayName("should emit OrderCreated event to Kafka")
  @Test
  void createOrderEmitsEvent() throws Exception {
    // Arrange
    var captor = KafkaTestUtils.getRecords(
      kafkaTemplate.getDefaultTopic(),
      100,  // timeout ms
      1     // expected records
    );
    
    // Act
    Order order = orderService.createOrder(request);
    
    // Assert
    assertThat(captor).hasSize(1);
    OrderCreatedEvent event = (OrderCreatedEvent) captor.get(0).value();
    assertThat(event.getOrderId()).isEqualTo(order.getOrderId());
  }
  
  // Transaction test
  @DisplayName("should rollback transaction if payment fails")
  @Test
  @Transactional
  void createOrderRollsBackOnPaymentFailure() {
    // Arrange - set payment service to fail mid-transaction
    paymentService.failNextRequest();
    
    // Act
    assertThatThrownBy(() -> orderService.createOrder(request))
      .isInstanceOf(PaymentException.class);
    
    // Assert - order NOT persisted
    assertThat(orderRepository.count()).isZero();
  }
}
```

### 3.2 Docker Compose for Local Testing

```yaml
version: '3.8'
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: orders_test
      POSTGRES_USER: test
      POSTGRES_PASSWORD: test
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U test"]
      interval: 10s
      timeout: 5s
      retries: 5

  kafka:
    image: confluentinc/cp-kafka:7.4.0
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:29092
    ports:
      - "9092:9092"
    depends_on:
      - zookeeper

  zookeeper:
    image: confluentinc/cp-zookeeper:7.4.0
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
```

Run: `docker-compose up --wait && mvn verify`

---

## 4. Spring Cloud Contract Testing

### 4.1 Contract Definition (Groovy)

**File**: `src/test/resources/contracts/order/shouldCreateOrder.groovy`

```groovy
package contracts.order

import org.springframework.cloud.contract.spec.Contract

Contract.make {
    description "should create order successfully"
    
    request {
        method POST()
        url "/api/v1/orders"
        body([
            customerId: "CUST-001",
            lineItems: [
                [
                    productId: "SKU-A",
                    quantity: 2,
                    unitPrice: 29.99
                ]
            ]
        ])
        headers {
            contentType applicationJson()
            header('Authorization', 'Bearer test-token')
        }
    }
    
    response {
        status 201
        body([
            orderId: value(anyNonEmptyString()),
            status: "PENDING",
            createdAt: value(anyDateTime()),
            totalAmount: 59.98
        ])
        headers {
            contentType applicationJson()
        }
    }
}
```

### 4.2 Auto-Generated Test

Spring Cloud Contract generates test from contract:

```java
@SpringBootTest
@AutoConfigureStubServer
public class OrderContractTest extends OrderBaseTestClass {
  
  @Autowired private TestRestTemplate restTemplate;
  
  // Auto-generated from contract
  public void shouldCreateOrder() {
    CreateOrderRequest request = new CreateOrderRequest(
      customerId = "CUST-001",
      lineItems = [...]
    );
    
    ResponseEntity<OrderResponse> response = 
      restTemplate.postForEntity("/api/v1/orders", request, OrderResponse.class);
    
    assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
    assertThat(response.getBody().getOrderId()).isNotEmpty();
  }
}
```

---

## 5. End-to-End Testing

### 5.1 Cucumber Feature Files

**File**: `src/test/resources/features/order.feature`

```gherkin
Feature: Order Management
  
  Scenario: Customer successfully creates and views order
    Given customer "alice@example.com" is logged in
    And inventory has 10 Widget-A in stock
    And payment gateway is available
    
    When alice creates an order with:
      | product   | quantity |
      | Widget-A  | 2        |
    
    Then order should be created with status PENDING
    And alice should see order in her order list
    And shipping service should receive order
    And alice should receive confirmation email
  
  Scenario: Order creation fails with insufficient inventory
    Given customer "bob@example.com" is logged in
    And inventory has 1 Widget-A in stock
    
    When bob attempts to create order with:
      | product   | quantity |
      | Widget-A  | 5        |
    
    Then order creation should fail
    And error message should include "Insufficient inventory"
    And no payment should be attempted
    And bob's cart should remain unchanged
```

### 5.2 Step Definitions

```java
@DisplayName("Order Steps")
public class OrderStepDefinitions {
  
  private CustomerContext customer;
  private OrderService orderService;
  private OrderResponse orderResponse;
  
  @Given("customer {string} is logged in")
  public void customerLoggedIn(String email) {
    customer = new CustomerContext(email);
    customer.login();
  }
  
  @When("alice creates an order with:")
  public void createOrder(DataTable dataTable) {
    List<Map<String, String>> rows = dataTable.asMaps();
    
    CreateOrderRequest request = new CreateOrderRequest(
      customerId = customer.getId(),
      items = rows.stream()
        .map(row -> new LineItem(
          productId = row.get("product"),
          quantity = Integer.parseInt(row.get("quantity"))
        ))
        .collect(Collectors.toList())
    );
    
    orderResponse = orderService.createOrder(request);
  }
  
  @Then("order should be created with status {string}")
  public void verifyOrderStatus(String status) {
    assertThat(orderResponse.getStatus()).isEqualTo(status);
    assertThat(orderResponse.getOrderId()).isNotEmpty();
  }
  
  @Then("alice should receive confirmation email")
  public void verifyEmail() {
    ArgumentCaptor<EmailRequest> captor = 
      ArgumentCaptor.forClass(EmailRequest.class);
    verify(emailService).sendEmail(captor.capture());
    EmailRequest email = captor.getValue();
    assertThat(email.getTo()).isEqualTo(customer.getEmail());
    assertThat(email.getSubject()).contains(orderResponse.getOrderId());
  }
}
```

---

## 6. Event Contract Validation

### 6.1 Event Schema Validation Test

```java
@DisplayName("Event Contract Validation")
class OrderEventsTest {
  
  private ObjectMapper objectMapper = new ObjectMapper();
  
  @DisplayName("OrderCreated event should conform to schema")
  @Test
  void validateOrderCreatedEventSchema() throws Exception {
    // Load schema
    String schemaJson = Files.readString(
      Paths.get("src/test/resources/schemas/order.created.v1.json")
    );
    JsonSchema schema = JsonSchemaFactory.getInstance()
      .getSchema(new StringSchemaSource(schemaJson));
    
    // Load sample event
    OrderCreatedEvent event = new OrderCreatedEvent(
      orderId = "ORD-2024-00001",
      customerId = "CUST-001",
      totalAmount = 99.99,
      createdAt = Instant.now()
    );
    
    // Validate
    String eventJson = objectMapper.writeValueAsString(event);
    JsonValidationResult result = schema.validate(
      objectMapper.readTree(eventJson)
    );
    
    assertThat(result.isValid()).isTrue();
    assertThat(result.getValidationMessages()).isEmpty();
  }
  
  @DisplayName("OrderCreated event should NOT contain PII")
  @Test
  void validateNoPiiInEvent() throws Exception {
    OrderCreatedEvent event = ...;
    String eventJson = objectMapper.writeValueAsString(event);
    
    // Forbidden patterns
    List<String> forbiddenPatterns = Arrays.asList(
      "email",
      "phone",
      "ssn",
      "address",
      "creditCard"
    );
    
    forbiddenPatterns.forEach(pattern -> {
      assertThat(eventJson.toLowerCase())
        .doesNotContain(pattern.toLowerCase());
    });
  }
}
```

### 6.2 Event versioning test

```java
@DisplayName("Event Versioning")
class EventVersioningTest {
  
  @DisplayName("should support v1 and v2 of OrderCreated event")
  @Test
  void multipleVersionsSupported() {
    // v1 (legacy)
    OrderCreatedEventV1 v1 = new OrderCreatedEventV1(...);
    kafka.publishEvent("ecommerce.order.order.created.v1", v1);
    
    // v2 (new fields)
    OrderCreatedEventV2 v2 = new OrderCreatedEventV2(
      ...oldFields...,
      discountCode = "SPRING20"
    );
    kafka.publishEvent("ecommerce.order.order.created.v2", v2);
    
    // Both should be consumable by downstream services
    OrderCreatedEventV1 consumedV1 = kafka.consume("...created.v1");
    assertThat(consumedV1).isNotNull();
    
    OrderCreatedEventV2 consumedV2 = kafka.consume("...created.v2");
    assertThat(consumedV2.getDiscountCode()).isEqualTo("SPRING20");
  }
}
```

---

## 7. Performance Testing

### 7.1 Performance Test with JUnit (Hyperfine Alternative)

```java
@DisplayName("Order Service Performance")
class OrderServicePerformanceTest {
  
  @Autowired private OrderService orderService;
  private List<Long> latencies = new ArrayList<>();
  
  @DisplayName("CreateOrder latency should meet SLO (p95 < 200ms)")
  @Test
  @Tag("performance")
  void createOrderLatency() throws Exception {
    // Warm-up
    for (int i = 0; i < 100; i++) {
      orderService.createOrder(testRequest());
    }
    
    // Measure
    for (int i = 0; i < 1000; i++) {
      long start = System.nanoTime();
      orderService.createOrder(testRequest());
      long end = System.nanoTime();
      
      latencies.add((end - start) / 1_000_000);  // Convert to ms
    }
    
    // Analyze
    Collections.sort(latencies);
    long p50 = latencies.get(500);
    long p95 = latencies.get(950);
    long p99 = latencies.get(990);
    
    System.out.println("Latency - p50: " + p50 + "ms, p95: " + p95 + "ms, p99: " + p99 + "ms");
    
    // Assert
    assertThat(p95).isLessThan(200);  // SLO requirement
  }
}
```

---

## 8. Chaos Testing

### 8.1 Chaos Test with Testcontainers Failover

```java
@DisplayName("Order Service Resilience")
class OrderServiceChaosTest {
  
  @Autowired private OrderService orderService;
  @Mock private CircuitBreaker inventoryBreaker;
  
  @DisplayName("should handle inventory service failure gracefully")
  @Test
  void inventoryServiceFailure() {
    // Inject failure
    inventoryBreaker.setState(CircuitState.OPEN);
    
    // Attempt order
    assertThatThrownBy(() -> orderService.createOrder(request))
      .isInstanceOf(ServiceUnavailableException.class);
    
    // Verify fallback: reject orders but don't crash
    verify(orderRepository, never()).save(any());
  }
  
  @DisplayName("should recover when inventory service recovers")
  @Test
  void inventoryServiceRecovery() throws Exception {
    // Initial failure
    inventoryBreaker.setState(CircuitState.OPEN);
    assertThatThrownBy(() -> orderService.createOrder(request));
    
    // Simulate recovery
    Thread.sleep(5000);  // Circuit breaker timeout
    inventoryBreaker.setState(CircuitState.CLOSED);
    
    // Order succeeds
    Order order = orderService.createOrder(request);
    assertThat(order.getOrderId()).isNotEmpty();
  }
}
```

---

## 9. QA Checklist Before Release

```markdown
## Pre-Release QA Validation

**Unit Tests**:
- [ ] All unit tests passing (mvn test)
- [ ] Code coverage ≥ 80%
- [ ] No warnings in test logs

**Integration Tests**:
- [ ] Database tests passing (Testcontainers)
- [ ] Kafka event integration tests passing
- [ ] External service mocks behaving correctly

**Contract Tests**:
- [ ] All Spring Cloud Contract tests passing
- [ ] Request/Response schemas validated
- [ ] API contract documentation current

**E2E Tests**:
- [ ] Critical user journeys passing
- [ ] Happy path test for each story
- [ ] One error scenario per feature

**Performance**:
- [ ] Create Order p95 < 200ms
- [ ] Get Order p95 < 100ms
- [ ] Load test with 100 concurrent users
- [ ] Memory: no leaks detected

**Security**:
- [ ] No PII in logs
- [ ] No PII in events
- [ ] Secrets not committed
- [ ] Dependency scan passed (OWASP)

**Documentation**:
- [ ] API docs (Swagger) current
- [ ] Test README updated
- [ ] Contract changes documented

**Deployment**:
- [ ] CI/CD pipeline green
- [ ] Manual smoke test on staging
- [ ] Rollback plan documented
```

---

## 10. Running Tests Locally

```bash
# Unit tests only (fast)
./mvnw test

# Unit + Integration tests
./mvnw verify

# Specific test class
./mvnw test -Dtest=OrderServiceTest

# Specific test method
./mvnw test -Dtest=OrderServiceTest#shouldCreateOrder

# With coverage report
./mvnw clean test jacoco:report
open target/site/jacoco/index.html

# Integration tests only (requires Testcontainers)
./mvnw test -Dgroups=integration

# Contract tests
./mvnw test -Dgroups=contract

# E2E tests (Cucumber)
./mvnw test -Dgroups=e2e

# Performance tests
./mvnw test -Dgroups=performance

# All with detailed output
./mvnw test -X -e
```

---

## References

- **JUnit 5 Docs**: https://junit.org/junit5/docs/current/user-guide/
- **Mockito**: https://javadoc.io/doc/org.mockito/mockito-core/latest/org/mockito/Mockito.html
- **Testcontainers**: https://www.testcontainers.org/
- **Spring Cloud Contract**: https://spring.io/projects/spring-cloud-contract
- **Cucumber**: https://cucumber.io/
- **Test Pyramid**: https://martinfowler.com/bliki/TestPyramid.html
