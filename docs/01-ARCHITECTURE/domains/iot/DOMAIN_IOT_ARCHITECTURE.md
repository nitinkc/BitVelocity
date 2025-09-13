# Domain Architecture – IoT Device Management

## 1. Purpose
Simulate device telemetry ingestion, inventory or analytics adjustments, firmware orchestration, anomaly detection learning path.

## 2. Services
| Service | Responsibility | Store |
|---------|----------------|-------|
| device-registry | Device identity, metadata, credentials | Postgres |
| telemetry-service | MQTT broker integration → Kafka | Kafka raw topics |
| firmware-service | Firmware update coordination state machine | Postgres |
| telemetry-analytics (later) | Stream processing, anomaly detection | Streams state / ClickHouse |
| edge-simulator (optional) | Publish synthetic MQTT payloads | N/A |

## 3. Protocols
| Use Case | Protocol |
|----------|----------|
| Device register/update | REST |
| Telemetry ingest | MQTT |
| Stream pipeline | Kafka Streams |
| Firmware orchestration | gRPC |
| Anomaly detection result | Event + optional Webhook |

## 4. Telemetry Payload
MQTT Topic: devices/{deviceId}/telemetry  
Payload (JSON):
```
{
  "ts": "...",
  "temperature": 24.1,
  "voltage": 3.7,
  "status": "OK"
}
```
Transformed into event: iot.telemetry.raw.v1 (partition by deviceId).

## 5. Data Model
Postgres:
- devices(id, serial, type, status, created_at)
- device_credentials(device_id, api_key_hash, rotated_at)
- firmware_artifacts(id, version, checksum, created_at)
- firmware_rollouts(id, artifact_id, target_group, status)
- firmware_rollout_device(rollout_id, device_id, status, updated_at)

## 6. Firmware gRPC (simplified)
```
service Firmware {
  rpc StartRollout(RolloutRequest) returns (RolloutAck);
  rpc ReportStatus(StatusReport) returns (Ack);
  rpc GetRollout(RolloutId) returns (RolloutState);
}
```

## 7. Stream Processing
Jobs:
- TelemetryNormalizer → enrich + validate
- AnomalyDetector (simple z-score or threshold)
- InventoryAdjustmentForwarder (optionally triggers ecommerce.inventory.stock.adjusted.v1)

## 8. Security
- Device credentials: hashed API key + optional rotation.
- MQTT authentication (username/apiKey).
- Rate-limit per device (broker plugin or ingress sidecar).
- Tokenless internal event pipeline.

## 9. Observability
Metrics:
- telemetry_ingest_rate
- telemetry_mqtt_connect_failures
- firmware_rollout_progress
- anomaly_events_total
Tracing:
- Firmware RPC sequences
- Telemetry transform pipeline stages

## 10. Resilience
| Concern | Solution |
|---------|----------|
| Burst telemetry | Backpressure via broker queue + streaming scaling (KEDA) |
| Device misbehavior | Quarantine list (deny subsequent messages) |
| Firmware partial failure | Retry policy per device with backoff |
| Clock skew | Normalize timestamps, warn on drift threshold |

## 11. Testing
| Layer | Target |
|-------|--------|
| Unit | Telemetry validation |
| Integration | MQTT → Kafka path |
| Load | Sustained ingest rate at configured target |
| Simulation | Edge emulator CLI |
| Contract | Firmware gRPC proto golden |
| Security | Device auth misuse attempts |

## 12. Implementation Order
1. Device registry REST + Postgres
2. MQTT broker (single) + telemetry ingestion to Kafka
3. Simple telemetry log consumer
4. Firmware gRPC scaffold
5. Anomaly threshold job
6. (Optional) Integration with E-Commerce inventory adjustments
7. Firmware rollout workflow
8. Advanced anomaly detection simulation

## 13. Interoperability Checklist
- [ ] Telemetry events conform to shared envelope
- [ ] Firmware events versioned
- [ ] Optional inventory adjustments use ecommerce event type spec
- [ ] Device identity not leaked in other domain logs (privacy)
- [ ] Anomaly events documented for ML/AI consumption

## 14. Cost Controls
- Single MQTT broker container.
- Avoid ClickHouse early: store anomalies in Postgres or Redis.
- Synthetic telemetry scale gating (env var max devices).

## 15. Exit Criteria
- Telemetry ingest stable at target throughput (e.g., 1k msg/s dev environment).
- Firmware rollout success metrics logged.
- Anomaly events emitted & visible in shared monitoring dashboard.
