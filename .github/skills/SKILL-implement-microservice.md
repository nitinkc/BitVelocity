# Skill: Implementing a New Microservice in BitVelocity

## Purpose
Step-by-step guide for creating a fully production-ready microservice within a BitVelocity domain, following all conventions and quality gates.

## When to Use This Skill
- Creating a new microservice in an existing domain (eCommerce, Chat, IoT, etc.)
- Adding a new bounded context service
- Following the full implementation workflow from skeleton to deployment

## Prerequisites
- Understand the domain requirements (use bitvelocity-requirements.instructions.md)
- Identified the service's responsibilities and event contracts
- Reviewed related domain architecture documentation

---

## Step 1: Create Maven Module Structure

### 1.1 Setup Module Hierarchy

```bash
cd bv-[domain]-core

# Create module directory
mkdir [service-name]-service
cd [service-name]-service

# Create standard Java package structure
mkdir -p src/main/java/com/bitvelo/[domain]/[service]
mkdir -p src/test/java/com/bitvelo/[domain]/[service]
mkdir -p src/test/resources/contracts/[entity]
mkdir -p src/main/resources
```

### 1.2 Create pom.xml

**Template**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  
  <parent>
    <groupId>com.bitvelo.[domain]</groupId>
    <artifactId>[domain]-parent</artifactId>
    <version>${project.version}</version>
    <relativePath>../pom.xml</relativePath>
  </parent>
  
  <artifactId>[service-name]-service</artifactId>
  <packaging>jar</packaging>
  <name>[Service Name]</name>
  
  <properties>
    <service.port>8080</service.port>
  </properties>
  
  <dependencies>
    <!-- Core Shared Libraries -->
    <dependency>
      <groupId>com.bitvelo.core</groupId>
      <artifactId>bv-common-auth</artifactId>
    </dependency>
    <dependency>
      <groupId>com.bitvelo.core</groupId>
      <artifactId>bv-common-entities</artifactId>
    </dependency>
    <dependency>
      <groupId>com.bitvelo.core</groupId>
      <artifactId>bv-common-events</artifactId>
    </dependency>
    <dependency>
      <groupId>com.bitvelo.core</groupId>
      <artifactId>bv-common-logging</artifactId>
    </dependency>
    <dependency>
      <groupId>com.bitvelo.core</groupId>
      <artifactId>bv-common-security</artifactId>
    </dependency>
    
    <!-- Spring Boot -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-data-jpa</artifactId>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-validation</artifactId>
    </dependency>
    
    <!-- Messaging -->
    <dependency>
      <groupId>org.springframework.kafka</groupId>
      <artifactId>spring-kafka</artifactId>
    </dependency>
    
    <!-- Observability -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>
    <dependency>
      <groupId>io.micrometer</groupId>
      <artifactId>micrometer-tracing-bridge-otel</artifactId>
    </dependency>
    
    <!-- Database -->
    <dependency>
      <groupId>org.postgresql</groupId>
      <artifactId>postgresql</artifactId>
      <scope>runtime</scope>
    </dependency>
    <dependency>
      <groupId>org.flywaydb</groupId>
      <artifactId>flyway-core</artifactId>
    </dependency>
    
    <!-- Circuit Breaking & Resilience -->
    <dependency>
      <groupId>io.github.resilience4j</groupId>
      <artifactId>resilience4j-spring-boot3</artifactId>
    </dependency>
    <dependency>
      <groupId>io.github.resilience4j</groupId>
      <artifactId>resilience4j-micrometer</artifactId>
    </dependency>
    
    <!-- Testing -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-test</artifactId>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>org.testcontainers</groupId>
      <artifactId>testcontainers</artifactId>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>org.testcontainers</groupId>
      <artifactId>postgresql</artifactId>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>org.testcontainers</groupId>
      <artifactId>kafka</artifactId>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>org.springframework.cloud</groupId>
      <artifactId>spring-cloud-contract-verifier</artifactId>
      <scope>test</scope>
    </dependency>
  </dependencies>
  
  <build>
    <plugins>
      <plugin>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-maven-plugin</artifactId>
      </plugin>
      <plugin>
        <groupId>org.springframework.cloud</groupId>
        <artifactId>spring-cloud-contract-maven-plugin</artifactId>
      </plugin>
    </plugins>
  </build>
</project>
```

### 1.3 Update Parent Domain pom.xml

Add new module to domain parent:
```xml
<modules>
  <module>[existing-service]</module>
  <module>[service-name]-service</module>  <!-- NEW -->
