# Domain Architecture – ML / AI Services

## 1. Purpose
Centralize model serving, feature retrieval, experimentation, and inference APIs consumed by other domains.

## 2. Capabilities
| Capability | Description |
|------------|-------------|
| Feature Store API | Retrieve feature vectors (Redis or Cassandra) |
| Recommendation Service | Given userId, return recommended products/posts |
| Fraud Detection | Score order events |
| Anomaly Scoring | Evaluate telemetry metrics |
| Moderation (optional) | Classify chat/social content |

## 3. Data Sources
- Consumes domain events (orders, telemetry, posts, chat messages)
- Curated warehouse tables (fact_orders, dim_product)
- Feature registry YAML (versioned)

## 4. Feature Store
- Redis key pattern: feature:{featureGroup}:{entityId}
- TTL for volatile features (recent activity).
- Batch loader populates from warehouse nightly.

## 5. Inference APIs
REST:
- GET /api/v1/recommendations/products?userId=U1
- POST /api/v1/fraud/score { orderId }
gRPC (optional future):
```
service Recommendations {
  rpc GetProductRecommendations(UserId) returns (ProductList);
}
```

## 6. Model Management
Metadata store (Postgres):
- models(id, name, version, status, created_at)
- model_metrics(model_id, metric_name, value, recorded_at)

Deployment Strategy:
- Blue/Green via separate endpoint version
- Model version header: X-Model-Version

## 7. Events Produced
| Event | Purpose |
|-------|---------|
| ml.fraud.order.scored.v1 | Downstream actions (manual review) |
| ml.recommendation.served.v1 | Observability / A/B tracking |
| ml.anomaly.detected.v1 | IoT / Inventory reaction |

## 8. Testing
| Type | Focus |
|------|-------|
| Unit | Feature extraction logic |
| Integration | Event ingestion to feature store |
| Performance | Recommendation latency p95 |
| Drift Monitoring (manual) | Compare feature distributions over time |

## 9. Observability
Metrics:
- inference_latency_ms
- model_version_request_count
- feature_cache_hit_ratio
- fraud_score_distribution (histogram buckets)

Tracing:
- Inference call spans with model version attribute.

## 10. Security
- Auth required for inference (JWT).
- Rate limiting per client key.
- Model artifacts stored in object storage with signed URLs (future).

## 11. Implementation Order
1. Feature store scaffold + Redis integration
2. Simple rule-based recommendation (no ML yet)
3. Fraud scoring stub (random score)
4. Inference REST endpoints + tracing
5. Event emission for consumption audit
6. Replace stub with lightweight ML (e.g., collaborative filtering mock)
7. Add gRPC service
8. Introduce model metadata & A/B version routing

## 12. Interoperability Checklist
- [ ] Consumes only public domain event types
- [ ] Does not introduce direct DB coupling to other domains
- [ ] Features versioned & documented
- [ ] Recommendation response stable & backward compatible

## 13. Exit Criteria
- Recommendation latency p95 < 150ms (local)
- Fraud scoring event produced for each paid order
- Feature cache > 80% hit rate after warmup
