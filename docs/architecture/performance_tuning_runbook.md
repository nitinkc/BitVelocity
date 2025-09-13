# Performance Tuning Runbook
Version: 1.0  
Status: Draft  

## 1. Objectives
Provide repeatable workflow for diagnosing and improving latency, throughput, and resource efficiency across services & data stores.

## 2. Golden Signals
Track for each service:
- Latency (p50, p95, p99)
- Error rate
- Saturation (CPU %, heap usage, thread pool queues)
- Traffic (RPS, events/sec)

## 3. Baseline Collection
1. Run load test (Gatling) at target baseline load (e.g., 100 req/s).
2. Capture:
   - JVM metrics (GC, heap, threads)
   - DB metrics (connections, slow queries)
   - Kafka lag
3. Store baseline snapshot markdown in `docs/perf/baselines/`.

## 4. JVM Tuning Checklist
| Area | Action |
|------|--------|
| GC | Use G1 (default) initially; evaluate Shenandoah/ZGC if pause > 150ms |
| Heap | Right-size: (Live data * 2) + safety |
| Thread Pools | Monitor queue length; size = CPUs * (1 + wait_ratio) |
| Async Timeouts | gRPC / HTTP client timeouts < upstream SLA threshold |
| Allocation Rate | Profile with async profiler; reduce temporary objects |

## 5. DB Query Optimization Workflow
1. Identify top slow queries (pg_stat_statements).
2. EXPLAIN (ANALYZE, BUFFERS).
3. Evaluate:
   - Index usage
   - Sequential scan needed?
   - Filter selectivity
4. Apply index/partition change.
5. Re-run load test.
6. Track plan hash; alert on change causing regression.

## 6. Caching Validation
- Measure hit ratio after 10 min warm.
- If < target (e.g., 85%), analyze key distribution (topN).
- Add partial object or adjust TTL.

## 7. Concurrency & Backpressure
Use Resilience4j:
- Rate limiter: set threshold per service to protect upstream.
- Bulkhead: isolate high-risk dependencies.
- Circuit breaker: open threshold (fail fast) to prevent cascading load.

## 8. Profiling Tools
| Tool | Purpose |
|------|---------|
| Async Profiler | CPU / allocation flamegraphs |
| JFR (Java Flight Recorder) | Low overhead continuous profiling |
| Parca/Pyroscope | Continuous multi-service |
| pprof-like (Go side services) | If polyglot expansion |

## 9. Load Test Phases
| Phase | Goal |
|-------|------|
| Smoke | Validate scenario (5 min) |
| Ramp | Increase load gradually (baseline → stress) |
| Steady | Hold target load (30–60 min) |
| Spike | Sudden 5× burst (observe resilience) |
| Soak | 2–4h memory leak detection |

## 10. Performance Budget Example
| Component | p95 Target |
|-----------|-----------|
| Product GET | <120ms |
| Order POST | <180ms |
| Inventory gRPC | <40ms |
| WebSocket broadcast | <150ms |
| Kafka event publish latency | <50ms |

## 11. Regression Detection
Automate comparison:
- Export metrics snapshot
- Compute delta vs baseline
- Fail pipeline if > defined threshold (e.g., +20% latency)

## 12. Observability Correlation
- Use exemplars linking traces to metrics.
- Add trace attributes: `db.statement.hash`, `cache.hit=true/false`.

## 13. Memory Leak Triage
1. Observe rising heap over soak.
2. Capture heap dump (jcmd).
3. Analyze dominant retained objects.
4. Patch + re-run soak.

## 14. Network Optimization
- HTTP/2 keep-alive.
- gRPC deadlines set (avoid indefinite waits).
- Compression (gzip) for large payloads (opt-in).
- Coalesce small messages in chat pipeline if Nagle disabled.

## 15. Backlog Seeds
- Story: Implement automated latency regression check in CI.
- Story: Add plan hash monitor exporter.
- Story: Async profiler script for load test run.
- Story: Add caching hit/miss Prometheus metric.
- Story: Soak test scenario (8h scheduler).

## 16. Escalation Thresholds
| Signal | Threshold | Action |
|--------|----------|--------|
| p95 latency ↑ 30% | 2 consecutive builds | Block merge |
| Error rate > 1% | Immediate | Rollback / investigate |
| Kafka lag > 5k msgs | 5 min sustained | Scale consumer / alert |
| CPU > 85% | 10 min | Scale horizontally |
| GC pause > 500ms | 5 occurrences | Investigate allocation |

## 17. Future
- Adaptive concurrency limits (Netflix Concurrency Limits).
- Tail-based sampling for slow traces only.
- Multi-region latency heatmap.

---