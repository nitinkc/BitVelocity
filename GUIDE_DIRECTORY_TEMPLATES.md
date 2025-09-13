# Directory Template Guide (Apply Per Repo)

| Layer | Folder Pattern | Notes |
|-------|----------------|-------|
| Source | `services/<svc>/src/main/java` | Standard Maven structure |
| Tests | `src/test/java` + `bdd/features` | Separate BDD from unit/integration |
| Infra | `infra/pulumi/` | Domain-specific infra overlays if needed |
| Docs | `docs/` | ADRs, API specs, diagrams (PlantUML / Mermaid) |
| Events | `docs/events/*.json` | Schema-registry validated |
| Contracts | `contracts/{rest|grpc}` | Pact / proto golden files |
| Scripts | `scripts/` | start/stop, replay, cost utilities |
| Security | `security/opa`, `security/vault` | Policy & secret policy docs |
| Performance | `performance/gatling` | Load test scenarios |
| Fuzz | `fuzz/jazzer` | Input fuzz harnesses |
| Replay | `scripts/replay` | Projections rebuild tools |