</modules>
```

---

## Step 2: Create Core Classes

### 2.1 Spring Boot Application Class

**File**: `src/main/java/com/bitvelo/[domain]/[service]/[ServiceName]Application.java`

```java
package com.bitvelo.[domain].[service];

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.kafka.annotation.EnableKafka;

@SpringBootApplication
@EnableKafka
public class OrderServiceApplication {
  
  public static void main(String[] args) {
    SpringApplication.run(OrderServiceApplication.class, args);
  }
}
```

### 2.2 JPA Entity

**File**: `src/main/java/com/bitvelo/[domain]/[service]/entity/Order.java`

```java
package com.bitvelo.[domain].[service].entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Entity
@Table(name = "orders")
public class Order {
  
  @Id
  private String orderId;
  
  @Column(nullable = false)
  private String customerId;
  
  @Enumerated(EnumType.STRING)
  @Column(nullable = false)
  private OrderStatus status;
  
  @Column(nullable = false, precision = 10, scale = 2)
  private BigDecimal totalAmount;
  
  @Column(nullable = false)
  private String currency;
  
  @Column(name = "created_at", nullable = false)
  private OffsetDateTime createdAt;
  
  @Column(name = "updated_at")
  private OffsetDateTime updatedAt;
  
  // Constructors, getters, setters...
}
```

### 2.3 Repository

**File**: `src/main/java/com/bitvelo/[domain]/[service]/repository/OrderRepository.java`

```java
package com.bitvelo.[domain].[service].repository;

import com.bitvelo.[domain].[service].entity.Order;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface OrderRepository extends JpaRepository<Order, String> {
  List<Order> findByCustomerId(String customerId);
}
```

### 2.4 Service Layer

**File**: `src/main/java/com/bitvelo/[domain]/[service]/service/OrderService.java`

```java
package com.bitvelo.[domain].[service].service;

import com.bitvelo.[domain].[service].entity.Order;
import com.bitvelo.[domain].[service].repository.OrderRepository;
import com.bitvelo.core.events.EventPublisher;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.UUID;

@Slf4j
@Service
public class OrderService {
  
  private final OrderRepository orderRepository;
  private final EventPublisher eventPublisher;
  
  public OrderService(OrderRepository orderRepository, 
                      EventPublisher eventPublisher) {
    this.orderRepository = orderRepository;
    this.eventPublisher = eventPublisher;
  }
  
  @Transactional
  public Order createOrder(CreateOrderRequest request) {
    log.info("Creating order for customer {}", request.customerId);
    
    Order order = new Order()
      .setOrderId(UUID.randomUUID().toString())
      .setCustomerId(request.customerId)
      .setStatus(OrderStatus.CREATED)
      .setTotalAmount(request.calculateTotal())
      .setCurrency(request.currency);
    
    Order saved = orderRepository.save(order);
    
    // Publish event
    eventPublisher.publish("orders.order.created.v1", 
      new OrderCreated(saved.getOrderId(), saved.getCustomerId()));
    
    return saved;
  }
}
```

### 2.5 REST Controller

**File**: `src/main/java/com/bitvelo/[domain]/[service]/controller/OrderController.java`

```java
package com.bitvelo.[domain].[service].controller;

import com.bitvelo.[domain].[service].service.OrderService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import jakarta.validation.Valid;
import java.net.URI;

@RestController
@RequestMapping("/api/v1/orders")
public class OrderController {
  
  private final OrderService orderService;
  
  public OrderController(OrderService orderService) {
    this.orderService = orderService;
  }
  
  @PostMapping
  @PreAuthorize("hasRole('CUSTOMER')")
  public ResponseEntity<OrderDTO> createOrder(@Valid @RequestBody CreateOrderRequest request) {
    Order order = orderService.createOrder(request);
    
    return ResponseEntity
      .created(URI.create("/api/v1/orders/" + order.getOrderId()))
      .body(new OrderDTO(order));
  }
  
  @GetMapping("/{orderId}")
  @PreAuthorize("hasRole('CUSTOMER')")
  public ResponseEntity<OrderDTO> getOrder(@PathVariable String orderId) {
    Order order = orderService.getOrder(orderId);
    return ResponseEntity.ok(new OrderDTO(order));
  }
}
```

---

## Step 3: Configuration Files

### 3.1 Application YAML

**File**: `src/main/resources/application.yml`

```yaml
spring:
  application:
    name: orders-service
  
  datasource:
    url: jdbc:postgresql://localhost:5432/orders
    username: ${DB_USER:postgres}
    password: ${DB_PASSWORD:postgres}
  
  jpa:
    hibernate:
      ddl-auto: validate
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect
        format_sql: true
  
  kafka:
    bootstrap-servers: ${KAFKA_BOOTSTRAP_SERVERS:localhost:9092}
    producer:
      value-serializer: org.springframework.kafka.support.serializer.JsonSerializer
    consumer:
      value-deserializer: org.springframework.kafka.support.serializer.JsonDeserializer
      auto-offset-reset: earliest
      group-id: orders-service
  
