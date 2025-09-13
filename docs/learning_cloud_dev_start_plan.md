# BitVelocity Learning Platform – Iterative Architecture & Execution Plan

## 1. Vision Recap
Create a multi-domain, protocol-rich, security-first, cloud-portable distributed backend platform using:
- Java + Spring Boot
- Pulumi (Java SDK) for portable infra
- Kubernetes (local → GKE → EKS/Azure later)
- Full protocol breadth: REST, GraphQL, gRPC, WebSocket, SSE, Kafka events, AMQP (RabbitMQ), MQTT, Webhooks, SOAP, Pub/Sub abstraction, batch, stream processing
- Security: JWT, OAuth2, mTLS, Vault, OPA, Apigee gateway
- Observability + Testing spectrum
- Multi-cluster (east/west) evolution
- Extreme reusability & low-cost operation with destroy/recreate cycles

## 2. Foundational Principles (Grounded in Provided Designs)
From `multi_domain_high_level_design.md`:
- Incremental build path (Section 15) → We adopt as Milestone Ladder.
- Protocol mapping (Section 3) → Drives service slicing.
- Pulumi modular infra (Section 13 & `pulumi_infra_portability_Version.md`) → CloudProvider abstraction.
- Security layering (`project_planner_java_security.md` & security sections) → Shift-left baseline at Sprint 2.

We deliberately constrain complexity of domain logic to maximize breadth of platform mechanics.

## 3. Unified Scenario Narrative (Story Spine)
Brand: “BitVelocity”.

A simplified storyline ties every protocol:
1. A user browses products (REST/GraphQL) and places an order (REST → internal gRPC to Inventory → Kafka event).
2. Real-time order status updates appear in a UI (WebSocket + fallback SSE).
3. Partner systems receive webhooks for order state transitions.
4. IoT edge sensors (MQTT) periodically adjust inventory counts; Inventory emits events to Kafka → materialized stock views → GraphQL queries.
5. Chat domain allows customer–support interaction (WebSocket, presence via gRPC, message events via Kafka).
6. Social feed domain produces promotional posts & flash sale announcements (Kafka → SSE feed).
7. Scheduled batch job aggregates daily sales (Batch) & a Kafka Streams/Flink job performs near real-time analytics (Stream processing).
8. Notification service enqueues retries via RabbitMQ (AMQP) for external partner pushes.
9. A legacy payment gateway is simulated via SOAP.
10. Apigee (or Kong/Istio locally) enforces rate limits, OAuth2 token introspection, JWT verification.
11. Multi-region replication is introduced for chat + feed + analytical dashboards (east/west clusters).
12. Pulumi switches stack from GCP to AWS to rehearse migration.

## 4. Protocol-to-Use Case Matrix (Condensed)
| Protocol / Pattern | Primary Service | Initial Slice Priority |
|--------------------|-----------------|------------------------|
| REST | Product, Order, Auth | Sprint 1–2 |
| gRPC | Inventory (stock check), Presence | Sprint 3–4 |
| GraphQL | Product+Inventory aggregator, Post/Feed | Sprint 4–5 |
| Kafka (Events) | Order domain events, Chat, Feed | Start Sprint 2; expand |
| WebSocket | Order status, Chat messages | Sprint 3 |
| SSE | Feed updates, flash sale ticker | Sprint 5 |
| MQTT | Inventory sensors, Telemetry | Sprint 6 |
| AMQP (RabbitMQ) | Reliable partner/webhook retries | Sprint 6 |
| Webhooks (Outbound) | Partner order status, social syndication | Sprint 5–6 |
| SOAP | Payment gateway simulation | Sprint 5 |
| Batch | End-of-day sales summary job | Sprint 7 |
| Stream Processing | Live sales metrics, feed fan-out | Sprint 7 |
| Caching (Redis) | Product catalog, Inventory snapshot, Presence ephemeral, Feed precomputed slices | Start Sprint 2, extend each step |
| Pub/Sub (Abstraction) | Wrap Kafka + provider Pub/Sub for portability | Sprint 8 (cloud portability focus) |

