# BitVelocity Specialized Agents

## Overview

9 specialized AI agents, each with deep expertise in specific BitVelocity domains and engineering functions. Use these agents by referencing them in VS Code Chat or when invoking subagents.

---

## 1. ecommerce-domain

**Expertise**: eCommerce microservices (orders, payments, inventory, pricing, notifications)

**Responsibilities**:
- Order service implementation and optimization
- Payment adapter patterns
- Inventory management and reservation strategies
- Cart service and checkout flows
- Pricing and promotion engine
- Cross-domain event integration

**Use When**:
- Implementing order processing features
- Designing payment authorization flows
- Building inventory reservation systems
- Creating pricing rules and promotions
- Integrating shipping with order management

**Example**:
```
@ecommerce-domain How should I design the return order flow? 
Should returns create new Order events or modify existing ones?
```

**References**:
- `bv-eCommerce-core/order-service/README.md`
- `bv-eCommerce-core/payment-adapter-service/README.md`
- `DOMAIN_ECOMMERCE_ARCHITECTURE.md`

---

## 2. event-contracts-specialist

**Expertise**: Event design, versioning, PII compliance, cross-domain integration

**Responsibilities**:
- Event naming conventions and semantic versioning
- JSON schema design and validation
- Event versioning strategies (v1→v2→v3)
- PII detection and exclusion
- Event publishing/consuming patterns
- Event contract documentation
- Backward compatibility management

**Use When**:
- Creating new domain events
- Versioning existing events
- Ensuring PII compliance
- Designing event schemas
- Planning cross-domain integration
- Troubleshooting event deserialization

**Example**:
```
@event-contracts-specialist We need to add shipping address to OrderCreated event 
without breaking existing consumers. What's the migration path?
```

**References**:
- `BitVelocity-Docs/docs/event-contracts/README.md`
- `.github/skills/SKILL-event-contracts.md`
- `bv-core-common/bv-common-events/`

---

## 3. testing-qa-specialist

**Expertise**: Unit tests, integration tests, contract tests, E2E tests, chaos testing, QA strategy

**Responsibilities**:
- Test pyramid design and implementation
- JUnit + Mockito patterns
- Testcontainers setup
- Spring Cloud Contract definitions
- Cucumber feature files and step definitions
- Performance baseline testing
- Chaos experiment design
- Test coverage analysis

**Use When**:
- Writing tests for new feature
- Setting up test infrastructure
- Debugging test failures
- Planning test strategy
- Validating event contracts
- Designing chaos experiments

**Example**:
```
@testing-qa-specialist The integration test for payment authorization 
is flaky due to timing issues. How should I structure the test?
```

**References**:
- `.github/bitvelocity-testing.instructions.md`
- `bv-core-common/src/test/`
- `bv-chaos-experiments/README.md`

---

## 4. performance-benchmark-engineer

**Expertise**: Load testing, performance optimization, SLI/SLO definition, capacity planning

**Responsibilities**:
- Gatling simulation design
- k6 smoke test creation
- Performance baseline establishment
- Latency/throughput target definition
- Profiling and optimization
- Capacity planning
- Performance regression detection
- Continuous monitoring setup

**Use When**:
- Creating load tests for endpoint
- Establishing performance targets
- Optimizing slow queries
- Planning for growth
- Setting up monitoring dashboards
- Analyzing performance results

**Example**:
```
@performance-benchmark-engineer What's a realistic p95 latency target 
for a database query involving 3 joins? How do we test for it?
```

**References**:
- `.github/skills/SKILL-performance-testing.md`
- `bv-performance-testing/gatling-tests/`
- `bv-performance-testing/k6-scripts/`
- `bv-performance-testing/performance-baselines/sli-targets.yaml`

---

## 5. requirements-analyst

**Expertise**: Domain-driven design, requirements gathering, user story decomposition, acceptance criteria

**Responsibilities**:
- Bounded context identification
- Ubiquitous language development
- Functional/non-functional requirement analysis
- User story estimation and decomposition
- Acceptance criteria definition
- Event contract specification
- API contract design
- Requirements validation

**Use When**:
- Starting new feature work
- Gathering requirements from stakeholders
- Defining cross-domain integrations
- Validating requirements completeness
- Breaking down epics into stories
- Planning performance baselines

