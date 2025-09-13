# Cross-Cutting – Observability & Testing Strategy

## 1. Observability Stack
| Aspect | Tool |
|--------|------|
| Traces | OpenTelemetry SDK → Jaeger/Tempo |
| Metrics | Prometheus + Grafana |
| Logs | Structured JSON → Loki / ELK |
| Alerting | Alertmanager |
| Profiling (optional) | Continuous profiler (Async Profiler / Pyroscope) |

## 2. Standard Labels / Tags
| Signal | Labels |
|--------|--------|
| Metrics | service, domain, version, region |
| Traces | service.name, domain, environment |
| Logs | service, traceId, correlationId, userId, region |

## 3. Core Metrics Baseline
| Category | Metric |
|----------|--------|
| HTTP | http_server_duration_seconds |
| gRPC | grpc_server_duration_seconds |
| Messaging | kafka_consumer_lag, event_publish_failures_total |
| Cache | cache_hit_ratio, cache_evictions_total |
| DB | db_query_duration_ms, db_connection_pool_in_use |
| Security | auth_failed_total, opa_denied_total |
| Domain-specific | orders_created_total, chat_messages_ingested_total |

## 4. Tracing Conventions
- Span names: METHOD PATH for HTTP, ServiceName.Method for gRPC.
- Link publish span to consumer processing span via traceId in headers.
- Event consumption span attribute: eventType, partition, offset.

## 5. Alert Examples
| Alert | Condition |
|-------|-----------|
| High error rate | 5xx > 2% over 5m |
| Kafka lag | consumer lag > threshold for critical topics |
| Inventory freshness | last inventory.adjusted > 2m |
| Auth failures spike | auth_failed_total increase > X/min |
| Replay backlog | replay_pending_jobs > 0 for > 30m |

## 6. Testing Layers (Cross-Domain)
| Layer | Goal | Tools |
|-------|------|------|
| Unit | Fast correctness | JUnit |
| Integration | Data + infra correctness | Testcontainers |
| Contract | Producer / consumer compatibility | Pact / protobuf golden |
| BDD | Business scenarios per domain | Cucumber |
| Performance | Latency & throughput | Gatling/k6 |
| Security | Vulnerability & authz test | ZAP, dependency-check |
| Fuzz | Input robustness | Jazzer |
| Chaos | Failure resilience | Chaos Mesh |
| DR Simulation | Failover readiness | Pulumi scripts |
| Replay Validation | Projection integrity | Replay harness |

## 7. Test Data Management
- Synthetic dataset generator per domain.
- Redact PII fields before logs.
- Use stable fixture IDs for deterministic assertions.

## 8. CI Pipeline Stage Sequence
1. Lint / Static analysis
2. Unit tests
3. Integration tests
4. Contract tests
5. Build image
6. Security scans (deps & image)
7. Deploy ephemeral env (preview)
8. BDD smoke
9. Performance smoke (short)
10. Promotion gating

## 9. SLO Starter Set
| SLO | Target |
|-----|--------|
| REST availability | 99% dev baseline |
| Order create p95 latency | < 200ms |
| Chat message fan-out | < 150ms intra-region |
| Feed update propagation | < 2s |
| Telemetry anomaly detection | < 10s |
| Replay recovery time | < 10m for 24h window |

## 10. Exit Criteria
- All domains produce baseline metrics & traces.
- CI gating for contract & schema changes operational.
- At least one chaos experiment validated.

```

````markdown name=CROSS_INFRA_PORTABILITY_AND_DEPLOYMENT.md
# Cross-Cutting – Infrastructure Portability & Deployment

## 1. Principles
- Cloud-neutral abstractions (Pulumi Java).
- Config-driven provider selection.
- Minimal early footprint; scale features when needed.
- Repeatable ephemeral environments (feature branches).

## 2. Abstraction Interfaces
```
interface CloudProvider {
  Network createNetwork(...);
  K8sCluster createKubernetesCluster(...);
  PostgresCluster createPostgres(...);
  RedisCache createRedis(...);
  KafkaCluster createKafka(...);
  VaultInstance createVault(...);
  ObservabilityStack createMonitoring(...);
}
```

## 3. Directory Layout (Infra Repo)
```
infra/
  common/
  networking/
  kubernetes/
  database/
  messaging/
  secrets/
  security/
  monitoring/
  stacks/dev/
  stacks/staging/
  stacks/drill/
```

## 4. Config Keys
| Key | Meaning |
|-----|---------|
| cloudProvider | local|gcp|aws|azure |
| regionEast / regionWest | Region codes |
| meshEnabled | Toggle Istio |
| multiRegionEnabled | MirrorMaker setup |
| featureFlags | pricing, iot, feed, chat |
| cost.ttlHours | Auto-destroy hint |

## 5. Deployment Strategy
- GitOps optional later (ArgoCD).
- Start with GitHub Actions + Pulumi preview/apply.
- Canary rollout using progressive traffic (Istio or Argo Rollouts).
- Promotion: dev → staging → (simulated prod) with manual approval.

## 6. Multi-Region Phases
| Phase | Capability |
|-------|-----------|
| 1 | Single cluster east |
| 2 | West cluster infra only |
| 3 | Kafka mirror selective topics |
| 4 | Chat + Feed active-active |
| 5 | Failover drill for orders DB |
| 6 | Cross-cloud migration rehearsal |

## 7. Resource Tagging
Mandatory tags: environment, owner, ttl-hours, cost-center(optional)

## 8. Secrets Management
- Early: K8s Secrets + sealed secrets optional.
- Phase 3+: Vault dynamic DB credentials.
- Phase 5+: Transit encryption for sensitive tokens.

## 9. DR Automation
Script sequence:
1. Validate replica freshness
2. Promote replica
3. Update service endpoints
4. Replay gap if needed
5. Emit DR completion event

## 10. Cost Guardrails
- Infra preview diff size threshold (warn).
- Auto scaling min replicas = 1 early.
- Turn off west region except drills.

## 11. Exit Criteria
- Recreate entire infra with single Pulumi command.
- Migration to second provider executed with doc’d diff.
- DR drill script produces metrics (RTO/RPO).
