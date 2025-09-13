# Multi-Domain Near Real-Time Distributed Platform – High Level Design

> Grounded in provided project context: `microservices_domain_plan.md`, `pulumi_infra_portability_Version.md`, `project_planner_java_security.md`.

---

## 1. Architectural Objectives

| Objective               | Description                                                                   |
|:------------------------|:------------------------------------------------------------------------------|
| Multi-Domain Learning   | Showcase e-Commerce, Messaging/Chat, IoT Device Management, Social Media      |
| Protocol Breadth        | REST, GraphQL, gRPC, WebSocket, SSE, MQTT, AMQP, Kafka, Webhooks, SOAP        |
| Near Real-Time          | Push-first event-driven architecture with low-latency regional interaction    |
| Portability             | Pulumi Java SDK—cloud-neutral abstractions for GCP/AWS/Azure/local            |
| Multi-Cluster           | East/West active-active (hybrid) for resilience, DR, geo latency exploration  |
| Security by Design      | JWT, OAuth2, mTLS, Vault, OPA policy, API Gateway protections                 |
| Observability & Quality | OpenTelemetry tracing, Prometheus/Grafana, ELK, full-spectrum automated tests |
| Progressive Learning    | Iterative domain and protocol expansion with infrastructure evolution         |

---

## 2. Domain Partitioning (Bounded Contexts)

### E-Commerce
- Product (Catalog, Search via REST & GraphQL)
- Order (Lifecycle, Payment integration, Events)
- Inventory (Stock, IoT sensor input via gRPC + MQTT)
- Notification (WebSocket/SSE real-time)
- Partner Integration (Webhooks, Legacy SOAP)

### Messaging / Chat
- User (Profile adapter to central Auth)
- Chat Session (Messages, Rooms)
- Presence (Online status via gRPC)
- Attachment (Metadata + Object Storage)

### IoT Device Management
- Device Registry (Identity, Metadata)
- Telemetry (MQTT ingestion → Kafka)
- Firmware Update (gRPC orchestration)
- Analytics (Stream processing)

### Social Media
- Post (CRUD + GraphQL)
- Comment
- Feed (Event fan-out + SSE)
- Integration (Outbound webhooks)

### Cross-Cutting
- Auth / Identity (JWT/OAuth2)
- API Gateway (Apigee/Kong/Istio Ingress)
- Policy (OPA)
- Secrets (Vault + K8s Secrets)
- Messaging Backbone (Kafka, RabbitMQ, MQTT bridge, Pub/Sub adapters)
- Caching (Redis local + optional global sync)
- Observability (Logging, Metrics, Tracing)
- Infra Orchestrator (Pulumi modules)

---

## 3. Communication & Protocol Mapping

| Interaction Type       | Technology | Example Use                                        |
|:-----------------------|:-----------|:---------------------------------------------------|
| External CRUD          | REST       | Product, Post, Device Registry                     |
| Query Aggregation      | GraphQL    | Product + Inventory availability, Posts            |
| Internal Low-Latency   | gRPC       | Order ↔ Inventory, Presence ↔ Chat                 |
| Streaming Events       | Kafka      | order.events.*, chat.messages.*, telemetry.raw     |
| Work Queues            | RabbitMQ   | Notification fan-out retries, webhook dispatch     |
| IoT Ingestion          | MQTT       | Inventory sensors, telemetry devices               |
| Real-Time Client Push  | WebSocket  | Chat, live order status                            |
| Real-Time Lightweight  | SSE        | Feed updates, flash sales, analytics dashboards    |
| Legacy Integration     | SOAP       | External payment provider                          |
| Outbound Notifications | Webhooks   | Partner order status, third-party feed syndication |

---

## 4. Multi-Cluster (East / West) Topology

### Logical Overview (Text Diagram)

```
                    +----------- Global DNS / GSLB ------------+
                    |  Latency-based + health-aware routing    |
                    +------------------+-----------------------+
                                       |
                   +-------------------+--------------------+
                   |                                        |
          (East Region Cluster)                    (West Region Cluster)
          K8s + Mesh (Istio)                       K8s + Mesh (Istio)
          API Gateway / Ingress                    API Gateway / Ingress
          Auth / Core Domains                      Read replicas / Active services
          Kafka (primary topics)                   Kafka (mirrored subsets)
          Postgres Primary (Orders)                Postgres Replica (Orders)
          Mongo Primary (Posts)                    Mongo Secondary
          Redis Regional Cache                     Redis Regional Cache
          MQTT Broker                              MQTT Broker
          Vault (Primary)                          Vault (Perf Secondary)
```