**Example**:
```
@requirements-analyst Help me break down the "customer returns" feature 
into stories and acceptance criteria with clear event contracts.
```

**References**:
- `.github/bitvelocity-requirements.instructions.md`
- `BitVelocity-Docs/docs/event-contracts/README.md`

---

## 6. infrastructure-automation

**Expertise**: Pulumi IaC, Kubernetes, ephemeral cloud stacks, CI/CD, secrets management

**Responsibilities**:
- Pulumi infrastructure-as-code design
- Kubernetes cluster setup and management
- Ephemeral stack creation/destruction
- Cloud provider integration (AWS/GCP/Azure)
- Secrets management (Vault, cloud vaults)
- CI/CD pipeline design
- GitOps workflows
- Cost optimization

**Use When**:
- Setting up cloud infrastructure
- Creating ephemeral test environments
- Deploying services to Kubernetes
- Managing secrets and credentials
- Designing CI/CD pipelines
- Planning disaster recovery

**Example**:
```
@infrastructure-automation How should we structure Pulumi to create 
ephemeral stacks per PR and auto-cleanup on merge?
```

**References**:
- `bv-infra-service/README.md`
- `bv-infra-service/src/main/java/`
- `k8s/`

---

## 7. security-compliance-expert

**Expertise**: Authentication, authorization, secrets, vulnerability scanning, audit logging, PII handling

**Responsibilities**:
- OAuth2/JWT implementation
- RBAC/ABAC design
- Secrets rotation strategies
- Dependency vulnerability scanning (OWASP)
- Penetration testing coordination
- Audit logging design
- PII detection and protection
- Compliance requirements (SOC2, GDPR, etc.)
- Security code review

**Use When**:
- Implementing authentication
- Designing authorization rules
- Managing service credentials
- Reviewing security vulnerabilities
- Planning audit trails
- Ensuring PII compliance

**Example**:
```
@security-compliance-expert How should we log sensitive transactions 
for audit trails without exposing customer PII?
```

**References**:
- `bv-security-testing/README.md`
- `bv-auth-service/README.md`
- `bv-core-common/bv-common-security/`

---

## 8. chaos-engineering-specialist

**Expertise**: Resilience testing, fault injection, game days, failure scenarios, recovery patterns

**Responsibilities**:
- Chaos Mesh experiment design
- Failure injection strategies (network latency, pod kills, etc.)
- Circuit breaker testing
- Timeout and retry pattern validation
- Game day runbook creation
- Blast radius assessment
- Recovery time validation
- Monitoring during chaos
- Hypothesis-driven experimentation

**Use When**:
- Designing resilience patterns
- Planning chaos experiments
- Testing circuit breaker behavior
- Validating timeout strategies
- Planning game days
- Improving MTTR (Mean Time to Recovery)

**Example**:
```
@chaos-engineering-specialist We want to test what happens when the 
inventory service is completely unavailable. How should we design 
this chaos experiment safely?
```

**References**:
- `bv-chaos-experiments/README.md`
- `bv-chaos-experiments/experiments/`
- `BitVelocity-Docs/docs/adr/ADR-016-chaos-engineering-framework.md`

---

## 9. mkdocs-content-specialist

**Expertise**: Documentation structure, ADRs, navigation, module synchronization, content strategy

**Responsibilities**:
- MkDocs site structure and navigation
- Markdown formatting and style
- Architecture Decision Records (ADRs)
- Module documentation synchronization
- Domain architecture documentation
- Event contract documentation
- Troubleshooting guides
- API documentation
- Changelog maintenance

**Use When**:
- Creating new documentation
- Updating architecture docs
- Writing ADRs
- Organizing documentation structure
- Synchronizing module READMEs
- Publishing release notes

**Example**:
```
@mkdocs-content-specialist Help me structure documentation for the new 
payment adapter service and ensure it's linked from the architecture guide.
```

**References**:
- `BitVelocity-Docs/.github/copilot-instructions.md`
- `BitVelocity-Docs/mkdocs.yml`
- `BitVelocity-Docs/docs/`

---

## How to Use Agents

### In VS Code Chat

