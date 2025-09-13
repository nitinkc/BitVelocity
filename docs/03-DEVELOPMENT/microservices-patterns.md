# Microservices Patterns & Implementation Guide

## Purpose
This document provides comprehensive guidance on microservices patterns, their implementation in the BitVelocity platform, and the sequence for introducing complexity during the learning process.

## Pattern Introduction Strategy

### Learning Sequence
1. **Foundation Patterns** (Weeks 1-4): Basic CRUD, Authentication, Events
2. **Communication Patterns** (Weeks 5-8): API Gateway, Service Discovery, Circuit Breaker
3. **Data Patterns** (Weeks 9-12): CQRS, Event Sourcing, Saga
4. **Advanced Integration** (Weeks 13-16): BFF, Anti-Corruption Layer, Strangler Fig
5. **Operational Patterns** (Weeks 17-20): Bulkhead, Timeout, Retry, Rate Limiting

## Core Microservices Patterns

### 1. Service Decomposition Patterns

#### Database per Service
**Intent**: Each microservice owns its data and database schema.

```java
// Order Service - owns order data
@Entity
@Table(name = "orders")
public class Order {
    @Id
    private UUID orderId;
    private UUID customerId; // Reference, not FK
    private OrderStatus status;
    private BigDecimal totalAmount;
    
    // Audit fields
    private Instant createdAt;
    private String createdBy;
}

// Customer Service - owns customer data  
@Entity
@Table(name = "customers")
public class Customer {
    @Id
    private UUID customerId;
    private String email;
    private String name;
    private CustomerStatus status;
}
```

**Implementation Strategy**:
- Start with logical separation in same database
- Migrate to physical separation as services stabilize
- Use shared libraries for common patterns

#### Shared Libraries Pattern
**Intent**: Share common code while maintaining service autonomy.

```java
// Shared event library
@AllArgsConstructor
@Getter
public abstract class DomainEvent {
    private final UUID eventId = UUID.randomUUID();
    private final Instant timestamp = Instant.now();
    private final String eventType;
    private final UUID aggregateId;
    private final String correlationId;
    private final Map<String, String> metadata;
}

// Usage in Order Service
public class OrderCreatedEvent extends DomainEvent {
    private final UUID customerId;
    private final BigDecimal amount;
    private final List<OrderItem> items;
    
    public OrderCreatedEvent(UUID orderId, UUID customerId, BigDecimal amount, List<OrderItem> items) {
        super("OrderCreated", orderId, MDC.get("correlationId"), getEventMetadata());
        this.customerId = customerId;
        this.amount = amount;
        this.items = items;
    }
}
```

### 2. Communication Patterns

#### API Gateway Pattern
**Intent**: Single entry point for all client requests with cross-cutting concerns.

```java
@RestController
@RequestMapping("/api/gateway")
public class ApiGatewayController {
    
    @Autowired
    private ServiceRegistry serviceRegistry;
    
    @Autowired
    private LoadBalancer loadBalancer;
    
    @PostMapping("/orders")
    public ResponseEntity<OrderResponse> createOrder(
            @RequestBody CreateOrderRequest request,
            @RequestHeader("Authorization") String authToken) {
        
        // Authentication & Authorization
        var user = authService.validateToken(authToken);
        
        // Rate limiting
        rateLimiter.checkLimit(user.getId());
        
        // Request routing
        var orderService = serviceRegistry.getService("order-service");
        var endpoint = loadBalancer.selectEndpoint(orderService);
        
        // Request transformation
        var internalRequest = requestTransformer.transform(request, user);
        
        // Circuit breaker protection
        return circuitBreaker.execute(() -> 
            orderServiceClient.createOrder(endpoint, internalRequest)
        );
    }
}
```

#### Service Discovery Pattern
**Intent**: Services register themselves and discover other services dynamically.