### Cross-Cluster Connectivity
- Service mesh multi-primary or primary-remote with mTLS.
- Kafka MirrorMaker 2 for topic replication (selective).
- DB replication: Logical (Postgres), Replica Set (MongoDB), built-in (Cloud provider managed).
- VPC/VNet peering + encrypted tunnels (if different clouds).
- Global DNS failover orchestration.

### Traffic Scenarios
| Scenario | Flow (Simplified) |
|----------|-------------------|
| Order Placement (East) | Client → East Gateway → Auth → Order Service → gRPC Inventory → DB write → Kafka event → Notification push |
| Feed Read (West) | Client → West Gateway → Feed Service (materialized view from replicated events) |
| Chat Cross-Region | User A (East) sends → Kafka east → MirrorMaker → Kafka west → WebSocket push to User B (West) |

---

## 5. Data Consistency Strategy

| Data | Consistency Model | Approach |
|------|-------------------|----------|
| Orders, Payments | Strong (regional) | Single writer region w/ failover promotion |
| Inventory Levels | Near Real-Time | Event sourcing + timestamp conflict resolution |
| Chat Messages | Local-first eventual | Regional append + mirror replication |
| Presence State | Ephemeral | Redis TTL + no replication (recomputed) |
| Telemetry Raw | Eventually consistent | Stream ingestion per region; aggregated sync |
| Product Catalog | Eventually consistent | Authoring region + CDC (Debezium) replication |
| Social Feed | Eventual (<2s) | Activity events + regional materialization |
| Auth Tokens | Globally valid | Shared JWK keys (Vault distribution) |
| Secrets/Policies | Strong | Vault replication (performance secondaries) |

---

## 6. Event & Streaming Backbone

| Component | Purpose |
|-----------|---------|
| Kafka Core | Domain event bus (orders, feeds, telemetry, chat) |
| Schema Registry | Avro/JSON schema governance |
| Kafka Streams / Flink | Aggregations (sales, telemetry, feed precompute) |
| MQTT Bridge | MQTT → Kafka ingestion for IoT |
| RabbitMQ | Targeted queue tasks (webhooks, retries) |
| Dead Letter Topics | Fault isolation and replay |
| MirrorMaker 2 | Cross-region selective replication |

Topic Naming Convention:
```
<domain>.<context>.<entity>.<eventType>.<version>
ecommerce.order.order.created.v1
chat.message.sent.v1
iot.telemetry.raw.v1
social.feed.activity.v1
```

---

## 7. Security Architecture (Applied)

| Layer | Implementation |
|-------|----------------|
| Identity & Auth | OAuth2/OIDC + JWT (short-lived, rotated signing keys) |
| Transport Security | TLS at ingress; mTLS in mesh for service-to-service |
| Policy Enforcement | OPA sidecar or central PDP: RBAC/ABAC (orders, firmware rollout) |
| Secrets | Vault dynamic DB creds + PKI for cert issuance |
| Gateway Protections | Rate limiting, spike arrest, GraphQL complexity, IP filters |
| Data Protection | Encryption at rest (DB/storage) + in transit (TLS) |
| Protocol Security | gRPC interceptors, WebSocket token revalidation, GraphQL depth limits |
| Secure SDLC | SAST, DAST (ZAP), Dependency scanning, Image scanning (Trivy), IaC scanning |

---

## 8. Observability & Operations

| Aspect | Tooling |
|--------|---------|
| Metrics | Prometheus + custom exporters (Kafka lag, Redis, DB replication) |
| Tracing | OpenTelemetry SDK → Jaeger/Tempo |
| Logging | Structured JSON → ELK (mask sensitive fields) |
| Dashboards | Grafana (domain + infra boards) |
| Alerts | Latency SLO breach, replication lag, auth failures, consumer lag |
| Correlation | Trace ID propagation gateway → downstream → async events (embed trace/span metadata in headers / event key) |

Key Metrics:
- REST p95 latency, gRPC p95 latency
- WebSocket session count & disconnect rate
- Kafka consumer lag per critical topic
- DB replication delay seconds
- Cache hit ratio per domain
- Auth failure/denied rate
- DR drill RTO & RPO achieved

---

## 9. Near Real-Time Delivery Tactics

