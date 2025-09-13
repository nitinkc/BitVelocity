# BitVelocity: Multi-Domain Distributed Learning Platform

## Overview
BitVelocity is a comprehensive distributed learning platform designed for hands-on mastery of modern backend systems, cloud technologies, and data engineering patterns. This project focuses on learning through practical implementation while maintaining production-ready architectural patterns.

## Project Objectives
- **Multi-Domain Learning**: Showcase real-world patterns across e-Commerce, messaging/chat, IoT, and social media domains
- **Protocol Breadth**: Implement REST, GraphQL, gRPC, WebSocket, SSE, MQTT, AMQP, Kafka, Webhooks, and SOAP
- **Cloud Portability**: Pulumi-based infrastructure supporting GCP, AWS, and Azure with minimal migration effort
- **Cost Optimization**: Leverage free tiers and cost-effective learning strategies
- **Production Patterns**: Implement security, observability, disaster recovery, and data governance

## Target Audience
- **Software Architects**: Comprehensive system design and architectural decision records
- **Backend Developers**: Microservices patterns and protocol implementation guides
- **Platform Engineers**: Infrastructure automation and multi-cloud deployment strategies
- **Data Engineers**: OLTP to OLAP pipelines, data governance, and analytics patterns
- **DevOps Engineers**: Observability, security, and operational excellence practices

## Quick Navigation

### For Architects and Technical Leaders
- [System Architecture Overview](../01-ARCHITECTURE/system-overview.md)
- [Data Architecture & OLTP→OLAP Strategy](../01-ARCHITECTURE/data-architecture.md)
- [Security Architecture](../01-ARCHITECTURE/security-architecture.md)
- [Architectural Decision Records](../adr/)

### For Developers
- [Microservices Patterns](../03-DEVELOPMENT/microservices-patterns.md)
- [API Protocols Guide](../03-DEVELOPMENT/api-protocols.md)
- [Domain-Specific Architecture](../01-ARCHITECTURE/domains/)

### For Platform and Operations Teams
- [Infrastructure Strategy](../02-INFRASTRUCTURE/cloud-strategy.md)
- [Deployment Architecture](../02-INFRASTRUCTURE/deployment-architecture.md)
- [Observability Strategy](../04-OPERATIONS/observability.md)
- [Disaster Recovery](../04-OPERATIONS/disaster-recovery.md)

### For Project Management
- [Execution Roadmap](../05-PROJECT-MANAGEMENT/execution-roadmap.md)
- [Sprint Planning](../05-PROJECT-MANAGEMENT/sprint-planning.md)
- [Budget Planning](../05-PROJECT-MANAGEMENT/budget-planning.md)

## Project Principles
1. **Learn Breadth with Depth**: Real patterns, not toy implementations
2. **Incremental Complexity**: Master each layer before adding the next
3. **Portability First**: Avoid vendor lock-in through abstraction layers
4. **Observability by Design**: Shift-left on monitoring, security, and cost control
5. **Cost-Conscious Learning**: Maximize learning value while minimizing expenses

## Technology Stack
- **Languages**: Java (Spring Boot), with TypeScript for UI components
- **Infrastructure**: Pulumi (Java SDK) for cloud-agnostic deployments
- **Databases**: PostgreSQL (OLTP), Cassandra/MongoDB (scale-out), Analytics platforms
- **Messaging**: Kafka, NATS, RabbitMQ for different messaging patterns
- **Security**: JWT, OAuth2, HashiCorp Vault, mTLS
- **Observability**: OpenTelemetry, Prometheus, Grafana, ELK Stack
- **Testing**: JUnit, Testcontainers, Cucumber for comprehensive test coverage

## Getting Started
1. Review the [Project Charter](project-charter.md) for detailed context
2. Understand your role with the [Stakeholder Guide](stakeholder-guide.md)
3. Follow the [Execution Roadmap](../05-PROJECT-MANAGEMENT/execution-roadmap.md) for implementation sequence
4. Start with the foundational [System Architecture](../01-ARCHITECTURE/system-overview.md)

## Repository Structure
```
BitVelocity/
├── docs/                          # All documentation (this folder)
│   ├── 00-OVERVIEW/              # Project overview and navigation
│   ├── 01-ARCHITECTURE/          # System and domain architecture
│   ├── 02-INFRASTRUCTURE/        # Cloud and deployment strategy
│   ├── 03-DEVELOPMENT/           # Development patterns and practices
│   ├── 04-OPERATIONS/            # Operational excellence
│   ├── 05-PROJECT-MANAGEMENT/    # Planning and execution
│   └── adr/                      # Architectural Decision Records
├── bv-eCommerce-core/            # E-commerce domain implementation
├── bv-chat-stream/               # Chat and messaging domain
├── bv-iot-control-hub/           # IoT device management
├── bv-social-pulse/              # Social media domain
├── bv-security-core/             # Cross-cutting security services
├── bv-infra-service/             # Infrastructure automation
└── event-contracts/              # Shared event schemas and contracts
```

---
*This documentation is designed to be living and evolving. Contributions and feedback are welcome as we build this comprehensive learning platform.*