# BitVelocity Development AI Instructions

## Purpose
Specialized instructions for developing, testing, and maintaining BitVelocity microservices, ensuring consistency with platform conventions, architecture patterns, and quality standards.

---

## 1. Development Workflows

### 1.1 Adding a New Microservice to a Domain

**When Creating a New Service:**

1. **Identify Owner Domain**: `bv-eCommerce-core`, `bv-chat-stream`, `bv-iot-control-hub`, etc.
2. **Service Structure** (Maven module in domain):
   ```
   [domain]/[service-name]/
   ├── pom.xml                  # Inherit from domain parent
   ├── README.md                # Service overview, endpoints, events
   ├── src/main/java/
   │   └── com/bitvelo/[domain]/[service]/
   │       ├── controller/      # REST endpoints
   │       ├── service/         # Business logic
   │       ├── repository/      # Data access
   │       ├── entity/          # JPA entities
   │       ├── event/           # Event classes
   │       └── config/          # Spring configuration
   ├── src/test/java/
   │   └── [same structure]/
   │       ├── integration/     # Integration tests (Testcontainers)
   │       ├── contract/        # Spring Cloud Contract tests
   │       └── e2e/             # E2E tests (Cucumber)
   └── src/test/resources/
       └── contracts/           # Contract definitions
   ```

3. **pom.xml Template** (inherit from domain parent):
   ```xml
   <parent>
     <groupId>com.bitvelo.[domain]</groupId>
     <artifactId>[domain]-parent</artifactId>
     <version>${project.version}</version>
   </parent>
   <artifactId>[service-name]-service</artifactId>
   
   <dependencies>
     <!-- Core shared libraries -->
     <dependency>
       <groupId>com.bitvelo.core</groupId>
       <artifactId>bv-common-auth</artifactId>
     </dependency>
     <!-- No version: inherited from BOM -->
   </dependencies>
   ```

4. **Key Conventions**:
   - Use `@RestController`, `@Service`, `@Repository` patterns
   - Implement OpenTelemetry instrumentation (auto via starter)
   - Define Spring Cloud Contract stub endpoints
   - Use `@Transactional` for service methods
   - Emit domain events to Kafka via event publisher

5. **Documentation**:
   - Add microservice to domain architecture section
   - Update `BitVelocity-Docs/docs/00-OVERVIEW/projects-and-modules.md`
   - Create domain event contracts in `docs/event-contracts/`
   - Update relevant ADRs if architectural decisions made

---

### 1.2 Cross-Domain Integration

**When Integrating Services Across Domains:**

1. **Use Published Shared Libraries Only**:
   - ✅ DO: Import from `bv-core-common` (auth, entities, events, logging)
   - ❌ DON'T: Create internal domain-specific shared code for other domains
   - ✅ DO: Define integration points via events or REST/gRPC

2. **Reference Common Libraries**:
   - `bv-common-auth` - Authentication/authorization
   - `bv-common-entities` - Shared domain entities (User, Product, etc.)
   - `bv-common-events` - Event base classes and publishers
   - `bv-common-logging` - Structured logging framework
   - `bv-common-security` - Security utilities

3. **Communication Patterns**:
   - **Async**: Kafka topics (event-driven). Name: `<domain>.<context>.<entity>.<event>.v<version>`
   - **Sync**: REST (prefer `/operations`) or gRPC for latency-critical paths
   - **Circuit Breaking**: Use Resilience4j (configured in `config/resilience4j.yml`)

4. **Versioning Event Contracts**:
   - Always version: `user.account.registration.completed.v1.json`
   - Schema path: `BitVelocity-Docs/docs/event-contracts/<domain>/<service>/`
   - Validate schema in tests using contract validation library

---

### 1.3 Dependency Management

**Dependency Strategy:**

1. **BOM Hierarchy**:
   ```
   bv-core-platform-bom (spring-boot, spring-cloud, databases, testing)
     ↓
   bv-core-parent (build plugins, maven compiler settings, shade config)
     ↓
   [domain]-parent (domain-specific dependencies)
     ↓
   [service] (depends on nothing, inherits all)
   ```

2. **Adding Dependencies**:
   - Add to `bv-core-platform-bom/pom.xml` if cross-domain
   - Add to domain `parent` if domain-specific
   - Never declare version in child modules
   - Run `./mvnw clean install` from `bv-core-parent` to propagate

3. **Avoiding Classpath Issues**:
   ```bash
   # Clean and rebuild if classpath errors
   ./mvnw clean install -DskipTests
   
   # Gradle for infra
   ./gradlew clean build --refresh-dependencies
   ```

---

## 2. Testing Strategies

### 2.1 Test Pyramid for Microservices

