# BitVelocity AI Coding Agent Instructions

## Big Picture Architecture
- BitVelocity is a multi-domain, protocol-rich platform for hands-on mastery of backend, cloud, and data engineering patterns.
- Major domains: eCommerce, Chat, IoT, Social Pulse, Security. Each domain is a separate folder (e.g., `bv-eCommerce-core`, `bv-chat-stream`, etc.) with its own services and README.
- Core shared libraries are in `bv-core-common` (auth, entities, events, logging, security). Use only published shared libs for cross-module dependencies.
- Infrastructure-as-code and cloud automation are in `bv-infra-service` (Pulumi, Gradle, cloud secrets, policy-as-code).
- Documentation and architecture guides are in `BitVelocity-Docs` (see `docs/00-OVERVIEW/README.md`).

## Developer Workflows
- **Java Build:** Use Maven (`mvnw`, `pom.xml`) for core modules, Gradle (`build.gradle`) for infra. Run `./mvnw clean install` or `./gradlew build` from module root.
- **Dependency Management:** Use BOM in `bv-core-parent/pom.xml`. Child modules declare dependencies without versions; BOM manages versions.
- **Testing:** JUnit, Testcontainers, and Cucumber are used. Destroy ephemeral cloud stacks after tests (`pulumi destroy`).
- **Debugging:** If classpath issues, run `./gradlew clean build` or `./mvnw clean install`.
- **Scripts:** Scripts are in `scripts/` and follow kebab-case naming. See `scripts/README.md` for conventions.

## Project-Specific Conventions
- Event contracts use `<domain>.<context>.<entity>.<eventType>.v<majorVersion>` naming (see `BitVelocity-Docs/docs/event-contracts/README.md`).
- File naming for entities: `entity.action.v<version>.json`.
- No PII leakage in event contracts; lint checks required fields and naming.
- Only use published shared libraries for cross-module dependencies.
- Secrets integration via Vault or cloud secret manager; policy-as-code via OPA or CrossGuard.

## Integration Points & Patterns
- Messaging: Kafka, NATS, RabbitMQ (see `BitVelocity-Docs/docs/00-OVERVIEW/README.md`).
- Data pipelines: OLTP to OLAP, data governance, analytics (see docs and domain folders).
- Microservices patterns: See `BitVelocity-Docs/docs/03-DEVELOPMENT/microservices-patterns.md`.

## Key References
- `BitVelocity-Docs/docs/00-OVERVIEW/README.md` — platform overview
- `bv-core-parent/pom.xml` — dependency management
- `bv-infra-service/README.md` — infra build/test/debug
- `scripts/README.md` — scripting conventions
- `BitVelocity-Docs/docs/event-contracts/README.md` — event contract conventions


bv-core-platform-bom (controls all versions) -> bv-core-parent (controls plugins etc.) -> bv-core-parent (this goes into every domain)


Try to keep code in `bv-core-common` reusable across domains. When adding features, consider if they belong in core or a specific domain module. it has modules like common auth, logging, security, etc.

When working on domain-specific features, focus on the respective domain folder (e.g., `bv-eCommerce-core` for eCommerce features).

Always focus on the requirements of the specific domain or module you are working on, while adhering to the shared conventions and patterns outlined above.

