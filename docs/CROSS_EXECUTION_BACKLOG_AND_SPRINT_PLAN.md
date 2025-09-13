# Cross-Cutting – Execution Backlog & Sprint Planning (Granular)

Assumptions: 2–3 devs, 10–15 hrs/week each, 2-week sprints.

## 1. Sprint Themes (Refined)
| Sprint | Theme | Domains Touched |
|--------|-------|-----------------|
| 1 | Core bootstrap (Auth, Product) | Security, E-Com |
| 2 | Orders + Events + Basic Inventory | E-Com |
| 3 | Realtime (WS) + Inventory gRPC | E-Com |
| 4 | GraphQL + Chat seed | E-Com, Chat |
| 5 | Payment SOAP + SSE Feed + Webhooks | E-Com, Social |
| 6 | IoT Telemetry + RabbitMQ retries | IoT, E-Com |
| 7 | Streams + Feature Store stub | E-Com, ML |
| 8 | Multi-Region infra + Vault intro | Infra, Security |
| 9 | Active-active Chat + DR drill 1 | Chat, Infra |
| 10 | Cloud migration (AWS) | Infra |
| 11 | Replay service + resilience hardening | Cross |
| 12 | Performance + Security gating | All |

## 2. Detailed Sprint Backlog Seeds
### Sprint 1
- Auth service (JWT issuance)
- Product service CRUD
- Shared libs (event envelope)
- Postgres + Pulumi local infrastructure
- OpenTelemetry bootstrap
- Unit + integration pipelines

### Sprint 2
- Order service + events
- Inventory proto + stub
- Redis cache product
- Kafka local cluster
- BDD: simple checkout (no payment)

### Sprint 3
- Inventory gRPC implementation
- WebSocket order status
- Retry policies (Resilience4j baseline)
- Event schema registry integration
- Integration tests (Kafka + Redis)

### Sprint 4
- GraphQL aggregator (product + inventory)
- Chat WebSocket echo service
- Presence Redis TTL
- Contract tests (REST/gRPC)
- Update docs (API / events)

### Sprint 5
- Payment SOAP adapter
- SSE flash sale endpoint
- Webhook dispatcher initial version
- OPA policy for cancel order
- Security integration tests

### Sprint 6
- MQTT ingestion (telemetry)
- Inventory adjustment from IoT path
- RabbitMQ deployment + webhook retry
- Fuzz test harness initial
- Load test smoke (orders)

### Sprint 7
- Kafka Streams order revenue aggregation
- Feature store Redis skeleton
- Fraud scoring stub
- Cassandra projection (orders_by_customer)
- Data quality check pipeline

### Sprint 8
- West cluster provisioning
- MirrorMaker config
- Vault dev integration (secrets)
- DR runbook v1
- GraphQL schema diff automation

### Sprint 9
- Chat cross-region replication
- DR drill (simulate east outage)
- Audit logging integration
- Latency dashboards

### Sprint 10
- Deploy to AWS (EKS) via config switch
- Storage bucket migration test
- Cost metrics collection script

### Sprint 11
- Replay service MVP
- Circuit breaker tuning
- DLQ replay scenario test
- Policy version rollout

### Sprint 12
- Performance benchmark suite
- Security regression gating (ZAP)
- Chaos experiments (network latency)
- Documentation completeness review

## 3. Story Sizing Template
Each story: 4–8 hrs. If >8, split vertical slice (feature + test + docs).

## 4. Definition of Ready Checklist
- Clear acceptance criteria
- Event changes have contract stub
- Security impact considered
- Test approach outlined

## 5. Definition of Done
| Criterion | Required |
|----------|----------|
| Code + Tests | Yes |
| Docs (README / API / Events) | Updated |
| Observability | Metric or trace added |
| Security | Auth enforced or rationale noted |
| CI | Green pipeline |
| Cost | No unnecessary persistent resource |

## 6. Risk Review Every Sprint
- Track technical debt categories: observability, security, resilience.
- Limit outstanding “unmitigated” items to <= 5.

## 7. Burndown & Metrics
Track:
- Completed stories vs planned
- Test coverage trend
- Mean time from event schema proposal → merge
- Defects found post-merge (should decline over sprints)

## 8. Backlog Grooming Cadence
- Mid-sprint: next 2 sprints refinement
- Add learning spikes labeled (SPK) with explicit outcomes

## 9. Exit Gates (Milestone)
| Gate | Validation |
|------|------------|
| Realtime | Trace from REST → gRPC → Kafka → WS |
| Streaming | Projection correctness test passes |
| DR | Failover script success & metrics recorded |
| Multi-Cloud | Same commit deploys to second provider |
| Security | OPA & ZAP gating merges |