**Unit Tests (70% of tests)**:
- Test individual methods in isolation with mocks
- Use `@ExtendWith(MockitoExtension.class)`
- Fast execution (< 1 sec per test class)
- Assert business logic, error handling

**Integration Tests (20% of tests)**:
- Use `@SpringBootTest` with `@Testcontainers`
- Spin up embedded PostgreSQL, Kafka, Redis
- Test service layer + repository interactions
- Verify event publishing to Kafka
- Clean up ephemeral containers after test

**Contract Tests (5% of tests)**:
- Spring Cloud Contract for REST/gRPC endpoints
- Define contracts in `src/test/resources/contracts/`
- Auto-generate test cases from contract definitions
- Ensure API backward compatibility

**E2E Tests (5% of tests)**:
- Cucumber feature files + Testcontainers
- Test full flow across multiple services
- Run in CI only; destroy stacks after test
- Document integration scenarios

### 2.2 Integration Test Template

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
  void shouldCreateOrderAndPublishEvent() {
    // Test service + Kafka event
  }
}
```

### 2.3 Event Validation in Tests

```java
@Autowired
private KafkaTemplate<String, String> kafkaTemplate;

@Test
void shouldPublishOrderCreatedEvent() throws Exception {
  var event = objectMapper.readValue(
    kafkaTemplate.receive("orders.order.created.v1", 5000).value(),
    OrderCreated.class
  );
  
  assertThat(event.orderId()).isNotNull();
  // Validate schema compliance
}
```

### 2.4 Contract Test Example

**File: `src/test/resources/contracts/orders/create-order.groovy`**
```groovy
org.springframework.cloud.contract.spec.Contract.make {
  request {
    method POST()
    url '/orders'
    body([
      customerId: $(regex('[0-9]+')),
      items: [[productId: value(123), quantity: 2]]
    ])
  }
  response {
    status 201()
    body([orderId: $(uuid())])
    headers { 'Content-Type': 'application/json' }
  }
}
```

---

## 3. Performance Testing

### 3.1 Gatling Load Tests

**Location**: `bv-performance-testing/gatling-tests/`

**Template**:
```java
public class OrderServiceLoadTest extends Simulation {
  
  private static final String BASE_URL = "http://orders-service:8080";
  private static final int TARGET_THROUGHPUT = 100;
  
  private HttpProtocolBuilder httpConf = http
    .baseUrl(BASE_URL)
    .acceptHeader("application/json");
  
  private ScenarioBuilder orderFlow = scenario("OrderFlow")
    .exec(http("Create Order")
      .post("/orders")
      .body(StringBody("""{"customerId":"123","items":[]}"""))
      .check(status().is(201)))
    .pause(1);
  
  { setUp(
    orderFlow.injectOpen(
      rampUsers(100).during(Duration.ofSeconds(30))
    )
  ).protocols(httpConf); }
}
```

**Run**:
```bash
cd bv-performance-testing/gatling-tests
./gradlew gatlingRun
```

### 3.2 k6 Smoke Tests (CI)

**Location**: `bv-performance-testing/k6-scripts/`

**Template**:
```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  vus: 10,
  duration: '30s',
  thresholds: {
    'http_req_duration': ['p(95)<200', 'p(99)<500'],
  },
};

export default function() {
  let res = http.post(`${__ENV.API_URL}/orders`, 
    JSON.stringify({ customerId: '123' })
  );
  check(res, {
    'status is 201': (r) => r.status === 201,
    'p95 latency < 200ms': (r) => r.timings.duration < 200,
  });
  sleep(1);
}
```

**Run**:
```bash
cd bv-performance-testing/k6-scripts
k6 run api-smoke-test.js
```

### 3.3 Performance Baselines

**Location**: `bv-performance-testing/performance-baselines/sli-targets.yaml`

Update after each load test to capture latency percentiles:
```yaml
order-service:
  POST /orders:
    p95_latency_ms: 200
    p99_latency_ms: 500
    throughput_rps: 100
```

---

## 4. Event Contracts Management

### 4.1 Event Naming Convention

**Format**: `<domain>.<context>.<entity>.<eventType>.v<majorVersion>`

**Examples**:
- `ecommerce.orders.order.created.v1`
- `ecommerce.payments.payment.completed.v2`
- `chat.messaging.message.sent.v1`
- `iot.devices.device.registered.v1`

### 4.2 Event Schema File

**Location**: `BitVelocity-Docs/docs/event-contracts/<domain>/<service>/<entity>.<action>.v<version>.json`

**Structure**:
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Order Created",
  "type": "object",
  "required": ["orderId", "customerId", "timestamp", "version"],
  "properties": {
    "orderId": { "type": "string" },
    "customerId": { "type": "string" },
    "totalAmount": { "type": "number" },
    "timestamp": { "type": "string", "format": "date-time" },
    "version": { "type": "string", "const": "1.0" }
  },
  "additionalProperties": false
}
```

