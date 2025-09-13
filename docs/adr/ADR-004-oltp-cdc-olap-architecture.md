# ADR-004: OLTP → Events/CDC → Derived → OLAP

## Decision
Postgres as system of record. Debezium CDC + domain events drive projections (Redis, Cassandra, OpenSearch) and OLAP (Parquet + ClickHouse/BigQuery).

## Rationale
Industry standard separation, replay, cost control, additive learning.

## Consequences
+ Comprehensive data lineage
- Additional operational footprint