# Data Architecture Strategy

## Purpose
This document defines the comprehensive data architecture for BitVelocity, including OLTP to OLAP data flows, audit database strategy, data governance, and analytics patterns that address the gaps identified in the original design.

## Architecture Overview

### Data Layer Strategy
```
┌─────────────────────────────────────────────────────────────────┐
│                        OLTP Layer                               │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐│
│  │ PostgreSQL  │ │  Cassandra  │ │   MongoDB   │ │    Redis    ││
│  │(Transaction)│ │ (Scale-out) │ │ (Document)  │ │  (Cache)    ││
│  └─────┬───────┘ └─────┬───────┘ └─────┬───────┘ └─────┬───────┘│
└─────────┼───────────────┼───────────────┼───────────────┼────────┘
          │               │               │               │
          │          ┌────▼─────────────────▼─────────────▼───┐
          │          │         Change Data Capture          │
          │          │        (Debezium CDC)                │
          │          └────┬─────────────────────────────────┘
          │               │
          ▼               ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Event Streaming Layer                        │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐│
│  │    Kafka    │ │    NATS     │ │  RabbitMQ   │ │ Schema Reg  ││
│  │ (Streaming) │ │(Lightweight)│ │ (Reliable)  │ │ (Governance)││
│  └─────┬───────┘ └─────────────┘ └─────────────┘ └─────────────┘│
└─────────┼───────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│              OLAP Layer (Bronze → Silver → Gold)               │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐│
│  │   Bronze    │ │   Silver    │ │    Gold     │ │   Serving   ││
│  │ (Raw Data)  │ │ (Cleaned)   │ │ (Business)  │ │   Layer     ││
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

## OLTP Database Strategy

### Primary Transactional Database: PostgreSQL

#### Table Design with Audit Strategy
Every business entity includes comprehensive audit columns:

```sql
-- Standard audit columns for all tables
CREATE TABLE audit_base (
    id BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_by VARCHAR(255) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(255) NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    deleted_at TIMESTAMP WITH TIME ZONE NULL,
    deleted_by VARCHAR(255) NULL
);

-- Example: Orders table with audit
CREATE TABLE orders (
    order_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'PENDING',
    total_amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    
    -- Audit columns
    LIKE audit_base INCLUDING ALL,
    
    -- Partitioning key
    created_date DATE GENERATED ALWAYS AS (created_at::DATE) STORED
) PARTITION BY RANGE (created_date);

-- Audit trail table for complete change history
CREATE TABLE orders_audit (
    audit_id BIGSERIAL PRIMARY KEY,
    order_id UUID NOT NULL,
    operation_type VARCHAR(10) NOT NULL, -- INSERT, UPDATE, DELETE
    operation_timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    operation_user VARCHAR(255) NOT NULL,
    old_values JSONB,
    new_values JSONB,
    correlation_id UUID -- For tracing changes across services
);
```

#### Partitioning Strategy

**Time-Based Partitioning** for high-volume tables:
```sql
-- Monthly partitions for orders
CREATE TABLE orders_y2024m01 PARTITION OF orders
FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

-- Automated partition management
SELECT partman.create_parent(
    p_parent_table => 'public.orders',
    p_control => 'created_date',
    p_type => 'range',
    p_interval => 'monthly',
    p_premake => 2
);
```

### Scale-Out Databases

#### Cassandra for High-Volume Event Data
```cql
-- Chat messages with time-series pattern
CREATE TABLE chat_messages (
    room_id UUID,
    message_time TIMEUUID,
    user_id UUID,
    message_text TEXT,
    metadata MAP<TEXT, TEXT>,
    
    -- Audit fields
    created_by TEXT,
    trace_id TEXT,
    
    PRIMARY KEY (room_id, message_time)
) WITH CLUSTERING ORDER BY (message_time DESC);