```
@agent-name What is your question?

Examples:
@ecommerce-domain Design the order cancellation flow
@testing-qa-specialist How do I test async Kafka events?
@performance-benchmark-engineer What SLO should I target for this endpoint?
@requirements-analyst Help me write acceptance criteria for inventory checkout
@event-contracts-specialist How do I version the OrderCreated event?
@infrastructure-automation Create an ephemeral staging environment
@security-compliance-expert How should we handle payment PII in logs?
@chaos-engineering-specialist Test what happens when payment service fails
@mkdocs-content-specialist Create ADR template for architectural decisions
```

### With Subagents

```bash
# Example usage pattern for agents (reference format):
# @agent-name Help implement feature X
# @agent-name Review this design approach
# @agent-name Write the implementation for use case Y
```

---

## Agent Decision Matrix

**Use this table to pick the right agent:**

| Task | Agent | Why |
|------|-------|-----|
| Create Order service | `@ecommerce-domain` | Domain expertise in eCommerce patterns |
| Design event schema | `@event-contracts-specialist` | Event-specific knowledge |
| Write integration test | `@testing-qa-specialist` | Test patterns & Testcontainers |
| Set latency targets | `@performance-benchmark-engineer` | Performance baseline expertise |
| Break down epic | `@requirements-analyst` | User story & DDD expertise |
| Setup Kubernetes | `@infrastructure-automation` | Cloud infrastructure expertise |
| Find PII leak | `@security-compliance-expert` | Security & compliance focus |
| Design failover | `@chaos-engineering-specialist` | Resilience patterns |
| Document ADR | `@mkdocs-content-specialist` | Documentation expertise |

---

## Multi-Agent Workflows

### Workflow 1: Implement New Feature

```
1. @requirements-analyst
   - Gather requirements
   - Define acceptance criteria
   - Plan event contracts

2. @ecommerce-domain (if eCommerce)
   - Review domain design
   - Validate patterns

3. @event-contracts-specialist
   - Design event schemas
   - Plan versioning

4. @testing-qa-specialist
   - Plan test strategy
   - Design contract tests

5. @performance-benchmark-engineer
   - Set latency targets
   - Plan load tests

6. @security-compliance-expert
   - Review security design
   - Check PII handling

7. @mkdocs-content-specialist
   - Document feature
   - Create ADR
```

### Workflow 2: Performance Optimization

```
1. @performance-benchmark-engineer
   - Analyze current baseline
   - Identify bottleneck

2. @infrastructure-automation or @ecommerce-domain
   - Implement optimization
   - Adjust resource allocation

3. @testing-qa-specialist
   - Write performance regression test
   - Validate improvements

4. @chaos-engineering-specialist
   - Test optimization under stress
   - Validate resilience

5. @mkdocs-content-specialist
   - Document optimization
   - Update baselines
```

### Workflow 3: Security Audit

```
1. @security-compliance-expert
   - Scan for vulnerabilities
   - Review patterns

2. @event-contracts-specialist
   - Check for PII in events
   - Validate contracts

3. @testing-qa-specialist
   - Write security tests
   - Validate fixes

4. @mkdocs-content-specialist
   - Document findings
   - Update security guide
```

---

## Agent Interaction Guidelines

**When using multiple agents:**

1. **Start with requirements**: Use `@requirements-analyst` first
2. **Domain validation**: Use domain specialist (e.g., `@ecommerce-domain`)
3. **Implementation**: Use technology specialist (e.g., `@testing-qa-specialist`)
4. **Cross-cutting concerns**: Use `@security-compliance-expert` and `@performance-benchmark-engineer`
5. **Documentation**: Use `@mkdocs-content-specialist` last

**Example flow**:
```
@requirements-analyst
  ↓ (validates requirements)
@ecommerce-domain
  ↓ (reviews domain model)
@event-contracts-specialist
  ↓ (designs events)
@testing-qa-specialist
  ↓ (plans tests)
@performance-benchmark-engineer
  ↓ (sets baselines)
@mkdocs-content-specialist
  ↓ (documents)
```

---

## Agent Expertise Levels

**Deep Expertise** (can do end-to-end):
- ecommerce-domain
- event-contracts-specialist
- testing-qa-specialist
- infrastructure-automation
- mkdocs-content-specialist

**Specialized Expertise** (focused domain):
- performance-benchmark-engineer
- security-compliance-expert
- chaos-engineering-specialist
- requirements-analyst

---

## References

- Individual agent instructions: See respective files above
- All shared guidance: `.github/bitvelocity-development.instructions.md`
- Skills library: `.github/skills/SKILL-*.md`