## 5. Caching Strategy (Explicit Use Cases)
| Cache Type | Data | Pattern | Consistency Notes | Invalidation |
|------------|------|---------|-------------------|--------------|
| Product Catalog | Product read models | Read-through Redis | Eventual (product.updated event) | Key per product + tag flush |
| Inventory Snapshot | Aggregated stock per SKU | Periodic refresh + event-driven | Near real-time | Kafka event triggers delta update |
| WebSocket Session Presence | User presence flags | Ephemeral TTL (Redis) | Soft eventual | TTL expiry; presence refresh ping |
| Feed Hot Set | Latest N feed items | Write-behind (event consumer) | Event-driven | On new post event rotate list |
| Auth JWK / Tenant Config | Keys, policies | In-memory + Redis fallback | Strong (short TTL) | Key rotation triggers flush |
| Flash Sale Pricing | Short-term dynamic price | Cache-as-authority for TTL window | TTL-bound staleness | TTL expiry or manual bump |

## 6. Resilience & Retry Patterns (Mapping)
| Pattern | Library | Use Case |
|---------|---------|----------|
| Linear Backoff | Spring Retry | Non-critical partner webhook first attempt |
| Linear Jitter | Custom wrapper or Resilience4j | Reduce thundering herd on Notification retry |
| Exponential Backoff | Resilience4j Retry | Payment SOAP invocation |
| Exponential Jitter | Resilience4j + custom jitter supplier | Kafka producer transient failures |
| Circuit Breaker | Resilience4j | Payment, Inventory gRPC |
| Bulkhead | Resilience4j | Chat vs Order isolation under load |
| Idempotency Keys | Custom filter (Order requests) | Avoid duplicate order creation |
| Dead Letter / Parking Lot | Kafka DLQ / RabbitMQ DLX | Poison events, partner webhook failure |
| Node Failure Detection | K8s liveness/readiness + Mesh health | Automatic reschedule; metrics/alerts |

## 7. Multi-Cloud & Pulumi Abstraction (Early Design Constraint)
Introduce CloudProvider interface from the start but implement only GCP in first 3 sprints:
```java
interface CloudProvider {
  Network createNetwork(Region r);
  K8sCluster createKubernetesCluster(Region r, ClusterProfile profile);
  Database createPostgres(String id, DbPlan plan);
  Cache createRedis(String id);
  Messaging createKafka(String id, KafkaPlan plan);
  SecretStore createSecrets(String id);
}
```
Factories for AWS/Azure added Sprint 8+, reusing neutral config keys.

## 8. Repository & Project Layout (Monorepo Recommended)
```
bitvelocity/
  infra/                    # Pulumi (multi-module)
    common/
    networking/
    kubernetes/
    database/
    messaging/
    security/
    monitoring/
    stacks/<env>/
  libs/
    bv-common-core/         # DTOs, error model, tracing config
    bv-security-core/       # JWT utilities, auth filters, OPA client
    bv-event-core/          # Event envelope, Kafka serializers
    bv-test-core/           # Testcontainers utilities
  services/
    bv-auth-service/
    bv-ecommerce-core/
      product-service/
      order-service/
      inventory-service/
      notification-service/
      payment-service/
    bv-chat-stream/
      chat-service/
      presence-service/
    bv-social-pulse/
      post-service/
      feed-service/
    bv-iot-control-hub/
      device-registry/
      telemetry-service/
    bv-infra-service/       # Migration helpers, replay jobs
  gateway/
    apigee-config/          # API proxy bundles / policies
    istio-manifests/        # Local gateway alternative
  docs/
  qa/
    performance/
    security/
    bdd/
  scripts/
    local-dev/
    cost-control/
```

## 9. Testing Pyramid & Tooling Rollout
| Layer | Tools | First Sprint Introduced |
|-------|-------|-------------------------|
| Unit | JUnit 5, AssertJ, Mockito | Sprint 1 |
| Integration (containers) | Testcontainers (Postgres, Kafka, Redis) | Sprint 2 |
| Contract (API + gRPC) | Spring Cloud Contract / Pact + protobuf golden files | Sprint 3–4 |
| BDD Functional | Cucumber (REST, GraphQL), JBehave optional | Sprint 4 |
| WebSocket & SSE | Gatling or K6 custom scripts | Sprint 4–5 |
| Performance / Load | Gatling / Locust (Java DSL for clarity) | Sprint 6 |
| Security Scans | OWASP ZAP CLI in GitHub Actions | Sprint 5 |
| Fuzz | Jazzer (target DTO parsers, JSON endpoints) | Sprint 6 |
| Chaos | Litmus or Chaos Mesh | Sprint 7–8 |
| DR / Failover Drills | Custom automation + Pulumi stack switching | Sprint 9+ |