-- IoT telemetry data
CREATE TABLE device_telemetry (
    device_id UUID,
    timestamp TIMESTAMP,
    sensor_type TEXT,
    sensor_value DOUBLE,
    
    -- Partitioning by device and time
    PRIMARY KEY ((device_id, sensor_type), timestamp)
) WITH CLUSTERING ORDER BY (timestamp DESC);
```

#### MongoDB for Document-Heavy Domains
```javascript
// Social media posts with flexible schema
{
  _id: ObjectId,
  user_id: UUID,
  content: {
    text: String,
    media: [{
      type: String, // image, video, link
      url: String,
      metadata: Object
    }],
    hashtags: [String],
    mentions: [UUID]
  },
  engagement: {
    likes: Number,
    shares: Number,
    comments: Number
  },
  // Audit fields
  created_at: ISODate,
  created_by: String,
  updated_at: ISODate,
  updated_by: String,
  version: Number,
  trace_id: String
}
```

## OLTP to OLAP Data Flow

### Change Data Capture (CDC) Strategy

#### Debezium Configuration
```yaml
# Debezium connector for PostgreSQL
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaConnector
metadata:
  name: postgres-orders-connector
spec:
  class: io.debezium.connector.postgresql.PostgresConnector
  tasksMax: 3
  config:
    database.hostname: postgres-primary
    database.port: 5432
    database.user: debezium
    database.password: ${DEBEZIUM_PASSWORD}
    database.dbname: bitvelocity
    database.server.name: postgres-orders
    table.include.list: public.orders,public.order_items,public.payments
    plugin.name: pgoutput
    transforms: unwrap
    transforms.unwrap.type: io.debezium.transforms.ExtractNewRecordState
    key.converter: org.apache.kafka.connect.json.JsonConverter
    value.converter: org.apache.kafka.connect.json.JsonConverter
```

#### Event Schema with Audit Context
```json
{
  "schema": {
    "type": "struct",
    "fields": [
      {"field": "order_id", "type": "string"},
      {"field": "customer_id", "type": "string"},
      {"field": "status", "type": "string"},
      {"field": "total_amount", "type": "double"},
      {"field": "created_at", "type": "string"},
      {"field": "created_by", "type": "string"},
      {"field": "updated_at", "type": "string"},
      {"field": "updated_by", "type": "string"},
      {"field": "version", "type": "int32"}
    ]
  },
  "payload": {
    "order_id": "550e8400-e29b-41d4-a716-446655440000",
    "customer_id": "123e4567-e89b-12d3-a456-426614174000",
    "status": "CONFIRMED",
    "total_amount": 99.99,
    "created_at": "2024-01-15T10:30:00Z",
    "created_by": "customer-service",
    "updated_at": "2024-01-15T10:35:00Z",
    "updated_by": "payment-service",
    "version": 2
  },
  "metadata": {
    "operation": "UPDATE",
    "source": "orders",
    "timestamp": "2024-01-15T10:35:00Z",
    "transaction_id": "txn_123456",
    "lsn": "24/3F000140"
  }
}
```

### Medallion Architecture: Bronze → Silver → Gold

#### Bronze Layer (Raw Data Ingestion)
```sql
-- Raw events from Kafka stored in Delta Lake format
CREATE TABLE bronze_orders (
    event_id UUID DEFAULT gen_random_uuid(),
    event_timestamp TIMESTAMP WITH TIME ZONE,
    source_system VARCHAR(100),
    operation_type VARCHAR(20),
    table_name VARCHAR(100),
    raw_payload JSONB,
    
    -- Partitioning for efficient querying
    ingestion_date DATE GENERATED ALWAYS AS (event_timestamp::DATE) STORED
) PARTITION BY RANGE (ingestion_date);

-- Example bronze record
INSERT INTO bronze_orders (event_timestamp, source_system, operation_type, table_name, raw_payload)
VALUES (
    NOW(),
    'postgres-orders',
    'UPDATE',
    'orders',
    '{"order_id": "550e8400-e29b-41d4-a716-446655440000", "status": "CONFIRMED", ...}'
);
```

#### Silver Layer (Cleaned and Standardized)
```sql
-- Cleaned, typed, and standardized data
CREATE TABLE silver_orders (
    order_id UUID PRIMARY KEY,
    customer_id UUID NOT NULL,
    status order_status_enum NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    order_date DATE NOT NULL,
    
    -- Data quality indicators
    data_quality_score DECIMAL(3,2),
    quality_checks_passed TEXT[],
    quality_issues TEXT[],
    
    -- Lineage information
    source_bronze_id UUID,
    processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processing_version VARCHAR(20)
) PARTITION BY RANGE (order_date);

