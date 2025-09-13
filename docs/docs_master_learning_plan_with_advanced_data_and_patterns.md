# BitVelocity Master Learning Plan (Expanded)
Comprehensive Architecture, Learning Roadmap, Advanced Data & Microservices Patterns

This file consolidates:
- Previous “starting point” & roadmap guidance
- Gap analysis findings
- Newly added advanced topics: DB sharding, partitioning, query optimization, data warehousing / lakehouse, microservices architectural & integration patterns
- Budgeting + incremental execution strategy suitable for a CTO/Architect mindset with limited weekly capacity (2–3 devs × 10–15h each)

---

## 1. Executive Snapshot

**Mission:** Build a multi-domain, protocol-rich, cloud-portable distributed platform for hands‑on mastery of modern backend & data/AI systems—while minimizing cost.

**Guiding Tenets:**
1. Learn breadth with sufficiently real patterns (not toy “hello world”).
2. Keep domain logic intentionally simple to focus on architecture.
3. Enforce incremental ratcheting: no new protocol/tech until prior baseline stabilized & observed.
4. Portability first (Pulumi abstractions, avoid provider lock-in).
5. “Shift left” on observability, security, cost control, data governance.

---

## 2. What Was Missing (Gap Analysis Summary)

| Area | Gaps Identified | Added Now |
|------|-----------------|-----------|
| DB Architecture | No explicit sharding / partitioning taxonomy, replica strategy, multi-modal design heuristics | Comprehensive sharding matrix, Postgres partitioning, Cassandra/Mongo shard key design |
| Query Optimization | No systematic workflow | EXPLAIN methodology, plan hash tracking, bloat mgmt, indexing strategy catalog |
| Transactional Messaging | Only generic “events” | Outbox pattern schema + Debezium CDC pipeline plan |
| Data Warehousing | Absent Medallion / dimensional modeling | Bronze–Silver–Gold pipeline, SCD2, fact/dimension blueprint |
| Streaming + CDC Integration | Not concretely tied to data models | CDC → Bronze → transform → materialized projections |
| Microservices Patterns | Lacked depth (Saga, CQRS, ES, BFF, ACL, Strangler, Idempotency) | Full catalog with domain mapping & adoption sequence |
| Caching Strategy | Partial examples only | Multi-layer (L1, L2, negative, refresh-ahead, Bloom, hot set) |
| Observability Advanced | Only baseline metrics/tracing | Tail sampling, plan drift, lineage, embedding trace ctx in Kafka headers |
| Governance & Data Quality | Missing lineage + schema compat enforcement details | OpenLineage, Great Expectations, schema registry policies |
| AI/Vector Layer | General mention only | Vector DB, embedding pipeline, feature store, RAG plan |
| Cost & Capacity Engineering | Only rough costs | Partition growth, cost per feature KPI, autoscaling heuristics |
| Security Data Layer | Missing RLS, column masking, transit encryption specifics | Added Vault Transit, RLS, field-level encryption strategy |

---

## 3. Starting Point (First 2–3 Weeks)

| Priority | Deliverable | Rationale | Acceptance Signal |
|----------|-------------|-----------|-------------------|
| P0 | Monorepo skeleton (parent BOM/POM + libs) | Consistency & reuse | Builds + shared version alignment |
| P0 | Pulumi local infra skeleton (kind, Postgres, Redis, Kafka) | Foundation for all protocols | `pulumi up` outputs endpoints |
| P0 | Auth Service (JWT issue/verify) | Cross-cutting dependency | Token verified by Product |
| P0 | Product Service (REST CRUD + Flyway + tests) | First baseline domain slice | CRUD + integration tests pass |
| P1 | Order Service (REST + emits OrderCreated) | Introduce eventing early | Kafka topic receives event |
| P1 | OpenTelemetry + Prometheus baseline | Instrumentation before scaling | Traces appear in collector |
| P1 | Redis cache (Product read-through) | Show caching fundamentals early | Cache hit ratio metric exported |
| P2 | Decision Log + ADR format started | Architectural discipline | ADR #1–#3 committed |

Avoid premature: GraphQL, gRPC, IoT, warehouse, multi-region—until above stable.

---

## 4. High-Level Layered Throughline

