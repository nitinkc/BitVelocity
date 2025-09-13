# Warehouse & Dimensional Modeling Guide
Version: 1.0  
Status: Draft  
Scope: Analytics & ML foundation (Delta/Iceberg over object storage)

## 1. Objectives
- Provide structured analytical layer (facts/dimensions).
- Support both batch (daily) and micro-batch (hourly) incremental loads.
- Enable SCD Type 2 for slowly changing entities (Product, Customer).
- Prepare feature derivation for ML (conversion rates, engagement scores).

## 2. Architecture Layers (Medallion)
| Layer | Content | Reliability | Storage |
|-------|---------|-------------|---------|
| Bronze | Raw CDC/outbox JSON events, telemetry | Append-only | Parquet (raw/) |
| Silver | Cleaned, typed, de-duplicated | Idempotent | Parquet (silver/) |
| Gold | Fact & Dim tables, aggregates | ACID (Delta/Iceberg) | parquet (gold/) |
| Feature | Curated ML features | Low-latency (Redis) + batch | redis + parquet |
| Semantic | BI-friendly marts (views) | Derived | SQL views |

## 3. Core Dimensions
| Dimension | Grain | SCD | Key Columns |
|-----------|-------|-----|-------------|
| DimProduct | Product version | Type 2 | product_sk (surrogate) |
| DimCustomer | Customer profile | Type 2 | customer_sk |
| DimTime | Minute or hour | Static | time_sk |
| DimRegion | Region code | Type 1 | region_sk |
| DimDevice | Device identity | Type 2 (firmware) | device_sk |

## 4. Facts
| Fact | Grain | Measures | Foreign Keys |
|------|-------|----------|--------------|
| FactOrder | 1 order line | qty, unit_price, total_amount | product_sk, customer_sk, time_sk, region_sk |
| FactOrderDaily | order per day per product | order_count, total_amount | product_sk, date_sk |
| FactTelemetryHourly | device-hour | avg_metric, max_metric | device_sk, time_sk |
| FactChatActivity | user-day | message_count | customer_sk, date_sk |
| FactFeedEngagement | post-day | impressions, clicks | product/post_sk, date_sk |

## 5. SCD Type 2 Implementation
Bronze event: `product.updated`
Silver job:
1. Compare hash of relevant attributes (name, category, brand).
2. If changed → close old row (`effective_to = NOW()`, `is_current=false`).
3. Insert new row with incremented `scd_version`, `effective_from = NOW()`.

Delta/Iceberg MERGE example (pseudo-SQL):
```sql
MERGE INTO dim_product t
USING staged_updates s
ON t.product_id = s.product_id AND t.is_current = true
WHEN MATCHED AND t.hash != s.hash THEN
  UPDATE SET is_current=false, effective_to = current_timestamp
WHEN NOT MATCHED THEN
  INSERT (product_sk, product_id, name, category, brand, scd_version, is_current, effective_from, effective_to, hash)
  VALUES (...,  s.hash);
```

## 6. Late Arriving Fact Handling
- Maintain “lateness watermark” per fact.
- If `occurred_at < watermark - grace_window` → mark as late.
- Recompute aggregate and emit correction event `analytics.fact.order.corrected`.

## 7. Data Quality Rules (Great Expectations Candidates)
| Table | Expectation |
|-------|-------------|
| dim_product | Non-null product_id |
| fact_order | total_amount = qty * unit_price |
| fact_order | qty > 0 |
| dim_customer | Exactly one `is_current=true` per customer_id |
| fact_chat_activity | message_count >= 0 |

## 8. Incremental Load Strategy
| Layer | Mode | Schedule |
|-------|------|----------|
| Bronze | Streaming (Debezium) | Continuous |
| Silver | Micro-batch (5 min) | Cron / streaming job |
| Gold (base facts) | Hourly micro-batch | Hourly |
| Gold (daily aggregates) | End-of-day batch | Nightly |
| Feature sync | Hourly & on-demand | Event-triggered |

## 9. Surrogate Key Generation
Use deterministic hash + sequence fallback:
```
product_sk = hash(product_id) % BIG_RANGE + sequence_offset
```
Maintains join performance vs text IDs.

## 10. Partitioning Strategy
| Table | Partition Key | Reason |
|-------|---------------|--------|
| fact_order | event_date (day) | Time-range queries |
| fact_order_daily | event_date | Natural daily access |
| fact_telemetry_hourly | event_date, hour | Filtering + pruning |
| dim_product | none / small | SCD narrow table |

## 11. Performance Optimizations
- Z-Order / clustering on (product_sk, event_date) if using Delta Lake.
- Bloom Filters for product_sk lookups (Delta).
- Compression codecs: ZSTD for mixed columns.
- Small file compaction job (target 256–512MB per file).

## 12. Security & Governance
- PII columns flagged with column tags (e.g. `pii:true`, `sensitivity:high`).
- Row-level filters for multi-tenant (future).
- Metadata catalog file `catalog.yaml` listing schema, owners, SLA.

## 13. Observability
Metrics:
- Pipeline latency (Bronze→Silver→Gold).
- Row counts delta vs expectation.
- Late event count.
- SCD churn rate per dimension per day.
Log lineage via OpenLineage integration in each job.

## 14. Backlog Seeds
- Story: Create Bronze ingestion schema repo + schema registry integration.
- Story: Implement Silver normalization job (orders).
- Story: Add Great Expectations suite for FactOrder and DimProduct.
- Story: Implement SCD2 logic for products.
- Story: Add micro-batch automation (GitHub Action runner local Spark).

## 15. Future Extensions
- Slowly Changing Fact (rare).
- Snapshot fact tables (inventory level EOD).
- Semantic Layer (dbt / metrics layer).

---