## 10. Observability Baseline Introduction
Sprint 2: OpenTelemetry tracing + Prometheus metrics + basic Grafana.
Sprint 3: Structured logging (JSON) + correlation IDs propagated into Kafka headers.
Sprint 5: Log enrichment (userId, traceId), alert rules (latency, Kafka lag).
Sprint 7+: Synthetic transactions + SLO dashboards (tie to Section 14 of high-level design).

## 11. Incremental Milestones & Sprints (Capacity Aware)
Assumption: 2–3 devs × 10–15 hrs/week = ~50–70 hrs per 2-week sprint. Each story sized to 4–8 hrs.

### Milestone Ladder (Aligned with Section 15 of High-Level Design)
| Sprint | Milestone | Core Deliverables (Stories) |
|--------|-----------|-----------------------------|
| 1 | Bootstrap Core | Monorepo skeleton, Auth (JWT issuance), Product REST CRUD, Local Postgres via Docker, Basic Pulumi stack (local kind), Unit tests |
| 2 | Eventful Orders | Order service (REST), Inventory stub (gRPC proto defined, mock impl), Kafka local, OrderCreated event, Redis cache for Products, OpenTelemetry + Prometheus |
| 3 | Real-Time Slice | Implement Inventory gRPC, WebSocket notifications for order status, Resilience4j baseline (retry/backoff), Testcontainers integration tests |
| 4 | GraphQL + Chat Base | GraphQL gateway for Product+Inventory, Chat service (WebSocket), Presence gRPC service, Pact/Contract tests, Basic Apigee proxy mock (or Kong locally) |
| 5 | Legacy & Feed | Payment SOAP mock, Feed service (SSE), Webhooks for order status → partner stub, Security hardening (OAuth2 support), OPA minimal policy for Order update |
| 6 | IoT & Messaging Depth | MQTT ingestion (Inventory sensor), RabbitMQ for reliable webhook retries, Device Registry & Telemetry ingestion, Fuzz baseline, Load test smoke |
| 7 | Batch & Streams | Batch sales aggregation, Kafka Streams for real-time sales metrics, Advanced caching patterns (feed hot set), Chaos experiment (pod kill) |
| 8 | Multi-Region Prep | West cluster provisioning (Pulumi), Kafka MirrorMaker config, Read replica DB, Cross-region feed read model, mTLS mesh integration, Vault introduction |
| 9 | Active-Active Features | Cross-region chat replication path, DR drill script (promote replica), Apigee real deployment (trial) with rate limits & JWT validation |
| 10 | Migration & Portability | Deploy stack on AWS (EKS) with same Pulumi abstractions, Compare endpoints, Document delta, Cost baseline measurement tooling |
| 11 | Advanced Resilience | Exponential jitter everywhere required, Circuit breaker tuning, Replay service for DLQ, Automated chaos scenario pipeline |
| 12 | Performance & Hardening | SLO gates in CI, ZAP automated gating, GraphQL complexity rules, Multi-cloud smoke, Documentation completeness |

(After Sprint 12 you recycle deeper into specialized learning: CRDT cache experiments, edge, ML streaming, etc.)

## 12. Gantt / PERT Style ASCII (High-Level)
Timeline (Sprints 1–12, each = 2 wks)

S1  S2  S3  S4  S5  S6  S7  S8  S9  S10 S11 S12
|---Core Foundation---|
     |--Events & Caching--|
         |--Realtime Layer--|
             |--GraphQL & Chat--|
                 |--Legacy+Feed--|
                      |--IoT & MQ--|
                           |--Batch/Streams--|
                               |--Multi-Region Setup--|
                                    |--Active-Active/DR--|
                                         |--Multi-Cloud Migration--|
                                              |--Resilience Advanced--|
                                                   |--Perf & Hardening--|

Dependencies:
- Auth → Orders → Notifications → GraphQL aggregator → Chat/Presence → Feed/SSE → IoT/MQTT → Streams → Multi-Region → Migration.