```java
@Component
public class ServiceRegistry {
    
    private final Map<String, List<ServiceInstance>> services = new ConcurrentHashMap<>();
    
    @EventListener
    public void handleServiceRegistration(ServiceRegistrationEvent event) {
        services.computeIfAbsent(event.getServiceName(), k -> new ArrayList<>())
                .add(event.getServiceInstance());
        
        log.info("Service registered: {} at {}", 
                event.getServiceName(), 
                event.getServiceInstance().getEndpoint());
    }
    
    public List<ServiceInstance> getHealthyInstances(String serviceName) {
        return services.getOrDefault(serviceName, Collections.emptyList())
                .stream()
                .filter(ServiceInstance::isHealthy)
                .collect(Collectors.toList());
    }
}

// Service registration on startup
@Component
public class ServiceRegistrar implements ApplicationListener<ContextRefreshedEvent> {
    
    @Override
    public void onApplicationEvent(ContextRefreshedEvent event) {
        var instance = ServiceInstance.builder()
                .serviceId(UUID.randomUUID())
                .serviceName(applicationProperties.getServiceName())
                .endpoint(buildEndpoint())
                .metadata(getServiceMetadata())
                .healthCheckUrl(getHealthCheckUrl())
                .build();
        
        serviceRegistry.register(instance);
    }
}
```

#### Circuit Breaker Pattern
**Intent**: Prevent cascading failures by failing fast when downstream services are unhealthy.

```java
@Component
public class CircuitBreaker {
    
    private final Map<String, CircuitBreakerState> circuitStates = new ConcurrentHashMap<>();
    
    public <T> T execute(String circuitName, Supplier<T> operation, Supplier<T> fallback) {
        var state = circuitStates.computeIfAbsent(circuitName, k -> new CircuitBreakerState());
        
        if (state.isOpen()) {
            if (state.shouldAttemptReset()) {
                state.halfOpen();
            } else {
                return fallback.get();
            }
        }
        
        try {
            var result = operation.get();
            state.recordSuccess();
            return result;
        } catch (Exception e) {
            state.recordFailure();
            if (state.shouldTrip()) {
                state.open();
            }
            return fallback.get();
        }
    }
}

// Usage
@Service
public class OrderService {
    
    public Order getOrderDetails(UUID orderId) {
        return circuitBreaker.execute(
            "customer-service",
            () -> customerServiceClient.getCustomer(order.getCustomerId()),
            () -> CustomerSummary.unavailable(order.getCustomerId())
        );
    }
}
```

### 3. Data Management Patterns

#### Command Query Responsibility Segregation (CQRS)
**Intent**: Separate read and write models for better scalability and maintainability.

```java
// Command side - optimized for writes
@Entity
@Table(name = "orders")
public class OrderAggregate {
    @Id
    private UUID orderId;
    private UUID customerId;
    private OrderStatus status;
    private List<OrderItem> items;
    
    public void addItem(OrderItem item) {
        validateItem(item);
        this.items.add(item);
        applyEvent(new OrderItemAddedEvent(orderId, item));
    }
    
    public void confirm() {
        if (status != OrderStatus.PENDING) {
            throw new InvalidOrderStateException("Order must be pending to confirm");
        }
        this.status = OrderStatus.CONFIRMED;
        applyEvent(new OrderConfirmedEvent(orderId, Instant.now()));
    }
}

// Query side - optimized for reads
@Document(collection = "order_views")
public class OrderView {
    @Id
    private UUID orderId;
    private String customerName;
    private String customerEmail;
    private BigDecimal totalAmount;
    private String status;
    private List<OrderItemView> items;
    private Instant createdAt;
    private Instant lastUpdated;
}

// Projection handler
@EventListener
@Component
public class OrderViewProjectionHandler {
    
    @Autowired
    private OrderViewRepository orderViewRepository;
    
    @KafkaListener(topics = "order-events")
    public void handleOrderEvent(DomainEvent event) {
        switch (event.getEventType()) {
            case "OrderCreated" -> handleOrderCreated((OrderCreatedEvent) event);
            case "OrderConfirmed" -> handleOrderConfirmed((OrderConfirmedEvent) event);
            case "OrderItemAdded" -> handleOrderItemAdded((OrderItemAddedEvent) event);
        }
    }
    
    private void handleOrderCreated(OrderCreatedEvent event) {
        var orderView = OrderView.builder()
                .orderId(event.getAggregateId())
                .customerId(event.getCustomerId())
                .totalAmount(event.getTotalAmount())
                .status("PENDING")
                .createdAt(event.getTimestamp())
                .build();
        
        orderViewRepository.save(orderView);
    }
}
```