1. Core CRUD + Auth
2. Events + Caching
3. Real-time (WebSocket / Notifications)
4. Internal RPC (gRPC) & GraphQL aggregator
5. Legacy + Integration (Webhooks, SOAP)
6. IoT + MQTT + Retry Queue (RabbitMQ)
7. Stream Processing + Batch
8. Multi-region replication (Kafka / DB read replicas)
9. DR drills + Failover automation
10. Cloud portability (GCP → AWS)
11. Advanced data (partitioning, warehouse, SCD, Outbox/CDC)
12. AI/ML + Vector + Feature Store
13. Governance (lineage, quality, schema compatibility)
14. Performance, chaos, cost, resilience hardening

---

## 5. Advanced Database Strategy

### 5.1 Sharding & Partitioning Matrix

| Pattern | Best For | Pros | Cons | Example Mapping |
|---------|----------|------|------|-----------------|
| Time (Range) Partition | Append-heavy time-series (telemetry, order history) | Efficient pruning & retention | “Hot” last partition hotspot | Orders monthly partitions |
| Hash Shard | Even write distribution (chat msgs) | Uniform spread | Cross-shard joins expensive | Chat messages (hash userId) |
| Geo Partition (Region) | Latency-critical user locality | Fast read/write local | Cross-region writes complex | Inventory read, feed read views |
| Hybrid (Time + Hash) | Large scale + concurrency | Avoids single “now” hotspot | More complex key mgmt | Telemetry (month then device hash) |
| Functional / Domain Split | Natural bounded contexts | Autonomy & scaling | Global queries require federation | Orders vs Inventory DB clusters |
| Vertical (Table Category) | Mixed workloads (OLTP vs analytics) | Isolation of query shapes | Data duplication risk | Move analytics to warehouse |
| Federated Read Replicas | Read scaling & offloads heavy queries | Simple adoption | Replica lag | Postgres replica for reports |

### 5.2 Postgres Partition Playbook
- Declarative RANGE partition on orders.created_at (monthly).
- Use `pg_partman` to automate create + detach + drop.
- Indexes:
  - B-Tree on (order_id)
  - BRIN on (created_at) for large partitions
  - Partial index (status='OPEN') for dashboards
- Maintenance:
  - VACUUM schedule per partition
  - Monitor bloat (pg_stat_all_tables)
  - Track plan hashes (capture baseline EXPLAIN)

### 5.3 Cassandra / Mongo Shard Key Guidance
| Store | Pitfall | Mitigation |
|-------|---------|------------|
| Cassandra | Hot partition (monotonic key) | Composite key (customer_id, month) |
| MongoDB | Low cardinality shard key | Use hashed high-card field |
| Both | Large partition growth | TTL or compaction window strategy |

### 5.4 Query Optimization Workflow
1. Identify slow queries (pg_stat_statements top N > threshold).
2. Capture baseline: `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)` commit plan artifact.
3. Diagnose: Check seq vs index scan, filter selectivity, join order.
4. Index design: Covering indexes; avoid overlapping duplicates.
5. Reduce bloat: periodic `VACUUM (FULL)` only if necessary; prefer autovacuum tuning.
6. Plan Stability: Compare plan hash diffs; alert on change causing regression.
7. Pool Sizing: Start at (2 × vCPU) + effective_io_threads; watch for wait events (active vs idle).
8. Leverage prepared statements & parameter binding to avoid parse overhead.

### 5.5 Transactional Messaging (Outbox + CDC)
Outbox Table:
| Column | Type | Notes |
|--------|------|------|
| id | UUID | PK |
| aggregate_type | TEXT | e.g. ORDER |
| aggregate_id | TEXT | Domain identifier |
| event_type | TEXT | ecommerce.order.created.v1 |
| payload_json | JSONB | Canonical schema |
| occurred_at | TIMESTAMPTZ | Event time |
| published_at | TIMESTAMPTZ NULL | Mark after Debezium ack (optional) |
| trace_id | TEXT | Observability propagation |
| partition_key | TEXT | For Kafka partition affinity |

Pipeline:
1. Local transaction writes domain row + outbox row.
2. Debezium connector streams outbox inserts.
3. Kafka topic receives canonical event.
4. Consumer idempotency (store event id in Redis set with TTL).
5. Optional cleanup job (partition & archive older events).

---

## 6. Caching Strategy (Expanded)

