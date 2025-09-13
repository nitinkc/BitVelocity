# ADR-002: Domain Events + CDC

## Decision
Use explicit semantic domain events + Debezium CDC for granular state changes. No direct dual writes to derived stores.

## Rationale
Replay, analytics enrichment, projection rebuilds, schema evolution resilience.

## Consequences
+ Flexible rebuild/replay
+ Reduced coupling
- Additional infra (Debezium, schema registry)