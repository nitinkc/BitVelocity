# ADR Starter Pack Overview

Included ADRs:
1. Multi-Repo over Monorepo
2. Domain Events + CDC Strategy
3. Protocol Introduction Order
4. OLTP→CDC→OLAP & Serving Architecture
5. Security Layering Strategy
6. Retry & Backoff Policy Matrix
7. Observability Baseline
8. Pulumi Cloud Provider Abstraction

How to Add a New ADR:
1. Copy template `docs/adr/ADR-TEMPLATE.md`
2. Increment next sequence number
3. Keep status = Proposed until reviewed
4. Merge only after at least one reviewer approves

ADR Template Keys:
- Context (why now)
- Decision (one sentence)
- Alternatives
- Consequences (+/-)
- Migration / Implementation Plan