management:
  endpoints:
    web:
      exposure:
        include: health,metrics,info
  metrics:
    export:
      prometheus:
        enabled: true
  tracing:
    sampling:
      probability: 1.0

logging:
  level:
    com.bitvelo: DEBUG
    org.springframework: INFO
  pattern:
    console: "%d{ISO8601} %msg%n"

resilience4j:
  circuitbreaker:
    configs:
      default:
        failure-rate-threshold: 50
        wait-duration-in-open-state: 10000
        register-health-indicator: true
```

### 3.2 Application Properties (Dev)

**File**: `src/main/resources/application-dev.yml`

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/orders_dev
  kafka:
    bootstrap-servers: localhost:9092

logging:
  level:
    com.bitvelo: DEBUG
```

---

## Step 4: Database Migrations

### 4.1 Flyway Migration

**File**: `src/main/resources/db/migration/V1__Initial_schema.sql`

```sql
CREATE TABLE orders (
  order_id VARCHAR(36) PRIMARY KEY,
  customer_id VARCHAR(36) NOT NULL,
  status VARCHAR(50) NOT NULL,
  total_amount NUMERIC(10,2) NOT NULL,
  currency VARCHAR(3) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE,
  CONSTRAINT fk_customer FOREIGN KEY (customer_id) 
    REFERENCES users(user_id)
);

CREATE INDEX idx_customer_id ON orders(customer_id);
CREATE INDEX idx_status ON orders(status);
```

---

## Step 5: Test Implementation

### 5.1 Unit Tests

**File**: `src/test/java/com/bitvelo/[domain]/[service]/service/OrderServiceTest.java`

```java
@ExtendWith(MockitoExtension.class)
class OrderServiceTest {
  
  @Mock
  private OrderRepository orderRepository;
  
  @Mock
  private EventPublisher eventPublisher;
  
  @InjectMocks
  private OrderService orderService;
  
  @Test
  void shouldCreateOrderAndPublishEvent() {
    // Arrange
    CreateOrderRequest request = new CreateOrderRequest()
      .setCustomerId("CUST-001")
      .setItems(/* ... */);
    
    Order order = new Order().setOrderId("ORD-001");
    when(orderRepository.save(any())).thenReturn(order);
    
    // Act
    Order result = orderService.createOrder(request);
    
    // Assert
    assertThat(result.getOrderId()).isEqualTo("ORD-001");
    verify(eventPublisher).publish("orders.order.created.v1", any());
  }
}
```

### 5.2 Integration Test

**File**: `src/test/java/com/bitvelo/[domain]/[service]/integration/OrderServiceIntegrationTest.java`

```java
@SpringBootTest
@Testcontainers
class OrderServiceIntegrationTest {
  
  @Container
  static PostgreSQLContainer<?> postgres = 
    new PostgreSQLContainer<>("postgres:15")
      .withDatabaseName("test_db");
  
  @Container
  static KafkaContainer kafka = new KafkaContainer();
  
  @Autowired
  private OrderService orderService;
  
  @DynamicPropertySource
  static void properties(DynamicPropertyRegistry registry) {
    registry.add("spring.datasource.url", postgres::getJdbcUrl);
    registry.add("spring.kafka.bootstrap-servers", kafka::getBootstrapServers);
  }
  
  @Test
  void shouldPersistAndPublishEvent() {
    // Test full flow with real DB + Kafka
  }
}
```

### 5.3 Contract Test

**File**: `src/test/resources/contracts/orders/create-order.groovy`

```groovy
Contract.make {
  description 'should create order and return 201'
  
  request {
    method POST()
    url '/api/v1/orders'
    body(/* order payload */)
  }
  
  response {
    status 201()
    body(/* expected response */)
  }
}
```

---

## Step 6: Event Contract Definition

### 6.1 Create Event Schema File