**Validation Rules**:
- ❌ NO PII (emails, phone, full names)
- ✅ DO use UUIDs or numerical IDs
- ✅ DO timestamp in ISO 8601 format
- ✅ DO version events
- ✅ DO document schema in event contract file

### 4.3 Testing Event Contracts

```java
@Test
void shouldPublishOrderCreatedEventWithValidSchema() {
  var event = "{\"orderId\":\"123\",\"customerId\":\"456\"...}";
  
  JsonSchema schema = JsonSchemaFactory.byDefault()
    .getJsonSchema("classpath:order.created.v1.json");
  
  ProcessingReport report = schema.validate(objectMapper.readTree(event));
  assertTrue(report.isSuccess(), report.toString());
}
```

---

## 5. Chaos Engineering

### 5.1 Running Chaos Experiments

**Location**: `bv-chaos-experiments/`

**Experiment Template**:
1. **Define Hypothesis**: "Order service degrades gracefully when payment service is unavailable"
2. **Blast Radius**: Payment service only; dev environment
3. **Validation**: Monitor p99 latency, error rates, circuit breaker state
4. **Document**: Save experiment YAML and results in `experiments/`

**Safety Checklist**:
- Run in dev/staging ONLY until validated
- Ensure monitoring dashboards active
- Define rollback strategy
- Set time limit for experiment
- Verify cleanup (run `pulumi destroy` if cloud resources spun up)

**Example Chaos Mesh Experiment** (`kafka-partition-failure.yaml`):
```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: order-kafka-failure
  namespace: default
spec:
  action: partition
  mode: all
  selector:
    namespaces:
      - default
    labelSelectors:
      app: kafka
  duration: 5m
  scheduler:
    cron: '@daily'
```

### 5.2 Game Day Runbooks

Always document game days in `bv-chaos-experiments/game-days/`:
1. **Incident Scenario** (what failed)
2. **Detection Steps** (how to identify)
3. **Response** (how to mitigate)
4. **Resolution** (how to fix)
5. **Lessons Learned**

---

## 6. Documentation Standards

### 6.1 Adding a New Module

1. **Update Module Index**: `BitVelocity-Docs/docs/00-OVERVIEW/projects-and-modules.md`
   ```markdown
   ### [Service Name]
   - **Module**: `bv-[domain]-[service]`
   - **Type**: Microservice
   - **Purpose**: Brief description
   - **Key Dependencies**: List 2-3
   ```

2. **Add to Domain Architecture**: `docs/01-ARCHITECTURE/domains/DOMAIN_[NAME]_ARCHITECTURE.md`
3. **Add Event Contracts**: `docs/event-contracts/[domain]/[service]/README.md`
4. **Update mkdocs.yml** if new navigation sections needed

### 6.2 ADR Template

**File**: `docs/adr/ADR-[NUM]-[title].md`
```markdown
# ADR-[NUM]: [Title]

**Status**: Accepted | Proposed | Deprecated

**Context**: Problem statement, constraints

**Decision**: What we decided

**Consequences**: Benefits and tradeoffs

**Related**: Links to related ADRs, docs
```

### 6.3 Service README Template

```markdown
# [Service Name]

## Purpose
Brief description of service responsibilities and bounded context.

## Architecture
- REST endpoints and gRPC services offered
- Events published and consumed
- Dependencies on other services
- Technology stack (Spring Boot, DB, cache, etc.)

## API
- Endpoints table (METHOD /path → response)
- gRPC service definitions
- Contract references

## Events
- Published events (schema versions)
- Consumed events (source services)

## Configuration
- Environment variables
- Observability endpoints (/actuator/metrics)

## Development
- Build: `./mvnw clean install`
- Test: `./mvnw test`
- Run: `./mvnw spring-boot:run`

## References
- Domain architecture link
- Performance baselines link
- Related ADRs
```

---

## 7. Observability & Monitoring

### 7.1 OpenTelemetry Instrumentation

**Auto-instrumented via starter** (no code changes needed for basic tracing/metrics).

**Custom Metrics**:
```java
@Component
public class OrderMetrics {
  private final MeterRegistry meterRegistry;
  
  public void recordOrderCreation(Order order) {
    Counter.builder("orders.created")
      .tag("currency", order.getCurrency())
      .register(meterRegistry)
      .increment();
  }
}
```

### 7.2 Structured Logging

```java
import org.slf4j.Logger;

@Service
public class OrderService {
  private static final Logger log = LoggerFactory.getLogger(OrderService.class);
  
  public void createOrder(Order order) {
    log.info("Creating order {}", order.getId(), 
      kv("customerId", order.getCustomerId()),
      kv("amount", order.getTotal())
    );
  }
}
```