| Layer | Technology | Use | Pattern | Extra Considerations |
|-------|------------|-----|---------|----------------------|
| L1 In-process | Caffeine | Hot, tiny keyset | Time-based expire | Keep TTL short (1–5s) |
| L2 Distributed | Redis | Shared product / inventory | Cache-aside | Metrics: hit/miss/export |
| Negative Cache | Redis | Avoid DB stampede on 404 | Short TTL | Separate key namespace: `neg:product:<id>` |
| Refresh-Ahead | Redis + Scheduler | Flash pricing, feed | Proactive repopulation | Refill before 80% TTL |
| Write-Behind | Event consumers | Denormalized feed list | Async materialize | Watch for eventual staleness |
| Bloom Filter | Redis module / Java | Filter non-existent | Pre-check before DB | Periodic rebuild |
| Multi-Region | Redis regional | Latency + isolation | Event bus invalidation | Accept eventual drift (<2s) |

Cache Metrics to Track: hit_ratio, hot_key_frequency (top N), stampede_count (fallback path spikes).

---

## 7. Data Warehousing & Lakehouse (Medallion)

| Layer | Characteristics | Implementation Plan |
|-------|-----------------|---------------------|
| Bronze | Raw, append-only CDC + telemetry | Debezium → Kafka → Parquet (MinIO + Delta/Iceberg) |
| Silver | Cleansed, conformed, deduped | Spark/Flink jobs (schema normalization) |
| Gold | Aggregated, analytics-ready | Fact & Dim tables, SCD2 product dimension |
| Feature Store | ML-serving features | Redis (hot) + Delta offline store |
| Semantic / Marts | Domain-specific curated sets | Materialized views, aggregated parquet |
| Governance | Quality + lineage | Great Expectations + OpenLineage |

### 7.1 Dimensional Modeling Example
- FactOrder(order_sk, product_sk, customer_sk, time_sk, quantity, unit_price, total_amount, region_sk, payment_method, status)
- DimProduct(product_sk, product_id, name, category, brand, scd_version, effective_from, effective_to, is_current)
- DimCustomer(customer_sk, customer_id, segment, region, lifecycle_stage)
- DimTime(time_sk, date, day_of_week, hour, is_weekend)

### 7.2 SCD Type 2 Flow
1. Receive ProductUpdated CDC event.
2. Look up current DimProduct row (is_current=true).
3. Set effective_to = now, is_current=false.
4. Insert new row with new scd_version, is_current=true.

### 7.3 Late Arriving Facts
- Stage events if occurred_at < watermark
- Recompute affected aggregates
- Emit correction event: `analytics.order.fact.corrected.v1`

---

## 8. Microservices Architectural Patterns (Adoption Catalogue)

| Pattern | Purpose | Domain Target | When to Introduce |
|---------|---------|---------------|-------------------|
| Saga (Choreography) | Distributed transaction via events | Order fulfillment (reserve inventory → payment → shipping) | After basic events stable (S4–S5) |
| Saga (Orchestration) | Central controller & compensations | Complex multi-step payment flows | Later if need visibility |
| Outbox Pattern | Reliable publish | All event producers | Sprint 5+ |
| CQRS | Split read/write scalability | Orders dashboard, feed service | Sprint 6–7 |
| Event Sourcing (Selective) | Reconstruct state + audit | Inventory adjustments | Sprint 7+ |
| BFF (Backend for Frontend) | Tailored API per client | Mobile vs Admin UI | After GraphQL baseline |
| Strangler Fig | Legacy replacement | Payment SOAP → REST | During integration sprints |
| Anti-Corruption Layer | Isolate legacy semantics | SOAP payment, external partner | Sprint 5 |
| Idempotent Consumer | Avoid double processing | Notification, Payment, Inventory updates | As soon as retries appear |
| Bulkhead | Resource isolation | Chat vs Order executors | S6–S7 |
| Circuit Breaker | Contain downstream failure | Payment, Inventory gRPC | Early (S3) |
| Rate Limiting + Load Shedding | Protect core services | Gateway & Notification | S5+ |
| Distributed ID Generation (ULID/Snowflake) | Sortable unique IDs | Orders, Events | Early (S2–S3) |
| API Composition | Real-time aggregate queries | GraphQL aggregator | S4 |
| Policy as Code (OPA) | Dynamic authorization | Order update restrictions | S5 |

---

## 9. Observability Enhancements