**File**: `BitVelocity-Docs/docs/event-contracts/[domain]/[service]/order.created.v1.json`

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Order Created",
  "type": "object",
  "required": ["orderId", "customerId", "totalAmount", "timestamp", "version"],
  "properties": {
    "orderId": { "type": "string", "pattern": "^[A-Z0-9-]{10,}$" },
    "customerId": { "type": "string", "format": "uuid" },
    "totalAmount": { "type": "number", "minimum": 0 },
    "currency": { "type": "string", "minLength": 3, "maxLength": 3 },
    "timestamp": { "type": "string", "format": "date-time" },
    "version": { "type": "string", "const": "1.0" }
  },
  "additionalProperties": false
}
```

### 6.2 Document Event Contracts in Service README

Update service `README.md`:
```markdown
## Events

### Published
- **order.created.v1**: When order is created
  - Schema: docs/event-contracts/[domain]/[service]/order.created.v1.json
  - Consumed by: PaymentService, NotificationService

### Consumed
- **payment.completed.v1**: When payment succeeds
  - Updates order status to PAID
```

---

## Step 7: Documentation

### 7.1 Service README

**File**: `[service-name]-service/README.md`

```markdown
# Order Service

## Purpose
Manages order creation, state transitions, and event publishing.

## Architecture
- Bounded Context: Order Management
- Technology: Spring Boot, PostgreSQL, Kafka, OpenTelemetry

## API Endpoints
- POST /api/v1/orders - Create order
- GET /api/v1/orders/{orderId} - Get order details

## Events
- Publishes: order.created.v1
- Consumes: payment.completed.v1

## Development
```bash
./mvnw clean install
./mvnw spring-boot:run
```

## Configuration
- KAFKA_BOOTSTRAP_SERVERS (default: localhost:9092)
- DB_USER, DB_PASSWORD
```

### 7.2 Update Domain Architecture

Add to `BitVelocity-Docs/docs/01-ARCHITECTURE/domains/DOMAIN_ECOMMERCE_ARCHITECTURE.md`:

```markdown
## Services

### Order Service
- Port: 8080
- Responsibility: Order creation and management
- Dependencies: Payment Service, Inventory Service
- Events: Publishes order.created, order.cancelled
```

### 7.3 Update Module Index

Update `BitVelocity-Docs/docs/00-OVERVIEW/projects-and-modules.md`:

```markdown
### Order Service
- **Module**: `bv-ecommerce-core/order-service`
- **Type**: Microservice
- **Purpose**: Order management and lifecycle
- **Key Dependencies**: Order repository, Event publisher
- **Status**: Active
```

---

## Step 8: Build & Deploy

### 8.1 Build Service

```bash
cd bv-ecommerce-core/order-service
./mvnw clean install
```

### 8.2 Run Service Locally

```bash
# Start PostgreSQL
docker run -d --name postgres \
  -e POSTGRES_DB=orders \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 \
  postgres:15

# Start Kafka
docker-compose up kafka

# Run service
./mvnw spring-boot:run
```

### 8.3 Verify Service

```bash
# Check health
curl http://localhost:8080/actuator/health

# Check metrics
curl http://localhost:8080/actuator/metrics

# Create order
curl -X POST http://localhost:8080/api/v1/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"customerId":"CUST-001","items":[...]}'
```

---

## Step 9: CI/CD Integration

Add to `.github/workflows/` pipeline:

```yaml
- name: Build Order Service
  run: |
    cd bv-ecommerce-core/order-service
    ./mvnw clean verify
    
- name: Deploy Order Service
  run: |
    cd bv-infra-service
    pulumi config set project-service:order-service-enabled true
    pulumi up --auto-approve
```

---

## Completion Checklist

- [ ] Maven module created with pom.xml
- [ ] Entity, Repository, Service, Controller implemented
- [ ] Database migrations created
- [ ] Unit tests passing (75%+ coverage)
- [ ] Integration tests passing (Testcontainers)
- [ ] Contract tests passing (Spring Cloud Contract)
- [ ] Event contracts defined and validated
- [ ] Application YAML configured
- [ ] Service README updated
- [ ] Domain architecture updated
- [ ] Module index updated
- [ ] Local build & run verified
- [ ] CI/CD pipeline configured
- [ ] Security review completed
- [ ] Documentation complete

---

## Common Troubleshooting

| Issue | Solution |
|-------|----------|
| Classpath errors | Run `mvnw clean install` from parent |
| Tests fail with container issues | Check Docker daemon, pull `postgres:15`, `confluentinc/cp-kafka` |
| Event publishing not working | Verify Kafka config, check Kafka logs |
| Migrations not running | Check flyway version, verify migration naming |