## 13. Detailed Sprint 1–2 Backlog (Example Breakdown)
Sprint 1 (Target ~60 hrs):
- Story: Monorepo skeleton + parent POM/BOM (6h)
- Story: Pulumi local kind cluster & Postgres provision script (8h)
- Story: Auth service (JWT issuance + refresh stub) (8h)
- Story: Product service REST CRUD + JPA + Flyway migrations (10h)
- Story: Unit & integration base (Testcontainers Postgres) (6h)
- Story: Common libs (error model, logging, tracing scaffold) (6h)
- Story: Dev scripts (start/stop, cost-saver) (4h)
- Story: Architecture doc baseline (4h)
Buffer: 6–8h

Sprint 2:
- Story: Introduce Kafka via docker-compose & Pulumi manifest (6h)
- Story: Order service: REST + persistence (8h)
- Story: Event publishing (OrderCreated) & envelope standard (6h)
- Story: Redis cache for Product reads (4h)
- Story: Inventory proto definition + mock gRPC server (6h)
- Story: WebSocket service skeleton (notification hub) (6h)
- Story: OpenTelemetry exporter + Prometheus endpoint (4h)
- Story: Integration tests (Kafka + Redis via Testcontainers) (6h)
Buffer: 6–8h

## 14. Security Rollout Roadmap (Phased)
| Phase | Coverage |
|-------|----------|
| 1 (S1–S2) | Basic JWT auth filter, stateless sessions, HTTPS locally (self-signed) |
| 2 (S3–S4) | OAuth2 provider integration, method-level @PreAuthorize |
| 3 (S5–S6) | OPA sidecar for order mutation policies, secret rotation via Vault dev mode |
| 4 (S7–S8) | mTLS in mesh, Vault dynamic DB creds, rate limiting in Apigee |
| 5 (S9–S10) | Full audit trails, GraphQL depth & complexity enforcement, SOAP WS-Security mock |
| 6 (S11–S12) | Automated security regression (ZAP fail pipeline), key rotation drill, token replay detection hooks |

## 15. Cost Optimization Strategy
| Technique | Explanation |
|-----------|------------|
| Local-first | Use kind/k3d/minikube for first 6 sprints to avoid cloud costs. |
| Ephemeral Cloud Windows | Provision GKE only for integration/performance sessions (e.g., 4–6 hrs/week), then `pulumi destroy`. |
| Minimal Node Profiles | Start with 2 small e2-micro (GCP) or t3.small (AWS) nodes. |
| Shared Kafka | Single small cluster (optional Redpanda dev) until multi-region milestone. |
| Use OSS for Apigee alt | Kong/Istio locally; only switch to Apigee trial after architecture stable (Sprint 9). |
| Observability Slim Mode | Disable retention > 1 day in early sprints; use Loki + lightweight. |
| Cleanup Automation | Script enumerating orphan disks, load balancers, static IPs after destroy. |
| Parameterized Feature Flags | Turn off MQTT, SOAP, Streams until relevant sprint. |
| CI Optimization | Parallel selective test suites; avoid spinning up unnecessary containers. |

Rough Budget (When Cloud Use Begins):
| Phase | Monthly Approx (If Left Running) | Strategy |
|-------|----------------------------------|----------|
| S1–S5 (Local) | $0 infra | Local only |
| S6–S8 (Light GKE) | $40–$70 | Run 2–3 short windows/week, else destroy |
| S9–S10 (Dual region + Apigee trial) | $80–$120 | Keep west cluster off >50% of time |
| S11–S12 (Perf & Multi-cloud) | $120–$180 (peaks) | AWS/EKS only ephemeral test days |

NOTE: Continuous running for full multi-region + Kafka + DB high availability could exceed $250–300/mo. Avoid leaving clusters idle.

## 16. Automation & Governance Early
- Pulumi Policies (S3–S4): Disallow public load balancers except gateway.
- GitHub Actions:
  - `ci-core.yml`: build + unit + integration
  - `security-scan.yml`: dependency + ZAP baseline
  - `env-provision.yml`: pulumi up (manual dispatch)
  - `dr-drill.yml`: failover simulation script (post Sprint 9)