#### Event Sourcing Pattern
**Intent**: Store domain events as the primary source of truth.

```java
@Entity
@Table(name = "event_store")
public class EventStore {
    @Id
    private UUID eventId;
    private UUID aggregateId;
    private String aggregateType;
    private String eventType;
    private String eventData;
    private Integer version;
    private Instant timestamp;
    private String metadata;
    
    // Optimistic locking
    @Version
    private Long lockVersion;
}

@Repository
public class EventStoreRepository {
    
    public void saveEvents(UUID aggregateId, List<DomainEvent> events, Integer expectedVersion) {
        var currentVersion = getLatestVersion(aggregateId);
        
        if (!currentVersion.equals(expectedVersion)) {
            throw new ConcurrencyException("Aggregate has been modified");
        }
        
        for (int i = 0; i < events.size(); i++) {
            var event = events.get(i);
            var eventStoreEntry = EventStore.builder()
                    .eventId(event.getEventId())
                    .aggregateId(aggregateId)
                    .aggregateType(getAggregateType(aggregateId))
                    .eventType(event.getEventType())
                    .eventData(jsonMapper.writeValueAsString(event))
                    .version(expectedVersion + i + 1)
                    .timestamp(event.getTimestamp())
                    .build();
            
            eventStoreJpaRepository.save(eventStoreEntry);
        }
    }
    
    public List<DomainEvent> getEvents(UUID aggregateId) {
        return eventStoreJpaRepository.findByAggregateIdOrderByVersion(aggregateId)
                .stream()
                .map(this::deserializeEvent)
                .collect(Collectors.toList());
    }
}

// Aggregate reconstruction
@Component
public class AggregateRepository<T extends AggregateRoot> {
    
    public T getById(UUID aggregateId, Class<T> aggregateClass) {
        var events = eventStoreRepository.getEvents(aggregateId);
        var aggregate = createEmptyAggregate(aggregateClass);
        
        events.forEach(aggregate::applyEvent);
        aggregate.markEventsAsCommitted();
        
        return aggregate;
    }
    
    public void save(T aggregate) {
        var uncommittedEvents = aggregate.getUncommittedEvents();
        eventStoreRepository.saveEvents(
            aggregate.getId(), 
            uncommittedEvents, 
            aggregate.getVersion()
        );
        
        // Publish events to message bus
        eventPublisher.publish(uncommittedEvents);
        
        aggregate.markEventsAsCommitted();
    }
}
```

#### Saga Pattern (Orchestration)
**Intent**: Manage distributed transactions across multiple services.

