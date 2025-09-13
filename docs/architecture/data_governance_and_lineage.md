# Data Governance & Lineage Framework
Version: 1.0  
Status: Draft  

## 1. Goals
- Ensure data trust: quality, lineage, ownership, compliance.
- Provide visibility from source events → analytics → ML features.
- Enforce schema evolution rules & retention policies.

## 2. Pillars
| Pillar | Focus |
|--------|-------|
| Catalog | Metadata registry & ownership |
| Lineage | Dataset + column-level flows |
| Quality | Automated validation (Great Expectations) |
| Security | Access controls, masking |
| Compliance | Retention, PII tagging |
| Observability | Data freshness, SLA metrics |

## 3. Metadata Catalog
Store in `catalog.yaml` (initial file-based) or lightweight service:
```yaml
datasets:
  - name: bronze_orders
    owner: data-team
    pii: false
    retention_days: 365
    upstream: [order_outbox_table]
    downstream: [silver_orders]
```

## 4. Lineage Capture
Use OpenLineage client in:
- Bronze ingestion (CDC job).
- Silver transform job.
- Gold aggregation job.
Emit:
- Job run ID
- Inputs / Outputs
- Column mappings (where feasible)

## 5. Quality Dimensions
| Dimension | Example Rule |
|-----------|--------------|
| Completeness | No null `order_id` |
| Consistency | `total_amount = qty * unit_price` |
| Timeliness | Bronze → Silver lag < 5m |
| Uniqueness | `event_id` unique |
| Validity | price >= 0 |
| Accuracy (manual) | Spot sample cross-check |

## 6. Schema Evolution Policy
- Backward compatible only (additive).
- Field removal requires deprecation period (min 2 sprints).
- CI check: Reject PR if incompatible Avro/JSON schema change.
- Versioning: `eventType` includes version suffix `v1`, bump on breaking change.

## 7. Retention & Purging
| Dataset | Retention | Action |
|---------|-----------|--------|
| Raw telemetry (bronze) | 7 days | Automatic partition drop |
| Orders bronze | 1 year | Archive to cold storage after 1y |
| Aggregates | Indefinite | Small footprint |
| Sensitive logs | 30 days | Anonymize then purge |

## 8. PII & Sensitivity Tags
Columns annotated:
- `pii: email, phone`
- `sensitive: payment_token`
Masking strategies:
- Hash (irreversible) for analytics
- Tokenization for reversible sensitive fields
- Vault transit encryption for secure columns

## 9. Access Control
- Role groups: `data_engineer`, `ml_engineer`, `analyst_read`, `service_ingest`.
- Row-level security future (tenant).
- Principle: service accounts limited to required layer (e.g. order service cannot query gold).

## 10. KPIs
| KPI | Target |
|-----|--------|
| Data freshness (bronze→gold) | < 30m |
| Failed quality checks | < 1% rows failing |
| Schema compatibility failures | 0 per sprint |
| Lineage completeness | > 90% jobs reporting |
| PII leakage incidents | 0 |

## 11. Incident Response (Data Quality)
1. Detect failing expectation (pipeline halts optional).
2. Raise alert (#data-alerts).
3. Triage: root cause (source change? corrupted batch?).
4. Backfill strategy (re-run silver job with corrections).
5. Post-mortem logged (dataset doc updated).

## 12. Tooling Stack
| Function | Tool |
|----------|------|
| Quality | Great Expectations |
| Lineage | OpenLineage + Marquez |
| Catalog | YAML → future UI |
| Policy | CI custom scripts + schema registry |
| Alerting | Prometheus & Grafana |

## 13. Backlog Seeds
- Story: Add OpenLineage instrumentation to silver job.
- Story: Implement Great Expectations for FactOrder.
- Story: Catalog file bootstrap.
- Story: Schema compatibility GitHub Action.
- Story: Retention purge script for telemetry partitions.

## 14. Future Extensions
- Data contract enforcement per producer team.
- Column-level lineage from SQL parsing.
- Differential privacy for analytics exports.

---