### 7.3 Observability Endpoints

- **Metrics**: `http://service:8080/actuator/metrics`
- **Health**: `http://service:8080/actuator/health`
- **OpenTelemetry Traces**: Sent to Jaeger (configured in `bv-observability/`)

---

## 8. Security & Compliance

### 8.1 Authentication & Authorization

**Use `bv-common-auth`**:
```java
@RestController
@RequestMapping("/api/orders")
public class OrderController {
  
  @GetMapping("/{orderId}")
  @PreAuthorize("hasRole('USER')")
  public OrderDTO getOrder(@PathVariable String orderId) {
    // Automatically enforces JWT validation
  }
}
```

### 8.2 Secrets Management

- **Development**: Load from `application-dev.yml` (NEVER commit secrets)
- **CI/CD**: Inject via GitHub Actions secrets
- **Production**: Use cloud secret manager (AWS Secrets Manager, Azure Key Vault)
- **Policy**: Enforce via OPA policies in `bv-infra-service/`

### 8.3 Security Testing

**OWASP ZAP Scans** (in `bv-security-testing/zap/`):
```bash
cd bv-security-testing
./run-zap-scan.sh http://orders-service:8080
```

**Dependency Scanning**:
```bash
./mvnw org.owasp:dependency-check-maven:check
```

---

## 9. Cloud Deployment (Pulumi)

### 9.1 Infrastructure as Code

**Location**: `bv-infra-service/`

**Deploy Stack**:
```bash
cd bv-infra-service
pulumi up --stack=dev  # Review changes
```

**Verify Deployment**:
```bash
./verify.sh  # Runs tests against deployed infrastructure
```

**Destroy (CRITICAL for ephemeral tests)**:
```bash
pulumi destroy --stack=dev --yes
```

### 9.2 Environment Configuration

- **Dev**: `Pulumi.dev.yaml` (auto-cleanup after tests)
- **Staging**: `Pulumi.staging.yaml` (persistent)
- **Production**: `Pulumi.production.yaml` (encrypted secrets)

---

## 10. CI/CD Quality Gates

### 10.1 Enforced Gates (`.github/workflows/`)

1. ✅ **Unit + Integration Tests**: Must pass
2. ✅ **Contract Validation**: Spring Cloud Contract tests
3. ✅ **Event Contract Linting**: No PII, valid schema
4. ✅ **Security Scans**: OWASP Dependency Check, SAST
5. ✅ **Code Quality**: Checkstyle, SpotBugs
6. ✅ **Performance Tests**: k6 smoke tests (p95 < thresholds)

### 10.2 Merge Requirements
- All checks pass
- Code review approved
- Documentation updated
- Event contracts (if modified) validated

---

## Quick Command Reference

```bash
# Build & Test
./mvnw clean install                    # Full build + tests
./mvnw test -Dtest=OrderServiceTest     # Single test class
./mvnw verify                           # includes integration tests

# Run Service
./mvnw spring-boot:run                  # Local development

# Dependency Management
./mvnw dependency:tree                  # View dependency tree
./mvnw org.owasp:dependency-check-maven:check

# Performance Testing
cd bv-performance-testing/gatling-tests && ./gradlew gatlingRun
cd bv-performance-testing/k6-scripts && k6 run api-smoke-test.js

# Infrastructure
cd bv-infra-service && pulumi up --stack=dev
cd bv-infra-service && ./verify.sh
cd bv-infra-service && pulumi destroy --stack=dev

# Chaos Engineering
cd bv-chaos-experiments && kubectl apply -f experiments/kafka-partition-failure.yaml

# Documentation
cd BitVelocity-Docs && mkdocs serve      # Preview locally
```

---

## References

- **Architecture**: `BitVelocity-Docs/docs/01-ARCHITECTURE/system-overview.md`
- **Module List**: `BitVelocity-Docs/docs/00-OVERVIEW/projects-and-modules.md`
- **Event Contracts**: `BitVelocity-Docs/docs/event-contracts/README.md`
- **Performance ADR**: `BitVelocity-Docs/docs/adr/ADR-015-load-testing-strategy.md`
- **Chaos ADR**: `BitVelocity-Docs/docs/adr/ADR-016-chaos-engineering-framework.md`
- **CI/CD ADR**: `BitVelocity-Docs/docs/adr/ADR-017-cicd-pipeline-architecture.md`
- **Testing Guide**: `BitVelocity-Docs/docs/03-DEVELOPMENT/testing-strategy.md`
- **Observability**: `bv-observability/README.md`
- **Security**: `bv-security-testing/README.md`