```java
@Component
public class OrderSaga {
    
    private enum SagaState {
        STARTED, PAYMENT_PENDING, INVENTORY_RESERVED, 
        COMPLETED, COMPENSATING, FAILED
    }
    
    @Entity
    @Table(name = "saga_instances")
    public static class SagaInstance {
        @Id
        private UUID sagaId;
        private UUID orderId;
        private SagaState state;
        private Map<String, Object> sagaData;
        private Instant createdAt;
        private Instant updatedAt;
    }
    
    @SagaOrchestrationStart
    public void handleOrderCreated(OrderCreatedEvent event) {
        var sagaInstance = new SagaInstance(UUID.randomUUID(), event.getAggregateId());
        sagaInstance.setState(SagaState.STARTED);
        sagaRepository.save(sagaInstance);
        
        // Step 1: Reserve inventory
        commandGateway.send(new ReserveInventoryCommand(
            event.getAggregateId(),
            event.getItems()
        ));
    }
    
    @SagaOrchestrationHandler
    public void handleInventoryReserved(InventoryReservedEvent event) {
        var saga = sagaRepository.findByOrderId(event.getOrderId());
        saga.setState(SagaState.INVENTORY_RESERVED);
        sagaRepository.save(saga);
        
        // Step 2: Process payment
        commandGateway.send(new ProcessPaymentCommand(
            event.getOrderId(),
            saga.getSagaData().get("paymentAmount")
        ));
    }
    
    @SagaOrchestrationHandler
    public void handlePaymentProcessed(PaymentProcessedEvent event) {
        var saga = sagaRepository.findByOrderId(event.getOrderId());
        saga.setState(SagaState.COMPLETED);
        sagaRepository.save(saga);
        
        // Step 3: Confirm order
        commandGateway.send(new ConfirmOrderCommand(event.getOrderId()));
    }
    
    // Compensation handlers
    @SagaOrchestrationHandler
    public void handleInventoryReservationFailed(InventoryReservationFailedEvent event) {
        var saga = sagaRepository.findByOrderId(event.getOrderId());
        saga.setState(SagaState.FAILED);
        sagaRepository.save(saga);
        
        commandGateway.send(new CancelOrderCommand(event.getOrderId()));
    }
    
    @SagaOrchestrationHandler
    public void handlePaymentFailed(PaymentFailedEvent event) {
        var saga = sagaRepository.findByOrderId(event.getOrderId());
        saga.setState(SagaState.COMPENSATING);
        sagaRepository.save(saga);
        
        // Compensate: Release inventory
        commandGateway.send(new ReleaseInventoryCommand(
            event.getOrderId(),
            saga.getSagaData().get("reservedItems")
        ));
    }
}
```

### 4. Integration Patterns

#### Backend for Frontend (BFF)
**Intent**: Create service layers tailored to specific frontend needs.

```java
// Mobile BFF
@RestController
@RequestMapping("/mobile/api")
public class MobileBffController {
    
    @GetMapping("/dashboard")
    public MobileDashboardResponse getDashboard(@AuthenticationPrincipal User user) {
        // Optimized for mobile - minimal data
        var orders = orderService.getRecentOrders(user.getId(), 5);
        var recommendations = recommendationService.getTopRecommendations(user.getId(), 3);
        
        return MobileDashboardResponse.builder()
                .recentOrders(orders.stream()
                    .map(this::toMobileOrderSummary)
                    .collect(Collectors.toList()))
                .recommendations(recommendations)
                .build();
    }
    
    private MobileOrderSummary toMobileOrderSummary(Order order) {
        return MobileOrderSummary.builder()
                .orderId(order.getId())
                .status(order.getStatus())
                .totalAmount(order.getTotalAmount())
                .itemCount(order.getItems().size())
                .build();
    }
}

// Web BFF
@RestController
@RequestMapping("/web/api")
public class WebBffController {
    
    @GetMapping("/dashboard")
    public WebDashboardResponse getDashboard(@AuthenticationPrincipal User user) {
        // Rich data for web interface
        var orders = orderService.getRecentOrdersWithDetails(user.getId(), 10);
        var analytics = analyticsService.getUserAnalytics(user.getId());
        var recommendations = recommendationService.getPersonalizedRecommendations(user.getId(), 10);
        
        return WebDashboardResponse.builder()
                .orders(orders)
                .analytics(analytics)
                .recommendations(recommendations)
                .build();
    }
}
```

#### Anti-Corruption Layer (ACL)
**Intent**: Protect domain model from external system dependencies.