| Topic | Enhancement | Tools |
|-------|------------|-------|
| Traces | Tail-based sampling keep all errors | Tempo/Jaeger + collector |
| Events | Span context propagation → Kafka headers | OTEL instrumentation |
| DB Perf | Plan hash diff alert | Custom exporter + Prometheus |
| Metrics | SLO Error Budget gating CI | GitHub Action + SLO config |
| Logs | Redaction & PII masking pipeline | Logstash filter |
| Profiling | Continuous CPU/Heap sampling | Parca / Pyroscope |
| Data Lineage | Track dataset flows | OpenLineage, Marquez |
| Trace–Metric Bridge | Exemplars linking | Prometheus exemplars config |

---

## 10. Security & Data Privacy (Additions)

| Layer | Enhancement |
|-------|------------|
| DB | Row-Level Security (tenant/user scoping for Orders) |
| Column-Level Protection | Vault Transit encrypt sensitive fields (payment_token) |
| Masking | Views or projection service masking PII in analytics |
| Tokenization | Replace card fragments with reversible tokens |
| Policy | OPA fine-grained ABAC (role + order owner + status) |
| Secrets | Dynamic DB creds rotation (Vault leases) |
| Privacy Analytics | Noise injection for aggregate exports (learning exercise) |

---

## 11. AI / ML & Vector Layer Roadmap

| Component | Purpose | Implementation |
|-----------|---------|----------------|
| Embedding Pipeline | Convert product text to vectors | Open-source sentence transformer (MiniLM) |
| Vector DB | Semantic product search | Qdrant / Weaviate / OpenSearch vector |
| Feature Store | Real-time rec features | Redis (hot) + Delta offline sync |
| Model Serving | REST/gRPC inference | Lightweight service (Java or Python) |
| Shadow Deploy | Compare candidate vs prod | Dual inference log divergence |
| Canary Release | Gradual traffic shift | Gateway header-based routing |
| RAG (Optional) | Knowledge QA (docs + events) | Embed docs + retrieval layer |
| Anomaly Detection | Telemetry stats | Sliding window z-score (Flink/KStreams) |

---

## 12. Governance & Data Quality

| Component | Purpose |
|----------|---------|
| Schema Registry Policy | Enforce backward compatibility |
| Great Expectations | Validate Silver layer (nulls, referential integrity) |
| OpenLineage | Track job → dataset → column lineage |
| Data Retention Policy | Partition drop + archival path |
| Quality Metrics | % valid rows, duplicate key rate, late event count |
| Compliance | Tag columns with sensitivity level (metadata catalog doc) |

---

## 13. Extended Sprint Ladder (12 + 6 Advanced)

| Sprint | Theme | New Advanced Emphasis |
|--------|-------|-----------------------|
| 1 | Core bootstrap | – |
| 2 | Events & caching | Basic Redis |
| 3 | Real-time & gRPC | Circuit breakers |
| 4 | GraphQL + Chat | Presence + trace propagation |
| 5 | Legacy & Webhooks | Outbox scaffold start |
| 6 | IoT + RabbitMQ | Idempotent consumers |
| 7 | Streams + Batch | Kafka Streams + partial ES |
| 8 | Multi-region prep | Replica provisioning |
| 9 | Active-active + DR | Failover runbook |
| 10 | Cloud portability | Deploy to AWS/EKS |
| 11 | Resilience hardening | Chaos experiments |
| 12 | Perf & security gates | Tail sampling intro |
| 13 | Advanced Data I | Partitioning + Outbox → Debezium |
| 14 | Warehouse + SCD | Bronze→Silver→Gold + SCD2 |
| 15 | Microservice Patterns | Saga orchestrator + CQRS |
| 16 | AI / Vector Search | Embeddings + semantic search |
| 17 | Governance & Privacy | Lineage + RLS + encryption |
| 18 | Optimization & Cost | Plan hash drift + autoscale tuning |

---

## 14. Sample Gantt / PERT ASCII (First 18 Sprints)

S1  S2  S3  S4  S5  S6  S7  S8  S9  S10 S11 S12 S13 S14 S15 S16 S17 S18
|Core Foundation|
    |Events+Caching|
         |Realtime|
             |GraphQL+Chat|
                  |Legacy+Webhooks|
                       |IoT+MQ|
                            |Streams+Batch|
                                 |Multi-Region|
                                       |Active-Active/DR|
                                             |Portability|
                                                   |Resilience|
                                                        |Perf/Sec|
                                                            |Adv Data I|
                                                                 |Warehouse|
                                                                      |Patterns|
                                                                           |AI/Vector|
                                                                                |Gov+Privacy|
                                                                                     |Optimize|

