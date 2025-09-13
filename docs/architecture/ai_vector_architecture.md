# AI & Vector Architecture Blueprint
Version: 1.0  
Status: Draft  

## 1. Objectives
- Enable semantic search & recommendation features.
- Provide foundation for Retrieval-Augmented Generation (RAG) over product & documentation corpus.
- Support real-time embedding updates after product changes.

## 2. Components
| Component | Role |
|-----------|------|
| Embedding Service | Generates vector embeddings (text → vector) |
| Vector Store (Qdrant / Weaviate / OpenSearch) | Index & similarity search |
| Feature Store (Redis) | Real-time features (click counts, conversion) |
| Inference Gateway | Abstraction layer (REST/gRPC) for search & recommend |
| Batch Trainer (future) | Offline model retraining |
| RAG Orchestrator | Combines semantic retrieval + LLM generation (optional) |

## 3. Data Flow
```
ProductUpdated Event -> Embedding Service -> Vector Store upsert
Search Query -> Inference Gateway -> Vector similarity -> Product IDs -> Feature enrichment -> Response
```

## 4. Embedding Generation
- Model: Sentence-Transformer MiniLM (OSS).
- Batch vs Real-time:
  - Real-time: Single product updates (<200ms).
  - Batch nightly re-index for drift.
- Fields concatenated: `name + category + brand + short_description`.

## 5. Vector Schema (Qdrant Example)
| Field | Type |
|-------|------|
| id | UUID |
| vector | float[384] |
| productId | keyword |
| category | keyword |
| updatedAt | timestamp |

Payload JSON stored for filtering (category filter, region personalization).

## 6. Semantic Search API
Request:
```json
{ "query": "lightweight running shoes", "topK": 10, "filters": { "category": "shoes" } }
```
Steps:
1. Embed query.
2. Vector similarity search (top 100).
3. Re-rank (feature-weighted: CTR, recency).
4. Return topK with enrichment.

## 7. Feature Enrichment
Feature candidates:
- `rolling_click_rate_7d`
- `purchase_conversion_rate`
- `inventory_available` (boost if > threshold)
Stored in Redis hash keyed by `product:<id>:features`.

## 8. RAG (Optional Future)
- Document sources: architecture docs, FAQs.
- Chunking pipeline (approx 512 tokens).
- Store chunk embeddings in separate vector collection.
- Retrieval:
  1. Query embed
  2. Top N chunks
  3. Construct prompt context
  4. Pass to LLM (local or API)
Add metadata (source file, line ref) for transparency.

## 9. Real-Time Update Latency SLO
| Step | Target |
|------|--------|
| Event to embedding start | < 200ms |
| Embedding compute | < 120ms |
| Vector upsert | < 50ms |
| Total | < 500ms |

## 10. Drift & Quality Monitoring
Metrics:
- Embedding queue length
- Upsert error rate
- Query latency p95
- Relevance evaluation (offline test set MRR / NDCG)
Log sample query/responses for evaluation dataset updates.

## 11. Security & Privacy
- Avoid storing PII in vector payloads.
- Sign internal gRPC/REST calls (mTLS) for embedding service.
- Limit public similarity search fields (filter injection prevention).

## 12. Backlog Seeds
- Story: Qdrant docker-compose + basic collection init.
- Story: Embedding service with MiniLM (Java/Python sidecar).
- Story: ProductUpdated event triggers embedding upsert.
- Story: Semantic search endpoint with feature enrichment.
- Story: Metrics + dashboard (embedding latency, vector count).

## 13. Future Enhancements
- Approximate NN (HNSW) tuning for recall vs speed.
- Active learning: capture low-confidence queries for retraining.
- Diversification algorithms (Maximal Marginal Relevance).
- Personalized ranking (user embedding fused with item embedding).

---