-- ETL process to transform bronze to silver
CREATE OR REPLACE FUNCTION bronze_to_silver_orders()
RETURNS VOID AS $$
BEGIN
    INSERT INTO silver_orders (
        order_id, customer_id, status, total_amount, currency, order_date,
        data_quality_score, source_bronze_id
    )
    SELECT 
        (raw_payload->>'order_id')::UUID,
        (raw_payload->>'customer_id')::UUID,
        (raw_payload->>'status')::order_status_enum,
        (raw_payload->>'total_amount')::DECIMAL(10,2),
        COALESCE(raw_payload->>'currency', 'USD'),
        (raw_payload->>'created_at')::DATE,
        calculate_quality_score(raw_payload),
        event_id
    FROM bronze_orders
    WHERE operation_type = 'INSERT'
    AND ingestion_date = CURRENT_DATE
    ON CONFLICT (order_id) DO UPDATE SET
        status = EXCLUDED.status,
        total_amount = EXCLUDED.total_amount,
        processed_at = NOW();
END;
$$ LANGUAGE plpgsql;
```

#### Gold Layer (Business Logic and Aggregations)
```sql
-- Business-ready dimensional model
CREATE TABLE gold_order_facts (
    fact_id BIGSERIAL PRIMARY KEY,
    order_date_key INTEGER, -- Links to date dimension
    customer_key INTEGER,   -- Links to customer dimension
    product_key INTEGER,    -- Links to product dimension
    
    -- Measures
    order_count INTEGER DEFAULT 1,
    total_amount DECIMAL(12,2),
    discount_amount DECIMAL(12,2),
    tax_amount DECIMAL(12,2),
    shipping_amount DECIMAL(12,2),
    
    -- Slowly Changing Dimension tracking
    valid_from TIMESTAMP WITH TIME ZONE,
    valid_to TIMESTAMP WITH TIME ZONE,
    is_current BOOLEAN DEFAULT TRUE,
    
    -- Lineage
    source_silver_order_id UUID,
    etl_batch_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Daily sales aggregations
CREATE MATERIALIZED VIEW gold_daily_sales AS
SELECT 
    order_date_key,
    COUNT(*) as order_count,
    SUM(total_amount) as total_revenue,
    AVG(total_amount) as avg_order_value,
    COUNT(DISTINCT customer_key) as unique_customers
FROM gold_order_facts
WHERE is_current = TRUE
GROUP BY order_date_key;
```

## Real-Time Analytics

### Kafka Streams Processing
```java
@Component
public class OrderAnalyticsStream {
    
    @Autowired
    public void processOrderEvents(StreamsBuilder builder) {
        KStream<String, OrderEvent> orderStream = builder
            .stream("orders-topic", Consumed.with(Serdes.String(), orderEventSerde));
        
        // Real-time revenue calculation
        KTable<Windowed<String>, Double> revenueByHour = orderStream
            .filter((key, order) -> "CONFIRMED".equals(order.getStatus()))
            .groupByKey()
            .windowedBy(TimeWindows.of(Duration.ofHours(1)))
            .aggregate(
                () -> 0.0,
                (key, order, aggregate) -> aggregate + order.getTotalAmount(),
                Materialized.with(Serdes.String(), Serdes.Double())
            );
        
        // Output to analytics topic
        revenueByHour
            .toStream()
            .to("hourly-revenue-topic");
    }
}
```

### Feature Store Integration
```java
@Entity
@Table(name = "customer_features")
public class CustomerFeatures {
    @Id
    private UUID customerId;
    
    // Real-time features
    private Integer orderCountLast30Days;
    private BigDecimal totalSpentLast30Days;
    private Double avgOrderValue;
    private String preferredCategory;
    
    // Batch features
    private String lifetimeSegment;
    private Integer lifetimeOrderCount;
    private BigDecimal lifetimeValue;
    
    // Feature freshness tracking
    @Column(name = "features_updated_at")
    private Instant featuresUpdatedAt;
    
    @Column(name = "feature_version")
    private String featureVersion;
}
```

## Data Governance & Quality

### Schema Registry and Evolution
```json
{
  "type": "record",
  "name": "OrderEvent",
  "namespace": "com.bitvelocity.events",
  "version": "v2",
  "fields": [
    {"name": "orderId", "type": "string"},
    {"name": "customerId", "type": "string"},
    {"name": "status", "type": {"type": "enum", "symbols": ["PENDING", "CONFIRMED", "SHIPPED", "DELIVERED", "CANCELLED"]}},
    {"name": "totalAmount", "type": "double"},
    {"name": "currency", "type": "string", "default": "USD"},
    {
      "name": "auditInfo", 
      "type": {
        "type": "record",
        "name": "AuditInfo",
        "fields": [
          {"name": "createdAt", "type": "long"},
          {"name": "createdBy", "type": "string"},
          {"name": "traceId", "type": ["null", "string"], "default": null}
        ]
      }
    }
  ]
}
```

### Data Quality Framework
```sql
-- Data quality rules table
CREATE TABLE data_quality_rules (
    rule_id UUID PRIMARY KEY,
    table_name VARCHAR(100),
    column_name VARCHAR(100),
    rule_type VARCHAR(50), -- NOT_NULL, RANGE, PATTERN, REFERENCE
    rule_config JSONB,
    severity VARCHAR(20), -- ERROR, WARNING, INFO
    is_active BOOLEAN DEFAULT TRUE
);

-- Example quality rules
INSERT INTO data_quality_rules VALUES
('rule-001', 'orders', 'total_amount', 'RANGE', '{"min": 0, "max": 10000}', 'ERROR', true),
('rule-002', 'orders', 'email', 'PATTERN', '{"regex": "^[^@]+@[^@]+\\.[^@]+$"}', 'ERROR', true),
('rule-003', 'orders', 'customer_id', 'REFERENCE', '{"table": "customers", "column": "id"}', 'ERROR', true);

-- Quality check results
CREATE TABLE data_quality_results (
    check_id UUID PRIMARY KEY,
    rule_id UUID REFERENCES data_quality_rules(rule_id),
    checked_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    record_count INTEGER,
    failed_count INTEGER,
    success_rate DECIMAL(5,2),
    sample_failures JSONB
);
```

### Data Lineage Tracking
```sql
-- Data lineage tracking
CREATE TABLE data_lineage (
    lineage_id UUID PRIMARY KEY,
    source_dataset VARCHAR(200),
    target_dataset VARCHAR(200),
    transformation_type VARCHAR(100),
    transformation_config JSONB,
    dependency_level INTEGER, -- 1=direct, 2=indirect, etc.
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- OpenLineage integration
INSERT INTO data_lineage VALUES
('lineage-001', 'postgres.public.orders', 'bronze_orders', 'CDC_CAPTURE', '{"connector": "debezium"}', 1, NOW()),
('lineage-002', 'bronze_orders', 'silver_orders', 'ETL_TRANSFORM', '{"job": "bronze_to_silver_orders"}', 2, NOW()),
('lineage-003', 'silver_orders', 'gold_order_facts', 'DIMENSIONAL_MODEL', '{"type": "fact_table"}', 3, NOW());
```

## Caching Strategy

### Multi-Layer Caching Architecture
```java
@Component
public class CacheStrategy {
    
    // L1: Application-level cache
    @Cacheable(value = "products", key = "#productId")
    public Product getProduct(UUID productId) {
        return productRepository.findById(productId);
    }
    
    // L2: Distributed cache
    @Autowired
    private RedisTemplate<String, Object> redisTemplate;
    
    public CustomerProfile getCustomerProfile(UUID customerId) {
        String cacheKey = "customer:" + customerId;
        CustomerProfile cached = (CustomerProfile) redisTemplate.opsForValue().get(cacheKey);
        
        if (cached == null) {
            cached = buildCustomerProfile(customerId);
            redisTemplate.opsForValue().set(cacheKey, cached, Duration.ofMinutes(30));
        }
        
        return cached;
    }
    
    // Cache warming strategy
    @Scheduled(fixedRate = 300000) // Every 5 minutes
    public void warmTopProducts() {
        List<UUID> topProductIds = analyticsService.getTopSellingProducts(100);
        topProductIds.forEach(this::getProduct);
    }
}
```

### Cache Invalidation Patterns
```java
@EventListener
public class CacheInvalidationHandler {
    
    @Autowired
    private CacheManager cacheManager;
    
    @KafkaListener(topics = "product-updates")
    public void handleProductUpdate(ProductUpdateEvent event) {
        Cache productCache = cacheManager.getCache("products");
        productCache.evict(event.getProductId());
        
        // Invalidate related caches
        if (event.isCategoryChange()) {
            Cache categoryCache = cacheManager.getCache("categories");
            categoryCache.evict(event.getCategoryId());
        }
    }
}
```

## Performance Optimization

### Database Optimization
```sql
-- Index strategies for common query patterns
CREATE INDEX CONCURRENTLY idx_orders_customer_date 
ON orders (customer_id, created_date DESC) 
WHERE deleted_at IS NULL;

-- Partial index for active orders
CREATE INDEX CONCURRENTLY idx_orders_active_status 
ON orders (status, created_date DESC) 
WHERE status IN ('PENDING', 'CONFIRMED', 'PROCESSING');

-- BRIN index for time-series data
CREATE INDEX idx_telemetry_timestamp_brin 
ON device_telemetry USING BRIN (timestamp);

-- Query optimization monitoring
CREATE OR REPLACE FUNCTION track_slow_queries() 
RETURNS TRIGGER AS $$
BEGIN
    IF (EXTRACT(EPOCH FROM (clock_timestamp() - statement_timestamp())) > 1.0) THEN
        INSERT INTO slow_query_log (query, duration, executed_at)
        VALUES (current_query(), EXTRACT(EPOCH FROM (clock_timestamp() - statement_timestamp())), NOW());
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;
```

## Disaster Recovery & Backup

### Backup Strategy
```yaml
# Automated backup configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: backup-config
data:
  postgres-backup.sh: |
    #!/bin/bash
    DATE=$(date +%Y%m%d_%H%M%S)
    
    # Full database backup
    pg_dump -h $POSTGRES_HOST -U $POSTGRES_USER -d bitvelocity \
      --format=custom --compress=9 \
      --file="/backups/full_backup_${DATE}.dump"
    
    # Incremental WAL archiving
    archive_command = 'cp %p /archive/%f'
    
    # Upload to cloud storage
    aws s3 cp "/backups/full_backup_${DATE}.dump" \
      "s3://bitvelocity-backups/postgres/${DATE}/"
```

### Cross-Region Replication
```sql
-- PostgreSQL streaming replication setup
-- Primary server configuration
wal_level = replica
max_wal_senders = 3
wal_keep_segments = 32
archive_mode = on
archive_command = 'cp %p /archive/%f'

-- Create replication user
CREATE USER replicator REPLICATION LOGIN PASSWORD 'secure_password';

-- Replica server setup
standby_mode = 'on'
primary_conninfo = 'host=primary_host port=5432 user=replicator'
restore_command = 'cp /archive/%f %p'
```

## Monitoring & Alerting

### Data Pipeline Monitoring
```java
@Component
public class DataPipelineMonitor {
    
    @Autowired
    private MeterRegistry meterRegistry;
    
    @EventListener
    public void handleDataProcessingEvent(DataProcessingEvent event) {
        Timer.Sample sample = Timer.start(meterRegistry);
        
        try {
            // Process data
            sample.stop(Timer.builder("data.processing.duration")
                .tag("pipeline", event.getPipelineName())
                .tag("status", "success")
                .register(meterRegistry));
                
            meterRegistry.counter("data.records.processed",
                "pipeline", event.getPipelineName())
                .increment(event.getRecordCount());
                
        } catch (Exception e) {
            sample.stop(Timer.builder("data.processing.duration")
                .tag("pipeline", event.getPipelineName())
                .tag("status", "error")
                .register(meterRegistry));
                
            meterRegistry.counter("data.processing.errors",
                "pipeline", event.getPipelineName(),
                "error_type", e.getClass().getSimpleName())
                .increment();
        }
    }
}
```

## Cost Optimization

### Storage Cost Management
- **Data Lifecycle Policies**: Automated archival of old partitions
- **Compression**: Use appropriate compression for different data types
- **Tiered Storage**: Hot, warm, and cold storage strategies
- **Query Optimization**: Efficient queries to reduce compute costs

### Resource Scaling
- **Auto-scaling**: Scale compute resources based on workload
- **Spot Instances**: Use spot instances for batch processing
- **Reserved Capacity**: Reserve capacity for predictable workloads
- **Resource Monitoring**: Track resource utilization and costs

---

This data architecture provides a solid foundation for learning comprehensive data engineering patterns while maintaining production-ready standards and addressing all the gaps identified in the original design.