```java
// Legacy payment gateway adapter
@Component
public class LegacyPaymentGatewayAdapter implements PaymentGateway {
    
    @Autowired
    private LegacyPaymentClient legacyClient;
    
    @Override
    public PaymentResult processPayment(PaymentRequest request) {
        // Translate domain model to legacy format
        var legacyRequest = LegacyPaymentRequest.builder()
                .amount(request.getAmount().multiply(BigDecimal.valueOf(100))) // Convert to cents
                .currency(request.getCurrency().getCurrencyCode())
                .cardNumber(request.getCardDetails().getNumber())
                .expiryMonth(String.format("%02d", request.getCardDetails().getExpiryMonth()))
                .expiryYear(String.valueOf(request.getCardDetails().getExpiryYear()))
                .build();
        
        try {
            var legacyResponse = legacyClient.chargeCard(legacyRequest);
            
            // Translate response back to domain model
            return PaymentResult.builder()
                    .paymentId(UUID.fromString(legacyResponse.getTransactionId()))
                    .status(mapLegacyStatus(legacyResponse.getStatus()))
                    .amount(legacyResponse.getChargedAmount().divide(BigDecimal.valueOf(100)))
                    .processedAt(Instant.parse(legacyResponse.getTimestamp()))
                    .build();
                    
        } catch (LegacyPaymentException e) {
            throw new PaymentProcessingException("Payment failed", e);
        }
    }
    
    private PaymentStatus mapLegacyStatus(String legacyStatus) {
        return switch (legacyStatus) {
            case "SUCCESS" -> PaymentStatus.COMPLETED;
            case "PENDING" -> PaymentStatus.PROCESSING;
            case "DECLINED" -> PaymentStatus.DECLINED;
            case "ERROR" -> PaymentStatus.FAILED;
            default -> throw new IllegalArgumentException("Unknown legacy status: " + legacyStatus);
        };
    }
}
```

#### Strangler Fig Pattern
**Intent**: Gradually replace legacy systems by intercepting and redirecting calls.

```java
@Component
public class OrderServiceStranglerFig {
    
    @Autowired
    private LegacyOrderService legacyOrderService;
    
    @Autowired
    private ModernOrderService modernOrderService;
    
    @Autowired
    private FeatureToggleService featureToggleService;
    
    public Order getOrder(UUID orderId) {
        // Determine which implementation to use
        if (shouldUseLegacyService(orderId)) {
            var legacyOrder = legacyOrderService.getOrder(orderId.toString());
            return adaptLegacyOrder(legacyOrder);
        } else {
            return modernOrderService.getOrder(orderId);
        }
    }
    
    public Order createOrder(CreateOrderRequest request) {
        // New orders always use modern service
        var order = modernOrderService.createOrder(request);
        
        // Optionally sync to legacy system for compatibility
        if (featureToggleService.isEnabled("sync-to-legacy")) {
            legacyOrderService.syncOrder(adaptModernOrder(order));
        }
        
        return order;
    }
    
    private boolean shouldUseLegacyService(UUID orderId) {
        // Check if order exists in modern system
        if (modernOrderService.exists(orderId)) {
            return false;
        }
        
        // Check feature toggle for gradual migration
        var migrationPercentage = featureToggleService.getPercentage("modern-order-service");
        var hash = orderId.hashCode() % 100;
        
        return hash >= migrationPercentage;
    }
}
```

### 5. Resilience Patterns

#### Bulkhead Pattern
**Intent**: Isolate resources to prevent cascading failures.

```java
@Configuration
public class BulkheadConfiguration {
    
    @Bean
    @Qualifier("orderProcessing")
    public Executor orderProcessingExecutor() {
        return new ThreadPoolTaskExecutor() {{
            setCorePoolSize(5);
            setMaxPoolSize(10);
            setQueueCapacity(25);
            setThreadNamePrefix("order-processing-");
            setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        }};
    }
    
    @Bean
    @Qualifier("notifications")
    public Executor notificationExecutor() {
        return new ThreadPoolTaskExecutor() {{
            setCorePoolSize(2);
            setMaxPoolSize(5);
            setQueueCapacity(50);
            setThreadNamePrefix("notifications-");
            setRejectedExecutionHandler(new ThreadPoolExecutor.DiscardOldestPolicy());
        }};
    }
    
    @Bean
    @Qualifier("analytics")
    public Executor analyticsExecutor() {
        return new ThreadPoolTaskExecutor() {{
            setCorePoolSize(1);
            setMaxPoolSize(3);
            setQueueCapacity(100);
            setThreadNamePrefix("analytics-");
            setRejectedExecutionHandler(new ThreadPoolExecutor.DiscardPolicy());
        }};
    }
}

@Service
public class OrderService {
    
    @Async("orderProcessing")
    public CompletableFuture<Order> processOrder(CreateOrderRequest request) {
        // Critical order processing in dedicated thread pool
        return CompletableFuture.completedFuture(createOrder(request));
    }
    
    @Async("notifications")
    public void sendOrderNotification(Order order) {
        // Non-critical notifications in separate thread pool
        notificationService.sendOrderConfirmation(order);
    }
    
    @Async("analytics")
    public void recordOrderAnalytics(Order order) {
        // Analytics processing in lowest priority thread pool
        analyticsService.recordOrderEvent(order);
    }
}
```