---

## 15. Metrics & KPIs

| Category | Metric | Target (Initial) |
|----------|--------|------------------|
| Performance | REST p95 | <120ms |
| Realtime | WS order notify latency | <500ms |
| Cross-Region | Event replication lag | <2000ms |
| DB | Partition scan time | Monitor baseline | 
| Events | Outbox publish lag | <3s |
| Cache | Hit ratio product | >85% after warmup |
| Data Quality | Silver validity % | >99% |
| AI | Embedding refresh latency | <5m after product update |
| Resilience | DR RTO | <10m drill |
| Cost | Dev cloud runtime hrs/week | <10 (destroy outside windows) |

---

## 16. Cost & Capacity Strategy

| Phase | Infra Mode | Est. Monthly (If Left Running) | Cost Control Tactics |
|-------|------------|--------------------------------|----------------------|
| S1–S5 | Local (kind, containers) | $0 | Avoid cloud until needed |
| S6–S8 | Light single-region cluster | $40–70 | Short-lived env (4–6 hr sessions) |
| S9–S10 | Dual region (test windows) | $80–120 | Turn off west except tests |
| S11–S12 | Perf + resilience runs | $120–180 | Scale down off-peak |
| S13+ (Adv Data) | Add warehouse + stream | +$40 if cloud obj store + compute | Use MinIO + local Spark where possible |

Cost Minimizers:
- Ephemeral Pulumi stacks per PR (auto destroy)
- Tiered retention (logs 1 day early)
- Minimal node sizes (e2-small / t3.small)
- Replace Kafka with Redpanda dev mode if needed
- Run analytic jobs locally unless scale matters

---

## 17. Immediate Next 10 Actions (Concrete)

| # | Action | Artifact / Output |
|---|--------|-------------------|
| 1 | Create monorepo skeleton + parent BOM | `pom.xml`, `libs/` baseline |
| 2 | Add Pulumi infra skeleton (already provided) | `infra/pulumi/*` |
| 3 | Auth Service (JWT issue/verify + tests) | `services/auth/` |
| 4 | Product Service CRUD + Flyway + Testcontainers | `services/product/` |
| 5 | Observability base (OTEL + Prometheus actuator) | `libs/common-observability/` |
| 6 | Redis integration (Product cache) | Cache config + metrics |
| 7 | Order Service + OrderCreated event (Kafka) | Topic + schema file |
| 8 | Decision Log (ADR 0001 Monorepo, 0002 Pulumi, 0003 Event Envelope) | `docs/adr/` |
| 9 | Add baseline CI pipeline (build + unit + integration) | `.github/workflows/ci.yml` |
|10 | Draft outbox schema doc & placeholder table (not yet active) | `docs/data/outbox.md` |

---

## 18. Documentation Artifacts To Create Soon

| File | Purpose |
|------|---------|
| `docs/adr/ADR-0001-monorepo.md` | Rationale for single repo |
| `docs/data/data_sharding_strategy.md` | Matrix of mapping per entity |
| `docs/data/query_optimization_runbook.md` | Step-by-step EXPLAIN workflow |
| `docs/data/warehouse_modeling_guide.md` | Medallion + SCD2 practices |
| `docs/events/transactional_messaging_outbox.md` | Outbox + Debezium design |
| `docs/architecture/microservices_patterns.md` | Saga, CQRS, etc. adoption rules |
| `docs/security/data_privacy_strategy.md` | RLS, masking, encryption |
| `docs/ai/vector_search_plan.md` | Embedding & retrieval strategy |
| `docs/governance/lineage_and_quality.md` | OpenLineage + Expectations |
| `docs/runbooks/dr_failover_playbook.md` | Step-by-step DR drill |

---

## 19. Event Envelope (Canonical Reference)

```json
{
  "eventId": "uuid",
  "eventType": "ecommerce.order.created.v1",
  "occurredAt": "2025-01-01T12:00:00Z",
  "producer": "order-service",
  "traceId": "trace-ctx",
  "correlationId": "corr-ctx",
  "schemaVersion": "1.0",
  "tenantId": "default",
  "partitionKey": "orderId",
  "payload": { }
}
```

---

## 20. Risk Register (Top Items)

