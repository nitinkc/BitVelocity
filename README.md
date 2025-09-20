# Repositories
Repo of repos : https://github.com/nitinkc/BitVelocity.git

Submodules :
- https://github.com/nitinkc/bv-core-common.git
- https://github.com/nitinkc/bv-core-event.git
- https://github.com/nitinkc/bv-core-platform-bom.git
- https://github.com/nitinkc/bv-eCommerce-core.git
- https://github.com/nitinkc/bv-chat-stream.git
- https://github.com/nitinkc/bv-iot-control-hub.git
- https://github.com/nitinkc/bv-social-pulse.git
- https://github.com/nitinkc/BitVelocity.wiki.git
- https://github.com/nitinkc/bv-infra-service.git
- https://github.com/nitinkc/bv-security-core.git

Clone all projects in submodule. Fetch up to 6 submodules at a time (in parallel) with 

```shell
 git clone --recurse-submodules -j6 https://github.com/nitinkc/BitVelocity.git
```

** Submodules are tracked using a branch instead of a commit **. 

```shell
[submodule "foo"]
    path = foo
    url = ...
    branch = main
```

This will check out the tip of the branch (e.g., main) in the submodule, instead of a fixed commit.

```sh
git submodule update --remote
```

# Docs 
[https://nitinkc.github.io/BitVelocity-Docs/](https://nitinkc.github.io/BitVelocity-Docs/)

# BitVelocity – Multi-Domain Distributed Learning Platform

You are building a protocol-rich, security-first, cloud-portable platform for hands-on mastery:
- Domains: e-commerce, chat, IoT, social, security, infra
- Protocols: REST, GraphQL, gRPC, WebSocket, SSE, Kafka, AMQP, MQTT, Webhooks, SOAP, batch, stream processing
- Data: OLTP (Postgres) → Events + CDC → Derived (Redis/Cassandra/OpenSearch) → OLAP (Parquet/ClickHouse/BigQuery)
- Security: JWT → OAuth2/OIDC → OPA policies → Vault → mTLS
- Infra: Pulumi (Java) for portable definition (local → GCP → AWS/Azure)
- Multi-Region (east/west) & DR later in roadmap
- Cost discipline: local-first, ephemeral cloud windows

## Repository Role
This repo is the “meta” or root aggregator. Each domain may live here as submodules (or you can spin separate repos named:
- bv-ecommerce-core
- bv-chat-stream
- bv-iot-control-hub
- bv-social-pulse
- bv-security-core
- bv-infra-service
… plus shared libs if separated.

Current approach: Start WITHIN this repo using a multi-module structure for velocity; later you can eject modules to their own repo with minimal refactoring because:
- Each module uses only published shared libs (bv-core-common, bv-event-core, bv-security-lib, bv-test-core).
- No cross-module internal compile-time dependencies across domains (only libs).

## High-Level Early Milestones
1. Sprint 1: Auth + Product (+ shared libs, event envelope, local infra)
2. Sprint 2: Orders + Inventory proto + Kafka + Redis cache
3. Sprint 3: Inventory gRPC impl + WebSocket notifications
4. Sprint 4+: GraphQL, Chat, etc. (see architecture docs)

## Run Local (after first commit)
```
./mvnw clean verify
./scripts/dev/start-infra.sh
(cd services/product-service && ./mvnw spring-boot:run)
curl http://localhost:8081/api/v1/products
```

## Cost Strategy
- Do not provision cloud until Sprint 2/3 smoke is stable.
- Use the Pulumi local “kind” stack for Postgres + Kafka + Redis.
- Destroy ephemeral cloud stacks after tests (pulumi destroy + TTL tags).

See docs/architecture/ for deep design and docs/adr for decisions.