- Tag build artifacts with commit + sprint tags.
- Add a “decision-log.md” for architecture trade-offs.

## 17. DR & Multi-Region Learning Path
| Stage | Activity |
|-------|----------|
| Prep (S8) | Provision west cluster read-only services + Kafka MirrorMaker |
| Enable (S9) | Chat & feed cross-region active-active |
| DR Drill (S9) | Simulate east failure: switch DNS (local script), promote DB read replica |
| Replay (S10) | Replay missed order events using replay service from DLQ |
| Observed Metrics | RTO, RPO, replication lag, failover latency |

## 18. Documentation Discipline
Each service README includes:
- Purpose & Protocols
- Run locally (docker compose / gradle task)
- Env vars (sourced from Pulumi outputs)
- Test matrix (which layers implemented)
- Observability fields (span names, metrics)
- Failure modes & retry policy

Infra docs maintain:
- Cloud provider switch steps (Pulumi stack config diff)
- Cost notes & destroy checklist
- DR runbook section (updated after each drill)

## 19. Developer Daily Workflow (Example)
1. `./scripts/local-dev/start-core.sh` (Postgres, Kafka, Redis, Vault dev)
2. Run service (Spring Boot dev mode)
3. Write/adjust contract tests before implementing new endpoint
4. Commit with conventional commit prefix (feat:, chore:, test:)
5. PR triggers CI pipeline (unit + integration)
6. Weekly ephemeral cloud test: `pulumi up` in staging stack
7. After validation: `pulumi destroy` to save cost

## 20. Immediate Next Actions (You Can Start Today)
1. Create monorepo & parent Maven POM with BOM (Spring Boot, Resilience4j, OpenTelemetry).
2. Implement `libs/bv-common-core` (error handling, base DTO, correlation ID filter).
3. Implement Auth service: issue signed JWT with HS256 (switch to RS256 when Vault introduced).
4. Product service REST CRUD with Postgres (Flyway migrations).
5. Add initial Pulumi project for local kind cluster + Postgres (container-based) + Kafka.
6. Add Redis docker service and integrate simple read-through Product cache.
7. Set up Testcontainers for Postgres & Redis in Product’s integration tests.
8. Draft architecture decision log: Reason for monorepo, initial protocols limited, deferring Apigee.
9. Baseline Observability: Add OpenTelemetry auto-instrumentation & custom trace for Product read.
10. Plan Sprint 2 backlog refinement meeting (list event envelope fields, gRPC contract definitions).

## 21. Event Envelope (Proposed Standard Early)
```json
{
  "eventId": "uuid",
  "eventType": "ecommerce.order.created.v1",
  "occurredAt": "2025-01-01T12:00:00Z",
  "producer": "order-service",
  "traceId": "...",
  "correlationId": "...",
  "payload": { ... },
  "schemaVersion": "1.0",
  "tenantId": "default",
  "partitionKey": "orderId"
}
```

## 22. Risk Watchlist & Mitigation
| Risk | Mitigation |
|------|------------|
| Overwhelm early with protocols | Strict milestone gates; no adding new protocol before previous validated |
| Cost creep | Enforce destroy script in CI weekly; cost log after each cloud session |
| Security debt accumulation | Security backlog reviewed every sprint retro |
| Schema drift across events | CI step validates Avro/JSON schema compat |
| Cloud lock-in sneaks in | Code review checklist: “No provider-specific assumptions?” |
| Integration test slowness | Parallel container networks + selective test profiles |

## 23. Success Criteria (Learning-Focused)
- After Sprint 4: You can explain & demo REST + gRPC + WebSocket + GraphQL end-to-end trace.
- After Sprint 6: All major messaging patterns (Kafka, RabbitMQ, MQTT, Webhooks) demonstrated.
- After Sprint 9: DR failover executed with documented RTO/RPO.
- After Sprint 10: Same codebase deployed on second cloud with <15% code delta (infra only).
- After Sprint 12: Security, observability, resilience automation gating merges.

---

Let me know when you want:
- Detailed POM/BOM example
- First Pulumi Java skeleton code
- Event schema & Avro registry setup
- Sample Resilience4j config file
- Apigee proxy bundle starter

We can proceed next with Sprint 1 tangible scaffolding and code stubs.