#### Timeout Pattern
**Intent**: Prevent resource exhaustion by setting maximum wait times.

```java
@Component
public class TimeoutConfiguration {
    
    @Bean
    public RestTemplate restTemplate() {
        var factory = new HttpComponentsClientHttpRequestFactory();
        factory.setConnectTimeout(5000);     // 5 seconds
        factory.setReadTimeout(10000);       // 10 seconds
        
        return new RestTemplate(factory);
    }
    
    @Bean
    public RedisTemplate<String, Object> redisTemplate() {
        var template = new RedisTemplate<String, Object>();
        template.setConnectionFactory(jedisConnectionFactory());
        
        // Set command timeout
        var jedisConfig = new JedisPoolConfig();
        jedisConfig.setMaxWaitMillis(2000);  // 2 seconds
        
        return template;
    }
}

// Service with timeout handling
@Service
public class ExternalApiService {
    
    @Autowired
    private RestTemplate restTemplate;
    
    @Retryable(value = {TimeoutException.class}, maxAttempts = 3)
    public ApiResponse callExternalApi(ApiRequest request) {
        try {
            return restTemplate.postForObject("/api/external", request, ApiResponse.class);
        } catch (ResourceAccessException e) {
            if (e.getCause() instanceof SocketTimeoutException) {
                throw new TimeoutException("External API call timed out", e);
            }
            throw e;
        }
    }
    
    @Recover
    public ApiResponse recoverFromTimeout(TimeoutException ex, ApiRequest request) {
        log.warn("External API call failed after retries, using fallback response");
        return ApiResponse.fallback();
    }
}
```

#### Retry Pattern with Backoff
**Intent**: Handle transient failures with intelligent retry strategies.

```java
@Component
public class RetryConfiguration {
    
    // Linear backoff
    @Bean
    @Qualifier("linearRetry")
    public RetryTemplate linearRetryTemplate() {
        return RetryTemplate.builder()
            .maxAttempts(3)
            .fixedBackoff(1000) // 1 second between retries
            .retryOn(TransientException.class)
            .build();
    }
    
    // Exponential backoff
    @Bean
    @Qualifier("exponentialRetry")
    public RetryTemplate exponentialRetryTemplate() {
        return RetryTemplate.builder()
            .maxAttempts(5)
            .exponentialBackoff(1000, 2, 10000) // 1s, 2s, 4s, 8s, 10s
            .retryOn(TransientException.class)
            .build();
    }
    
    // Exponential backoff with jitter
    @Bean
    @Qualifier("jitterRetry")
    public RetryTemplate jitterRetryTemplate() {
        var backoffPolicy = new ExponentialBackOffPolicy();
        backoffPolicy.setInitialInterval(1000);
        backoffPolicy.setMultiplier(2.0);
        backoffPolicy.setMaxInterval(10000);
        
        var retryPolicy = new SimpleRetryPolicy();
        retryPolicy.setMaxAttempts(5);
        
        var template = new RetryTemplate();
        template.setBackOffPolicy(backoffPolicy);
        template.setRetryPolicy(retryPolicy);
        
        // Add jitter
        template.setBackOffPolicy(new ExponentialRandomBackOffPolicy() {{
            setInitialInterval(1000);
            setMultiplier(2.0);
            setMaxInterval(10000);
        }});
        
        return template;
    }
}

@Service
public class PaymentService {
    
    @Autowired
    @Qualifier("jitterRetry")
    private RetryTemplate retryTemplate;
    
    public PaymentResult processPayment(PaymentRequest request) {
        return retryTemplate.execute(context -> {
            log.info("Processing payment, attempt {}", context.getRetryCount() + 1);
            
            try {
                return paymentGateway.processPayment(request);
            } catch (PaymentGatewayException e) {
                if (e.isRetryable()) {
                    throw new TransientException("Payment gateway temporarily unavailable", e);
                } else {
                    throw new PermanentException("Payment failed permanently", e);
                }
            }
        });
    }
}
```

