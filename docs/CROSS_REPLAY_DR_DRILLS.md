# Cross-Cutting – Replay & Disaster Recovery Drills

## 1. Replay Goals
Rebuild derived projections and recover from data corruption or missed events.

## 2. Replay Data Sources
- Parquet archived domain events
- CDC parquet (Debezium output)
- Snapshot manifests (optional)

## 3. Replay Workflow
1. Identify target projection & timespan
2. Acquire input set (list parquet segments)
3. Stream sorted by timestamp/LSN
4. Apply transformation (same logic as live stream code)
5. Validation: sample checksums, row counts
6. Emit system.replay.completed.v1 event

## 4. CLI (Conceptual)
```
replay \
  --projection orders_by_customer \
  --from 2025-02-01T00:00Z \
  --to 2025-02-02T00:00Z \
  --events s3://archive/events/ecommerce.order/2025/02/01 \
  --cdc s3://archive/cdc/orders/2025/02/01 \
  --dry-run
```

## 5. DR Drill Types
| Drill | Scenario | Goal |
|-------|----------|------|
| Failover DB | East Postgres down | Promote replica |
| Kafka Partition Loss | Topic partial outage | Replay missing partition events |
| Cache Flush | Redis cleared | Rehydrate via events |
| Cross-Region Latency Spike | Simulate 500ms RTT | Validate fallbacks |
| Replay Integrity | Random projection deletion | Full rebuild parity |

## 6. Metrics
- replay_duration_seconds
- replay_events_processed_total
- replay_validation_failures_total
- dr_rto_seconds
- dr_rpo_seconds

## 7. DR Runbook (High-Level)
1. Detect incident (alerts)
2. Declare severity
3. Promote replica (script)
4. Update endpoints / DNS
5. Replay gap (if RPO > 0)
6. Verify service health & user flows
7. Post-mortem record & improvements

## 8. Exit Criteria
- At least one successful replay of each major projection (orders, feed)
- DR drill executed with RTO < 10m and RPO < 2m (learning targets)
- Replay job idempotent & documented