| Risk | Impact | Mitigation |
|------|--------|------------|
| Scope creep (too many protocols early) | Diluted learning | Sprint gating rule |
| Infra cost creep | Budget blow past comfort | Auto destroy; spend log |
| Data model divergence across services | Event schema drift | Schema registry + CI check |
| Observability neglected in new services | Blind spots | Definition of Done includes tracing |
| Outbox reliability gaps | Duplicate or lost events | Idempotent consumers + monitors |
| Performance regressions | Hidden until late | Plan hash & latency budgets tracked early |

---

## 21. Quality Gates (Definition of Done Additions)
- Unit + integration tests (coverage target optional; focus on critical paths)
- Tracing spans present for all inbound requests
- Metrics: request_count, latency histogram, error_count
- If emitting events: schema in registry + contract test
- Security baseline (authn enforced) unless explicitly public
- ADR updated if architectural deviation
- Cost annotation (expected runtime impact if any)

---

## 22. Developer Daily Flow

1. Start local stack (`scripts/local-dev/start-core.sh` for Postgres, Kafka, Redis).
2. Run service in IDE (Spring Devtools).
3. Add/Update tests before feature logic.
4. Run `./gradlew build` (or Maven) & ephemeral integration tests.
5. Commit (conventional message).
6. Open PR → CI (lint → unit → integration → Pulumi preview optional).
7. Merge after reviews (check metrics dashboards).
8. Weekly: ephemeral cloud deploy; DR/chaos rehearsal after S8.

---

## 23. Future Enhancement Candidates (Post Plan)
| Idea | Value |
|------|-------|
| CRDT-based multi-region cache sync | Consistency experimentation |
| Adaptive concurrency limiting | Resilience under load spikes |
| Edge caching layer (Cloudflare Workers stub) | Latency studies |
| Multi-tenant partition experiment | SaaS simulation |
| GraphQL Federation gateway | Schema split scaling |
| Inline PII detection in logs | Privacy automation |
| Cost anomaly detection job | FinOps learning |

---

## 24. Success Criteria (Learning Outcomes)
| Milestone | Demonstrable Skill |
|-----------|--------------------|
| After Sprint 4 | End-to-end REST + gRPC + WebSocket + GraphQL with tracing |
| After Sprint 7 | Outbox + stream processing + partitioned data introduction |
| After Sprint 10 | Cloud portability (GCP→AWS) minimal code changes |
| After Sprint 12 | Security & perf gates in CI; resilience patterns applied |
| After Sprint 14 | Warehouse with SCD2 + governed pipeline |
| After Sprint 16 | Vector search integration & feature store |
| After Sprint 18 | Governance, lineage, cost & optimization dashboards |

---

## 25. Quick Reference Cheat Sheets

### Shard Key Anti-Patterns
- Monotonic increasing key (hot last partition) → add hash / time bucket
- Low cardinality field (few distinct values) → causes uneven distribution

### Index Patterns
| Pattern | Use |
|---------|-----|
| Composite (status, created_at) | Filter + ordering |
| Partial (status='OPEN') | Narrow active subset |
| BRIN (created_at) | Large time-series scans |
| GIN (jsonb_path_ops) | JSON attribute filters |
| Covering (idx includes columns in SELECT) | Avoid heap lookups |

### Cache Invalidation Triggers
| Event | Action |
|-------|--------|
| ProductUpdated | Evict product:* key |
| PriceChanged | Evict price:* + refresh-ahead |
| InventoryAdjusted | Update inventory snapshot & publish cache refresh event |
| OrderCreated | Add to user recent orders list cache (if present) |

---

## 26. Closing Notes
- Resist the urge to “gold plate” early—prioritize stable pipelines & observability instrumentation.
- Capture lessons learned per sprint in a short retrospective doc; convert insights into ADRs or playbooks.
- Treat the data warehouse & AI phases as a *second learning arc* building atop a stable transactional core.

---

## 27. What To Ask For Next (Optional Prompts)
- “Generate outbox table DDL + Debezium connector JSON.”
- “Provide sample Flyway migration for orders + partitioning.”
- “Give me a Saga orchestrator skeleton (Spring State Machine).”
- “Create Great Expectations YAML for FactOrder dataset.”
- “Add vector DB integration starter with Qdrant client.”

When you pick one, I’ll produce the next artifact.

---

Prepared for: BitVelocity Learning Journey  
Authored as: Architectural & Data/Platform Enablement Reference  
Version: 1.0 (Expandable)