## Implementation Roadmap

### Week 1-2: Foundation
- Service decomposition (logical)
- Basic API Gateway
- Shared libraries setup
- Simple retry patterns

### Week 3-4: Communication
- Service discovery
- Circuit breaker
- Load balancing
- Health checks

### Week 5-6: Data Patterns
- CQRS implementation
- Event store setup
- Basic projections
- Command/query separation

### Week 7-8: Advanced Data
- Event sourcing
- Saga orchestration
- Compensation patterns
- Event replay

### Week 9-10: Integration
- BFF implementation
- Anti-corruption layers
- Legacy system integration
- API versioning

### Week 11-12: Resilience
- Bulkhead pattern
- Timeout configuration
- Advanced retry strategies
- Failure injection testing

## Testing Strategy

### Pattern-Specific Testing
```java
// Test CQRS command/query separation
@Test
public void testCqrsSeparation() {
    // Given
    var command = new CreateOrderCommand(customerId, items);
    
    // When
    var orderId = commandHandler.handle(command);
    
    // Then - verify command side
    var aggregate = aggregateRepository.load(orderId);
    assertThat(aggregate.getStatus()).isEqualTo(OrderStatus.PENDING);
    
    // And verify query side (eventually consistent)
    await().atMost(5, SECONDS).until(() -> {
        var orderView = queryService.getOrderView(orderId);
        return orderView.getStatus().equals("PENDING");
    });
}

// Test circuit breaker
@Test
public void testCircuitBreakerTrip() {
    // Given - service is failing
    when(externalService.call()).thenThrow(new ServiceException());
    
    // When - multiple calls
    for (int i = 0; i < 5; i++) {
        try {
            serviceWithCircuitBreaker.callExternal();
        } catch (Exception e) {
            // Expected
        }
    }
    
    // Then - circuit breaker should be open
    assertThat(circuitBreaker.getState()).isEqualTo(CircuitBreakerState.OPEN);
    
    // And subsequent calls should fail fast
    var start = System.currentTimeMillis();
    try {
        serviceWithCircuitBreaker.callExternal();
    } catch (Exception e) {
        var duration = System.currentTimeMillis() - start;
        assertThat(duration).isLessThan(100); // Failed fast
    }
}
```

## Monitoring and Observability

### Pattern-Specific Metrics
```java
@Component
public class MicroservicesMetrics {
    
    private final MeterRegistry meterRegistry;
    
    // Circuit breaker metrics
    public void recordCircuitBreakerState(String circuitName, String state) {
        Gauge.builder("circuit_breaker.state")
            .tag("circuit", circuitName)
            .tag("state", state)
            .register(meterRegistry, this, value -> state.equals("OPEN") ? 1 : 0);
    }
    
    // Saga metrics
    public void recordSagaCompletion(String sagaType, String outcome, Duration duration) {
        Timer.builder("saga.duration")
            .tag("saga_type", sagaType)
            .tag("outcome", outcome)
            .register(meterRegistry)
            .record(duration);
    }
    
    // CQRS metrics
    public void recordCommandProcessing(String commandType, Duration duration) {
        Timer.builder("command.processing.duration")
            .tag("command_type", commandType)
            .register(meterRegistry)
            .record(duration);
    }
    
    public void recordQueryExecution(String queryType, Duration duration) {
        Timer.builder("query.execution.duration")
            .tag("query_type", queryType)
            .register(meterRegistry)
            .record(duration);
    }
}
```

---

This comprehensive guide provides a structured approach to implementing microservices patterns in the BitVelocity platform, ensuring gradual complexity introduction while maintaining production-ready standards.