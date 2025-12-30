# BitVelocity AI Coding Agent Instructions

## Big Picture Architecture
- BitVelocity is a multi-domain, protocol-rich platform for hands-on mastery of backend, cloud, and data engineering patterns.
- Major domains: eCommerce, Chat, IoT, Social Pulse, Security. Each domain is a separate folder (e.g., `bv-eCommerce-core`, `bv-chat-stream`, etc.) with its own services and README.
- Core shared libraries are in `bv-core-common` (auth, entities, events, logging, security). Use only published shared libs for cross-module dependencies.
- Infrastructure-as-code and cloud automation are in `bv-infra-service` (Pulumi, Gradle, cloud secrets, policy-as-code).
- Documentation and architecture guides are in `BitVelocity-Docs` (see `docs/00-OVERVIEW/README.md`).
- **Performance testing** is in `bv-performance-testing` (Gatling, k6, performance baselines).
- **Chaos engineering** experiments are in `bv-chaos-experiments` (Chaos Mesh, game day runbooks).
- **Observability** configuration is in `bv-observability` (OpenTelemetry, Prometheus, Grafana, Jaeger).
- **Security testing** is in `bv-security-testing` (OWASP ZAP, dependency scanning, penetration test scenarios).

## Developer Workflows
- **Java Build:** Use Maven (`mvnw`, `pom.xml`) for core modules, Gradle (`build.gradle`) for infra and performance tests. Run `./mvnw clean install` or `./gradlew build` from module root.
- **Dependency Management:** Use BOM in `bv-core-parent/pom.xml`. Child modules declare dependencies without versions; BOM manages versions.
- **Testing:** JUnit, Testcontainers, and Cucumber are used. Destroy ephemeral cloud stacks after tests (`pulumi destroy`).
- **Performance Testing:** Use Gatling (Java) for complex load tests, k6 for CI smoke tests. See `bv-performance-testing/README.md`.
- **Chaos Engineering:** Use Chaos Mesh for experiments. Always document experiments in `bv-chaos-experiments/`. See safety guidelines before running.
- **Debugging:** If classpath issues, run `./gradlew clean build` or `./mvnw clean install`.
- **Scripts:** Scripts are in `scripts/` and follow kebab-case naming. See `scripts/README.md` for conventions.

## Project-Specific Conventions
- Event contracts use `<domain>.<context>.<entity>.<eventType>.v<majorVersion>` naming (see `BitVelocity-Docs/docs/event-contracts/README.md`).
- File naming for entities: `entity.action.v<version>.json`.
- No PII leakage in event contracts; lint checks required fields and naming.
- Only use published shared libraries for cross-module dependencies.
- Secrets integration via Vault or cloud secret manager; policy-as-code via OPA or CrossGuard.
- **Performance baselines** must be defined in `bv-performance-testing/performance-baselines/sli-targets.yaml`.
- **Chaos experiments** must include hypothesis, blast radius, and validation criteria.
- **All services** must expose OpenTelemetry metrics and traces (see `bv-observability/README.md`).
- **CI/CD pipelines** enforce quality gates: tests, security scans, contract validation (see `.github/workflows/`).

## Key References
- `BitVelocity-Docs/docs/00-OVERVIEW/README.md` — platform overview
- `bv-core-parent/pom.xml` — dependency management
- `bv-infra-service/README.md` — infra build/test/debug
- `scripts/README.md` — scripting conventions
- `BitVelocity-Docs/docs/event-contracts/README.md` — event contract conventions
- `bv-performance-testing/README.md` — performance testing guide
- `bv-chaos-experiments/README.md` — chaos engineering guide
- `bv-observability/README.md` — observability standards
- `bv-security-testing/README.md` — security testing practices
- `BitVelocity-Docs/docs/adr/ADR-015-load-testing-strategy.md` — load testing ADR
- `BitVelocity-Docs/docs/adr/ADR-016-chaos-engineering-framework.md` — chaos engineering ADR
- `BitVelocity-Docs/docs/adr/ADR-017-cicd-pipeline-architecture.md` — CI/CD ADR


bv-core-platform-bom (controls all versions) -> bv-core-parent (controls plugins etc.) -> bv-core-parent (this goes into every domain)


Try to keep code in `bv-core-common` reusable across domains. When adding features, consider if they belong in core or a specific domain module. it has modules like common auth, logging, security, etc.

When working on domain-specific features, focus on the respective domain folder (e.g., `bv-eCommerce-core` for eCommerce features).

Always focus on the requirements of the specific domain or module you are working on, while adhering to the shared conventions and patterns outlined above.