| Tactic | Description |
|--------|-------------|
| Push-first | WebSocket/SSE default; fallback polling |
| CQRS Views | Materialized read models for Orders dashboard, Feeds, Inventory snapshot |
| Event Sourcing (Selective) | Orders & Inventory updates as append-only events |
| Stream Pre-Computation | Feed fan-out partial pre-materialization |
| Latency Optimization | gRPC internal RPCs, HTTP/2 reuse, keepalive tuning |
| Regional Caching | Redis per region to avoid cross-region chatter |
| Backpressure | Circuit breakers (Resilience4J), gRPC deadlines, queue depth monitoring |

---

## 10. Standard Software Practices

| Practice | Implementation |
|----------|----------------|
| Project Layout | Multi-module: core libs (auth, tracing), domain services standalone |
| Dependency Management | BOM (Spring Boot) + shared parent POM for uniformity |
| Twelve-Factor Compliance | ENV-driven config (injected from Pulumi outputs) |
| API Versioning | REST path versioning + GraphQL schema directives |
| Event Evolution | Backward-compatible schema; producers add fields, consumers tolerant |
| Testing Layers | Unit → Integration (Testcontainers) → Contract (Pact) → Performance (Gatling) → Security (ZAP) |
| Release Strategy | Canary (east) → Observability gate → West rollout |
| Deployment | GitHub Actions / Tekton + Pulumi preview/apply + Argo Rollouts |
| Resilience Testing | Chaos experiments (pod kill, network latency, partition Kafka) |
| DORA Metrics | MTTR, Change Failure Rate, Lead Time tracked via pipeline annotations |

CI/CD Pipeline Stages (Illustrative):
1. Compile & Unit Tests  
2. Integration Tests (Testcontainers)  
3. Contract / Pact Tests  
4. Static Analysis & Dependency Scan  
5. Build Distroless Image  
6. Pulumi Preview (infra drift check)  
7. Deploy Canary (East)  
8. Synthetic & Load Smoke  
9. Progressive Rollout (West)  
10. Tag & Publish Artifacts + Docs  

---

## 11. Failover & Disaster Recovery (Playbook Snapshot)

| Step | Activity |
|------|----------|
| 1 | Detect anomaly: elevated 5xx / health failing in East |
| 2 | GSLB shifts weight to West gradually |
| 3 | Promote DB replica (if Orders write needed) |
| 4 | Reissue dynamic credentials via Vault (update services) |
| 5 | Adjust Kafka ingestion mode (pause East producers or fail safe) |
| 6 | Reconcile divergent event sequences (replayer microservice) |
| 7 | Run post-mortem metrics capture (RTO/RPO validation) |
| 8 | Controlled reintroduce East (warm-up health gating) |

---

## 12. Example End-to-End Sequences

### Order Creation (Near Real-Time Notification)
1. Client → Gateway (/orders POST)  
2. Auth validated (JWT)  
3. Order Service: validate, gRPC call Inventory (stock check)  
4. Persist → Emit `ecommerce.order.order.created.v1`  
5. Notification Service consumes → WebSocket push + SSE broadcast  
6. Analytics pipeline ingests (Kafka Streams)  
7. Mirror to West for dashboards  

### Chat Message Cross-Region
1. User A → WS (East) → Chat Service  
2. Append message event → Kafka East (chat.message.sent.v1)  
3. MirrorMaker replicates to West  
4. Chat Service West consumes → pushes to User B (West) WebSocket  

---

## 13. Pulumi Infrastructure Alignment

| Module | Responsibility |
|--------|----------------|
| `common` | Naming, tagging, IAM baseline |
| `networking` | VPC/VNet, peering, subnets, mesh gateways |
| `kubernetes` | Cluster provisioning (GKE/EKS/AKS/kind) |
| `database` | Postgres, Mongo, Redis (primary + replicas) |
| `messaging` | Kafka brokers, MirrorMaker, RabbitMQ, MQTT |
| `secrets` | Vault setup, policies, transit engine |
| `monitoring` | Prometheus, Grafana, Alertmanager |
| `storage` | Object buckets, PVC classes |
| `security` | OPA deployment, cert management |
| `appStacks` | Deploy domain services (config from outputs) |

Config Keys (Sample):
```
cloudProvider = gcp|aws|azure|local
regionEast = us-east1
regionWest = us-west1
meshEnabled = true
replication.kafka.enabled = true
db.orders.mode = primary|replica
```

