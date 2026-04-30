# BitVelocity Monorepo

**Source**: [GitHub](https://github.com/nitinkc/BitVelocity) | **Docs Site**: [nitinkc.github.io/BitVelocity-Docs](https://nitinkc.github.io/BitVelocity-Docs/) | **Project Board**: [GitHub Projects](https://github.com/users/nitinkc/projects/8)

---

## 📖 Docs Site — Local Run

```bash
cd BitVelocity-Docs
pip install mkdocs-material
mkdocs serve
# Open: http://127.0.0.1:8000
```

---

## 🔨 Build All Modules

Build in dependency order:

```bash
cd bv-core-platform-bom && mvn clean install -DskipTests && cd ..
cd bv-core-parent      && mvn clean install -DskipTests && cd ..
cd bv-core-common      && mvn clean install -DskipTests && cd ..
cd bv-auth-service     && mvn clean install -DskipTests && cd ..
```

> Dependency hierarchy: `bv-core-platform-bom` (versions) → `bv-core-parent` (plugins) → domain modules

---

## 🚀 Run Locally

**1. Start Infrastructure**

```bash
cd scripts/dev
docker-compose -f docker-compose.infra.yml up -d
```

**2. Run Auth Service**

```bash
cd bv-auth-service
mvn spring-boot:run
# Runs on :8080
```

**3. Kubernetes (Kind/Minikube)**

```bash
kubectl apply -f k8s/postgres.yaml
kubectl apply -f k8s/auth-service.yaml
```

---

## ✅ Progress — What's Done

| Module | Status | Notes |
|--------|--------|-------|
| `bv-core-platform-bom` | ✅ Complete | BOM — controls all dependency versions |
| `bv-core-parent` | ✅ Complete | Parent POM — controls plugins |
| `bv-core-common` | ✅ Complete | Shared libs: auth, logging, security, events |
| `bv-auth-service` | ✅ Built & Tested | JWT auth, token refresh, account lockout |
| `bv-eCommerce-core/product-service` | ✅ Built | Spring Security + JWT integration |
| `bv-infra-service` | ✅ Complete | Pulumi IaC, cloud automation |
| `bv-observability` | ✅ Complete | OpenTelemetry, Prometheus, Grafana |
| `.github/` AI customizations | ✅ Complete | 9 agents, 4 instructions, 3 skills |

---

## 🔧 What's Left / In Progress

| Module | Status | Remaining Work |
|--------|--------|----------------|
| `bv-eCommerce-core/order-service` | 🔄 In Progress | Order state machine, Kafka events |
| `bv-eCommerce-core/inventory-service` | 🔄 In Progress | Reservation + release flow |
| `bv-eCommerce-core/payment-adapter-service` | ⏳ Not Started | Payment gateway integration |
| `bv-eCommerce-core/cart-service` | ⏳ Not Started | Cart + checkout flow |
| `bv-eCommerce-core/pricing-service` | ⏳ Not Started | Pricing rules, promotions |
| `bv-eCommerce-core/notification-service` | ⏳ Not Started | Email/SMS event-driven |
| `bv-chat-stream` | ⏳ Not Started | Real-time messaging, WebSocket |
| `bv-iot-control-hub` | ⏳ Not Started | IoT device management |
| `bv-social-pulse` | ⏳ Not Started | Social analytics |
| `bv-security-core` | ⏳ Not Started | Platform-wide security policies |
| `bv-performance-testing` | ⏳ Not Started | Gatling + k6 load tests |
| `bv-chaos-experiments` | ⏳ Not Started | Chaos Mesh experiments |
| `bv-security-testing` | ⏳ Not Started | OWASP ZAP scans |
| E2E test suite | ⏳ Not Started | Cucumber cross-service flows |

---

## 📂 Key References

| Resource | Location |
|----------|----------|
| AI Development Guide | `.github/bitvelocity-development.instructions.md` |
| Requirements Guide | `.github/bitvelocity-requirements.instructions.md` |
| Testing Guide | `.github/bitvelocity-testing.instructions.md` |
| Agent Definitions | `.github/bitvelocity-agents.md` |
| Skills | `.github/skills/SKILL-*.md` |
| Implementation Progress | `IMPLEMENTATION_STATUS.md` |
| Architecture Docs | `BitVelocity-Docs/docs/01-ARCHITECTURE/` |
| Security Architecture | `BitVelocity-Docs/docs/01-ARCHITECTURE/SECURITY_ARCHITECTURE.md` |
