# Directory Template Guide (Apply Per Repo)

This guide provides the standard directory structure for BitVelocity repositories.

## Standard Directory Layout

| Layer | Folder Pattern | Notes |
|-------|----------------|-------|
| **Source Code** | `services/<svc>/src/main/java` | Standard Maven structure |
| **Tests** | `src/test/java` + `bdd/features` | Separate BDD from unit/integration |
| **Infrastructure** | `infra/pulumi/` | Cloud-agnostic infrastructure as code |
| **Documentation** | `docs/` | ADRs, API specs, domain architecture |
| **Event Contracts** | `event-contracts/` | Shared event schemas by domain |
| **API Contracts** | `contracts/{rest,grpc}/` | Pact files, proto definitions |
| **Scripts** | `scripts/` | Start/stop, replay, cost utilities |
| **Security** | `security/{opa,vault}/` | Policy definitions & secret management |
| **Performance** | `performance/gatling/` | Load test scenarios |
| **Fuzz Testing** | `fuzz/jazzer/` | Input fuzz harnesses |
| **Replay Tools** | `scripts/replay/` | Event replay & projection rebuild |

## Documentation Structure
```
docs/
  00-OVERVIEW/           # High-level system overview
  01-ARCHITECTURE/       # Domain architecture files
  02-INFRASTRUCTURE/     # Infrastructure patterns
  03-DEVELOPMENT/        # Developer guides
  05-PROJECT-MANAGEMENT/ # Sprint planning, execution
  adr/                   # Architecture Decision Records
  architecture/          # System diagrams (PlantUML/Mermaid)
```

## Event Contracts Structure
```
event-contracts/
  <domain>/
    <context>/
      <entity>.<eventType>.v<version>.json
  schema/
    envelope.schema.json
```

## Service Structure (Java/Spring Boot)
```
services/<service-name>/
  src/
    main/java/
      com/bitvelocity/<domain>/
        application/       # Application services
        domain/           # Domain entities & aggregates  
        infrastructure/   # Repositories, external adapters
        interfaces/       # REST controllers, message handlers
    test/java/           # Unit & integration tests
  bdd/features/          # BDD scenarios
  contracts/             # Pact consumer/provider tests
  README.md             # Service documentation
```

## Infrastructure Structure
```
infra/
  common/               # Shared infrastructure components
  networking/           # VPC, subnets, security groups
  kubernetes/           # EKS/GKE cluster definitions
  database/            # RDS, managed databases
  messaging/           # Kafka, RabbitMQ clusters
  secrets/             # Vault, secret management
  monitoring/          # Prometheus, Grafana setup
```

## Security Structure
```
security/
  opa/                 # Open Policy Agent policies
    policies/          # RBAC, data access policies
    tests/             # Policy unit tests
  vault/               # HashiCorp Vault configuration
    policies/          # Vault policies
    auth/              # Authentication methods
```

## Quality Assurance
| Aspect | Location | Tools |
|--------|----------|-------|
| **Unit Tests** | `src/test/java` | JUnit, Mockito |
| **Integration Tests** | `src/test/java` | TestContainers |
| **BDD Tests** | `bdd/features` | Cucumber |
| **Contract Tests** | `contracts/` | Pact |
| **Load Tests** | `performance/` | Gatling |
| **Security Tests** | `security/tests/` | OWASP ZAP |
| **Fuzz Tests** | `fuzz/` | Jazzer |

## Cross-Repository Consistency
- All repos follow this template structure
- Event contracts are shared across repositories
- Infrastructure patterns are reusable
- Documentation standards are consistent
- Security policies are centrally managed

## Implementation Guidelines
1. **Start Simple**: Begin with core directories, add others as needed
2. **Domain Alignment**: Structure reflects domain boundaries
3. **Tool Consistency**: Use same tools across repositories
4. **Documentation**: Keep README.md files updated
5. **Automation**: Script common operations in `scripts/`

## References
- [Event Contracts Guide](../GUIDE_EVENT_CONTRACTS_USAGE.md)
- [Cross-Cutting Documentation](docs/INDEX_DOMAIN_DESIGNS.md)
- [Infrastructure Portability](docs/CROSS_INFRA_PORTABILITY_AND_DEPLOYMENT.md)