Outputs consumed by apps:
- `KAFKA_BROKERS_EAST`
- `POSTGRES_ORDERS_RW_ENDPOINT`
- `VAULT_ADDR`
- `OPA_POLICY_ENDPOINT`
- `REDIS_CACHE_HOST`
- `GRAPHQL_GATEWAY_URL`

---

## 14. Performance & Latency SLOs (Initial)

| Component | SLO (p95) |
|-----------|-----------|
| REST CRUD (Local Region) | < 120 ms |
| Internal gRPC Call | < 40 ms |
| WebSocket Message Fan-out (Intra-region) | < 150 ms |
| Cross-Region Event Visibility | < 2000 ms |
| Notification Delivery (Order Created → Client) | < 500 ms |
| Chat Delivery (Cross-region) | < 600 ms |
| Telemetry Ingestion Sustained | 10K msgs/sec/region (scalable target) |

---

## 15. Incremental Build Path (Optimized for Learning)

| Step | Focus |
|------|-------|
| 1 | Single region: Auth, Product, Order, Inventory, Kafka, Redis |
| 2 | Add WebSocket Notifications + SSE |
| 3 | Introduce GraphQL (Product + Inventory federated view) |
| 4 | Add Chat + Presence (WebSocket + gRPC) |
| 5 | IoT (MQTT ingestion → Kafka → basic analytics) |
| 6 | Social feed event model + SSE |
| 7 | Security hardening (Vault, OPA, mTLS) |
| 8 | Provision West cluster + replication (Kafka + DB read) |
| 9 | Active-active real-time (Chat + Notifications cross-region) |
| 10 | DR simulation & failover automation |
| 11 | Performance tuning + chaos & resilience patterns |

---

## 16. Key Trade-Offs

| Decision | Rationale |
|----------|-----------|
| Hybrid Active Model | Simplifies strong consistency (orders) while showcasing eventual models |
| Multiple Messaging Tools | Educational coverage over production minimalism |
| Regional Caches | Demonstrate invalidation & eventual sync complexities |
| Separate Protocol Layers | Teach comparative trade-offs (REST vs gRPC vs GraphQL vs events) |
| Eventual Consistency in Feeds | Enables scaling/fan-out learning without global locks |

---

## 17. Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Cross-region schema drift | CI schema registry validation |
| Event replay complexity | Standardized event envelope + sequence ledger |
| Security gaps early | Shift-left pipeline gating + baseline OPA policies |
| Overhead of many stacks | Pulumi modularization + templated stack config |
| Latency spikes | Autoscaling (HPA + KEDA), caching, circuit breakers |
| DR rehearsal skipped | Scheduled DR drills (automated GitHub Action) |

---

## 18. Core Metrics to Track

| Category | Metric |
|----------|--------|
| Reliability | Error rate %, uptime, replication lag |
| Performance | p95 latencies (REST/gRPC/WebSocket) |
| Throughput | Events/sec per topic |
| Data Freshness | Feed materialization delay |
| Security | Auth failures/min, policy denials |
| Cost Awareness | Resource utilization vs baseline |
| Resilience | Circuit breaker trips, retry counts |

---

## 19. Immediate Next Steps

1. Scaffold Pulumi infra repo structure (common, networking, kubernetes, database, messaging).
2. Provision East cluster + Postgres + Kafka + Redis + Vault (minimal).
3. Implement Auth + Product + Order services (REST + gRPC internal for Inventory).
4. Add order events (Kafka) + WebSocket notification service.
5. Introduce tracing (OpenTelemetry) + Prometheus metrics early.
6. Add MirrorMaker ready config (even before West exists).
7. Start integration tests with Testcontainers (Postgres + Kafka).
8. Document first iteration architecture & deployment runbook.
9. Prepare West cluster manifest (disabled until step 8 in roadmap).
10. Add OPA policy for order mutation once baseline stable.

---

## 20. Optional Enhancements (Future Iterations)

| Enhancement | Value |
|-------------|-------|
| CRDT-based Global Cache | Demonstrate conflict-free replication |
| Multi-tenancy (Auth + Data Partition) | SaaS education scenario |
| Adaptive QoS | Priority queues for premium users |
| Canary GraphQL Schema Introduction | Safe federated expansion |
| Anomaly Detection (Telemetry) | Real-time ML streaming patterns |
| Edge Functions | Pre-auth caching at edge for hot queries |


# Desired Project structure
- bv-chat-stream
- bv-eCommerce-core
- bv-infra-service
- bv-iot-control-hub
- bv-security-core                                   
- bv-social-pulse