# Data Sharding & Partitioning Strategy
Version: 1.0  
Status: Draft  
Owner: Architecture / Data Platform  
Last Updated: 2025-09-13

## 1. Purpose
Define consistent strategies for horizontal and vertical data scaling across BitVelocity domains (e-commerce, chat, feed, telemetry, analytics). Establish when to apply partitions vs shards, and the lifecycle of evolving from single-node to distributed storage.

## 2. Principles
- Start simple (single Postgres instance) → introduce partitioning → introduce logical sharding only when metrics justify.
- Prefer “predictable routing” over dynamic hashing initially.
- Keep write paths simple; complexity moves to projections/read models when possible.
- Each scaling step must include: observability instrumentation, migration safety, rollback plan.

## 3. Glossary
- Partition: Physical table segmentation (e.g. Postgres declarative RANGE).
- Shard: Logical dataset slice living on separate physical cluster/node.
- Hot Partition: Disproportionately higher write volume segment.
- Routing Key: Deterministic field deciding which shard gets a record.

## 4. Domain Requirements Overview
| Domain | Growth Vector | Latency Sensitivity | Initial Store | Mid-Term Strategy | Long-Term |
|--------|---------------|---------------------|---------------|-------------------|-----------|
| Orders | Steady + burst (campaigns) | Medium | Postgres | Monthly RANGE partitions + index | Hybrid: Time + Hash |
| Inventory Events | Device & order driven | Medium | Postgres | Time partition (daily) | Offload to Kafka + aggregated view |
| Chat Messages | Potentially high fan-in per channel | High | Postgres (append log) | Hash shard by (roomId % N) | Cassandra / Scylla migration |
| Feed Activities | High write fan-out | Medium | Kafka → materialized Postgres | Hash shard by userId | Add Elastic / Columnar |
| Telemetry (IoT) | High write / time-series | Low-lat realtime queries | Postgres | Time partition daily + BRIN | Move to TSDB / ClickHouse |
| Analytics Facts | Batch append | Low | Delta/Iceberg | Partition by date | Z-Order / Clustering |

## 5. Partitioning Patterns
| Pattern | Use-Case | Implementation | Tooling |
|---------|----------|----------------|---------|
| RANGE (time) | Orders, telemetry | `PARTITION BY RANGE (created_at)` monthly/daily | pg_partman |
| LIST (region) | Multi-region catalog | `PARTITION BY LIST (region_code)` | Manual |
| HASH (logical) | Pre-shard simulation | Application routing key → schema suffix | App layer |
| Hybrid (range+hash) | High volume orders | Partition by month, table suffix by hash bucket | Migrations + metadata registry |

## 6. Shard Key Selection Guidelines
| Anti-Pattern | Why Bad | Mitigation |
|--------------|---------|-----------|
| Monotonic key (auto-inc ID) | Last partition hotspot | Add time bucket / hash |
| Low cardinality (status) | Skew | Combine fields or avoid |
| UserId only (few “heavy” users) | Hot users dominate | Add temporal bucket / channel |
| Random UUID for time queries | No locality | Store time in separate index/partition |

## 7. Migration Phases (Orders Example)
1. Phase 0: Single table `orders`.
2. Phase 1: Add partitioned table (monthly) + dual write OFF. Backfill historical.
3. Phase 2: Switch writes to partitioned table; shadow read compare (metric).
4. Phase 3: Introduce logical hash buckets (if p95 write queue > threshold).
5. Phase 4: Externalize to multi-cluster or Citus if analytical fan-out needed.

## 8. Routing Layer Design
Simple Java utility:
```java
class ShardRouter {
  int bucket(String orderId) {
     return Math.floorMod(orderId.hashCode(), activeBucketCount());
  }
}
```
Active bucket count in config (Pulumi exported). Store mapping metadata in a registry table for future dynamic expansion.

## 9. Metadata & Observability
Track per partition:
- Row count
- Bloat %
- Last vacuum/analyze timestamp
- Query latency (95th)
- Hot key frequency (top 20)
Publish: `db_partition_stats{table, partition}` Prometheus metrics.

## 10. Hot Partition Detection
Algorithm:
1. Collect write counts per partition per 1m.
2. Compute z-score; if > 3 for 3 consecutive intervals → flag.
3. Emit `shard.hot_partition.detected` event → triggers scale plan.

## 11. Rebalancing Strategy (Hash Buckets)
- Double bucket count (N → 2N).
- New records route to new mod.
- Background migrator rehashes old buckets gradually (idempotent).
- Dual-read period merges old+new bucket sets.

## 12. Risk & Mitigation
| Risk | Mitigation |
|------|------------|
| Complex early sharding | Delay until throughput threshold defined |
| Data skew after campaign | Real-time metrics; burst temporary caching |
| Rebalance contention | Rate limit migration batch size |
| Cross-shard transactions | Use saga or eventual consistency projections |

## 13. Decision Triggers
Introduce partitioning if:
- Table size > 50GB OR
- p95 sequential scans degrade > 30% baseline
Introduce sharding if:
- Single partition write QPS > hardware capacity OR
- Vacuum/autovacuum falling behind consistently

## 14. Backlog Seeds
- Story: Implement monthly partitioning for Orders with pg_partman.
- Story: Partition telemetry daily + add BRIN index.
- Spike: Evaluate Cassandra vs Postgres + Citus for Chat (simulate 500K msgs/day).
- Story: Add shard routing module + metrics.
- Story: Partition observability dashboard.

## 15. Open Questions
- Adopt Citus for horizontal Postgres early or defer?
- Introduce consistent hashing library or keep naive mod hashing?
- Consider separate logical DB per region or single multi-tenant cluster?

## 16. References
- PostgreSQL Partitioning Docs
- Citus Architecture Notes
- Twitter Snowflake ID approach
- Stripe blog on shard rebalancing

---