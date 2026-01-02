# Infrastructure Service Complete Guide - BitVelocity

> **Purpose**: A comprehensive, systematic guide to understanding Infrastructure as Code (IaC) implementation in BitVelocity using Pulumi, covering cloud abstraction, resource provisioning, policy-as-code, and deployment automation.

**Last Updated**: December 31, 2025  
**Version**: 1.0

---

## Table of Contents

1. [Introduction to Infrastructure as Code](#1-introduction-to-infrastructure-as-code)
2. [Pulumi Fundamentals](#2-pulumi-fundamentals)
3. [BitVelocity Infrastructure Architecture](#3-bitvelocity-infrastructure-architecture)
4. [Cloud Provider Abstraction](#4-cloud-provider-abstraction)
5. [Resource Modules](#5-resource-modules)
6. [Stack Management](#6-stack-management)
7. [Configuration and Secrets](#7-configuration-and-secrets)
8. [Policy as Code](#8-policy-as-code)
9. [Multi-Region Deployment](#9-multi-region-deployment)
10. [Observability Infrastructure](#10-observability-infrastructure)
11. [Cost Management](#11-cost-management)
12. [CI/CD Integration](#12-cicd-integration)
13. [Testing Infrastructure](#13-testing-infrastructure)
14. [Common Patterns](#14-common-patterns)
15. [Troubleshooting](#15-troubleshooting)
16. [Migration Strategies](#16-migration-strategies)

---

## 1. Introduction to Infrastructure as Code

### 1.1 What is IaC?
Declarative code defining infrastructure resources. Version-controlled, repeatable, testable. Alternative to manual console clicking or imperative scripts.

### 1.2 IaC Benefits
- **Repeatability**: Same config → same infrastructure
- **Version control**: Git history for infra changes
- **Automation**: CI/CD deploys infrastructure
- **Documentation**: Code is documentation
- **Collaboration**: Code reviews for infra changes

### 1.3 Declarative vs Imperative
- **Declarative** (Pulumi, Terraform): Define desired state, tool figures out how
- **Imperative** (Shell scripts): Explicit commands (create, update, delete)

BitVelocity uses declarative (Pulumi) for consistency.

### 1.4 Why Pulumi over Terraform?
- **Real programming languages**: Java (type safety, IDE support, refactoring)
- **No HCL learning**: Leverage existing Java knowledge
- **Better testing**: Unit tests with familiar frameworks
- **Dynamic logic**: Loops, conditionals, functions without weird syntax
- **Cloud-agnostic**: Same abstraction across AWS, GCP, Azure

### 1.5 BitVelocity IaC Goals
- Cloud portability (local → GCP → AWS → Azure)
- Zero cloud costs in development (local provider)
- Modular architecture (networking, k8s, database, messaging)
- Policy enforcement (no public load balancers, encryption required)
- Multi-region capability (east/west regions)

---

## 2. Pulumi Fundamentals

### 2.1 Core Concepts
- **Project**: Root folder with `Pulumi.yaml`
- **Stack**: Isolated instance of project (dev, staging, prod)
- **Resources**: Cloud entities (VM, database, network)
- **Outputs**: Exported values (endpoints, IDs)
- **State**: Current infrastructure snapshot (stored in backend)

### 2.2 Pulumi CLI Commands
```bash
pulumi new <template>      # Create new project
pulumi stack init <name>   # Create new stack
pulumi config set <key> <value>  # Set config
pulumi preview            # Show planned changes
pulumi up                 # Apply changes
pulumi destroy            # Delete all resources
pulumi stack output       # View outputs
pulumi refresh            # Sync state with actual cloud
```

### 2.3 Pulumi State Management
State tracks deployed resources. Backends:
- **Local**: File in `.pulumi/` (dev only)
- **Pulumi Service**: SaaS backend (default, free tier)
- **Self-hosted**: S3, Azure Blob, GCS
- **Passphrase**: Encrypts local state

BitVelocity uses Pulumi Service for team collaboration.

### 2.4 Pulumi Program Structure
```java
public class AppStack {
    public static void main(String[] args) {
        Pulumi.run(ctx -> {
            // Read config
            var config = ctx.config();
            
            // Create resources
            var vpc = new Network("my-vpc", NetworkArgs.builder()
                .cidrBlock("10.0.0.0/16")
                .build());
            
            // Export outputs
            ctx.export("vpcId", vpc.id());
        });
    }
}
```

### 2.5 Resource Dependencies
Pulumi automatically tracks dependencies via `Output<T>`:
```java
var vpc = new Vpc("vpc", ...);
var subnet = new Subnet("subnet", SubnetArgs.builder()
    .vpcId(vpc.id()) // Dependency: subnet needs vpc first
    .build());
```

### 2.6 Outputs and Apply
`Output<T>` represents future value (async resolution):
```java
Output<String> vpcId = vpc.id();

// Transform output
Output<String> message = vpcId.apply(id -> "VPC ID: " + id);

// Export
ctx.export("vpcId", vpcId);
```

### 2.7 Stack References
Access outputs from other stacks:
```java
var infraStack = new StackReference("org/infra-project/prod");
Output<String> vpcId = infraStack.getOutput("vpcId");
```

BitVelocity: App services reference infra stack for endpoints.

---

## 3. BitVelocity Infrastructure Architecture

### 3.1 Module Structure
```
bv-infra-service/
├── Pulumi.yaml              # Project definition
├── Pulumi.dev.yaml          # Dev stack config
├── build.gradle             # Java build
├── src/main/java/
│   └── io/bitvelocity/infra/
│       ├── AppStack.java    # Entry point
│       ├── config/
│       │   └── ConfigKeys.java
│       ├── core/
│       │   ├── CloudProvider.java      # Provider interface
│       │   └── model/                  # Data models
│       ├── providers/
│       │   ├── local/LocalCloudProvider.java
│       │   └── gcp/GcpCloudProvider.java
│       └── modules/
│           ├── networking/NetworkingModule.java
│           ├── kubernetes/KubernetesModule.java
│           ├── database/DatabaseModule.java
│           ├── messaging/MessagingModule.java
│           ├── cache/CacheModule.java
│           └── secrets/SecretsModule.java
```

### 3.2 Architecture Layers
```
┌─────────────────────────────────────┐
│        AppStack (Main)              │  ← Orchestrator
├─────────────────────────────────────┤
│  Modules (Networking, K8s, DB...)  │  ← Logical grouping
├─────────────────────────────────────┤
│    CloudProvider Interface          │  ← Abstraction
├─────────────────────────────────────┤
│  Provider Implementations           │  ← Local/GCP/AWS/Azure
│  (LocalProvider, GcpProvider...)    │
└─────────────────────────────────────┘
```

### 3.3 Exported Outputs
Applications consume these:
```yaml
K8S_CLUSTER_NAME: local-kind-cluster
POSTGRES_ORDERS_RW_ENDPOINT: localhost:5432/orders
KAFKA_BROKERS_EAST: localhost:9092
REDIS_CACHE_HOST: localhost:6379
VAULT_ADDR: http://localhost:8200
```

### 3.4 Multi-Stack Strategy
- **dev**: Local provider, no cloud costs
- **staging**: GCP, single region
- **prod-east**: GCP, us-east1
- **prod-west**: GCP, us-west1 (read replicas, disaster recovery)

### 3.5 Configuration Hierarchy
```
1. Pulumi.<stack>.yaml    (stack-specific: dev, staging, prod)
2. Environment variables  (secrets: API keys, passwords)
3. Defaults in code       (fallbacks)
```

### 3.6 Design Principles
- **Cloud portability**: Switch providers via config
- **Cost awareness**: Local provider for dev
- **Modularity**: Each module independently testable
- **Immutable infrastructure**: Replace, don't modify
- **GitOps**: All changes via pull requests

---

## 4. Cloud Provider Abstraction

### 4.1 CloudProvider Interface
```java
public interface CloudProvider {
    K8sCluster createKubernetesCluster(String name, String region);
    Database createPostgres(String name, String region, String mode);
    Messaging createKafka(String name, String region, boolean replication);
    Cache createRedis(String name, String region);
    SecretStore createSecrets(String name);
}
```

### 4.2 Local Provider (Development)
No cloud API calls. Returns placeholder outputs:
```java
@Override
public Database createPostgres(String name, String region, String mode) {
    return new Database(
        Output.of("localhost:5432/" + name),
        Output.of("localhost:5432/" + name + "-ro"),
        Output.of("postgres")
    );
}
```
Perfect for CI, unit tests, rapid iteration.

### 4.3 GCP Provider (Production)
Real resource provisioning:
```java
@Override
public Database createPostgres(String name, String region, String mode) {
    var instance = new DatabaseInstance(name, DatabaseInstanceArgs.builder()
        .databaseVersion("POSTGRES_15")
        .region(region)
        .settings(DatabaseInstanceSettingsArgs.builder()
            .tier("db-g1-small")
            .backupConfiguration(...)
            .build())
        .build());
    
    return new Database(
        instance.connectionName().apply(cn -> cn + "/" + name),
        // ... read replica endpoint
        instance.name()
    );
}
```

### 4.4 Provider Selection
```java
CloudProvider provider = switch (providerName.toLowerCase()) {
    case "local" -> new LocalCloudProvider();
    case "gcp" -> new GcpCloudProvider();
    case "aws" -> new AwsCloudProvider();
    case "azure" -> new AzureCloudProvider();
    default -> new LocalCloudProvider();
};
```

### 4.5 Provider-Specific Configuration
```yaml
# Pulumi.gcp-prod.yaml
cloudProvider: gcp
gcp:
  project: bitvelocity-prod
  region: us-east1
  network: projects/bitvelocity-prod/global/networks/default
```

### 4.6 Benefits of Abstraction
- Test locally before cloud deployment
- Swap providers without changing app code
- Gradual migration (local → GCP → multi-cloud)
- Cost control (dev doesn't provision expensive resources)

---

## 5. Resource Modules

### 5.1 Networking Module
Creates VPC, subnets, firewall rules:
```java
public class NetworkingModule {
    public NetworkingModule(String regionEast, String regionWest) {
        // For local: no-op
        // For cloud: provision VPC, subnets, NAT gateway
        log.info("Networking configured for regions: {}, {}", regionEast, regionWest);
    }
}
```

**Cloud implementation**:
```java
var vpc = new Network("bitvelocity-vpc", NetworkArgs.builder()
    .autoCreateSubnetworks(false)
    .build());

var subnetEast = new Subnetwork("subnet-east", SubnetworkArgs.builder()
    .network(vpc.id())
    .ipCidrRange("10.1.0.0/24")
    .region(regionEast)
    .build());
```

### 5.2 Kubernetes Module
Provisions K8s cluster:
```java
public class KubernetesModule {
    private K8sCluster cluster;
    
    public KubernetesModule(CloudProvider provider, String region) {
        this.cluster = provider.createKubernetesCluster("main", region);
    }
    
    public K8sCluster cluster() { return cluster; }
}
```

**GCP (GKE)**:
```java
var cluster = new Cluster("gke-cluster", ClusterArgs.builder()
    .location(region)
    .initialNodeCount(3)
    .nodeConfig(NodeConfigArgs.builder()
        .machineType("e2-medium")
        .oauthScopes("https://www.googleapis.com/auth/cloud-platform")
        .build())
    .build());
```

### 5.3 Database Module
Postgres instances:
```java
public class DatabaseModule {
    private Database ordersDb;
    
    public DatabaseModule(CloudProvider provider, String region, String mode) {
        this.ordersDb = provider.createPostgres("orders", region, mode);
    }
    
    public Database ordersDb() { return ordersDb; }
}
```

**Modes**:
- `primary`: Read-write master
- `replica`: Read-only follower
- `readreplica`: Cross-region read replica

### 5.4 Messaging Module
Kafka clusters:
```java
public class MessagingModule {
    private Messaging messaging;
    
    public MessagingModule(CloudProvider provider, String region, boolean replication) {
        this.messaging = provider.createKafka("events", region, replication);
    }
    
    public Messaging messaging() { return messaging; }
}
```

**Replication**: Cross-region Kafka mirroring for DR.

### 5.5 Cache Module
Redis instances:
```java
public class CacheModule {
    private Cache cache;
    
    public CacheModule(CloudProvider provider, String region) {
        this.cache = provider.createRedis("cache", region);
    }
    
    public Cache cache() { return cache; }
}
```

**GCP (Memorystore)**:
```java
var redis = new Instance("redis", InstanceArgs.builder()
    .tier("BASIC")
    .memorySizeGb(1)
    .region(region)
    .build());
```

### 5.6 Secrets Module
Secret management (Vault, cloud secret managers):
```java
public class SecretsModule {
    private SecretStore secretStore;
    
    public SecretsModule(CloudProvider provider) {
        this.secretStore = provider.createSecrets("vault");
    }
    
    public SecretStore secretStore() { return secretStore; }
}
```

### 5.7 Module Dependencies
Order matters:
```
1. Networking (VPC, subnets)
2. Kubernetes (needs VPC)
3. Database (needs VPC)
4. Messaging (needs VPC)
5. Cache (needs VPC)
6. Secrets (independent)
```

Pulumi resolves automatically via `Output<T>` dependencies.

---

## 6. Stack Management

### 6.1 Creating Stacks
```bash
pulumi stack init dev
pulumi stack init staging
pulumi stack init prod-east
pulumi stack init prod-west
```

### 6.2 Stack Configuration Files
```yaml
# Pulumi.dev.yaml
config:
  cloudProvider: local
  regionEast: us-east1
  regionWest: us-west1
  db.orders.mode: primary
  replication.kafka.enabled: false
```

```yaml
# Pulumi.prod-east.yaml
config:
  cloudProvider: gcp
  gcp:project: bitvelocity-prod
  regionEast: us-east1
  db.orders.mode: primary
  replication.kafka.enabled: true
```

### 6.3 Switching Stacks
```bash
pulumi stack select dev
pulumi up

pulumi stack select prod-east
pulumi up
```

### 6.4 Stack Outputs
```bash
# View all outputs
pulumi stack output --json

# Specific output
pulumi stack output POSTGRES_ORDERS_RW_ENDPOINT
```

### 6.5 Stack Tagging
```bash
pulumi stack tag set environment production
pulumi stack tag set region us-east1
pulumi stack tag set cost-center engineering
```

### 6.6 Stack Import/Export
```bash
# Backup state
pulumi stack export > backup.json

# Restore state
pulumi stack import < backup.json
```

---

## 7. Configuration and Secrets

### 7.1 Config Keys (ConfigKeys.java)
```java
public class ConfigKeys {
    public static final String CLOUD_PROVIDER = "cloudProvider";
    public static final String REGION_EAST = "regionEast";
    public static final String REGION_WEST = "regionWest";
    public static final String DB_ORDERS_MODE = "db.orders.mode";
    public static final String KAFKA_REPLICATION = "replication.kafka.enabled";
}
```

### 7.2 Reading Configuration
```java
var config = ctx.config();
String provider = config.get(ConfigKeys.CLOUD_PROVIDER).orElse("local");
boolean kafkaReplication = config.getBoolean(ConfigKeys.KAFKA_REPLICATION).orElse(false);
```

### 7.3 Secrets Management
```bash
# Set secret (encrypted in state)
pulumi config set --secret dbPassword P@ssw0rd123

# Read secret in code
config.requireSecret("dbPassword")
```

### 7.4 Environment Variables
```bash
export PULUMI_CONFIG_PASSPHRASE=your-passphrase
export GCP_PROJECT=bitvelocity-prod
```

### 7.5 Secret Rotation
```bash
# Update secret
pulumi config set --secret dbPassword NewP@ssw0rd456

# Apply change
pulumi up  # Updates resources using secret
```

### 7.6 External Secrets (Vault)
```java
var vaultSecret = new Secret("db-password", SecretArgs.builder()
    .secretId("projects/bitvelocity/secrets/db-password")
    .build());

var password = vaultSecret.data();
```

---

## 8. Policy as Code

### 8.1 What is Policy as Code?
Enforce compliance rules before deployment. Reject non-compliant stacks.

### 8.2 Pulumi CrossGuard
```typescript
// policies/no-public-lb.ts
import * as policy from "@pulumi/policy";

new policy.PolicyPack("bitvelocity-policies", {
    policies: [{
        name: "no-public-load-balancers",
        description: "Load balancers must not be publicly accessible",
        enforcementLevel: "mandatory",
        validateResource: (args, reportViolation) => {
            if (args.type === "gcp:compute/globalForwardingRule:GlobalForwardingRule") {
                if (args.props.loadBalancingScheme === "EXTERNAL") {
                    reportViolation("Public load balancers are not allowed");
                }
            }
        },
    }],
});
```

### 8.3 Policy Enforcement
```bash
# Enable policy pack
pulumi policy enable policies/no-public-lb.ts

# Violations prevent deployment
pulumi up
# ❌ Policy violation: Public load balancers are not allowed
```

### 8.4 Common Policies
- No public load balancers
- Encryption at rest required
- VMs must use specific machine types
- No hardcoded secrets
- Resources must have tags (cost center, owner)

### 8.5 OPA Integration (Alternative)
Open Policy Agent for complex rules:
```rego
package bitvelocity.policies

deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "google_compute_instance"
    not resource.change.after.labels["cost-center"]
    msg := "VM must have cost-center label"
}
```

### 8.6 Policy Testing
Unit test policies before enforcing:
```typescript
it("rejects public load balancers", () => {
    const result = validateResource({
        type: "gcp:compute/globalForwardingRule:GlobalForwardingRule",
        props: { loadBalancingScheme: "EXTERNAL" }
    });
    expect(result.violations).toHaveLength(1);
});
```

---

## 9. Multi-Region Deployment

### 9.1 Active-Active Architecture
```
┌──────────────┐         ┌──────────────┐
│  US-EAST-1   │ ←──────→│  US-WEST-1   │
│  (Primary)   │  Replicate │  (Primary)   │
├──────────────┤         ├──────────────┤
│ GKE Cluster  │         │ GKE Cluster  │
│ Postgres RW  │         │ Postgres RW  │
│ Kafka        │         │ Kafka        │
│ Redis        │         │ Redis        │
└──────────────┘         └──────────────┘
       ↑                        ↑
       └────── Global LB ───────┘
```

### 9.2 Active-Passive (DR)
```
┌──────────────┐         ┌──────────────┐
│  US-EAST-1   │ ────────→│  US-WEST-1   │
│  (Active)    │  Async   │  (Standby)   │
│              │  Replicate│              │
├──────────────┤         ├──────────────┤
│ All traffic  │         │ Read replicas│
│ Writes here  │         │ Failover ready│
└──────────────┘         └──────────────┘
```

BitVelocity uses active-passive (cost-effective).

### 9.3 Cross-Region Configuration
```yaml
# Pulumi.prod-east.yaml
config:
  region: us-east1
  db.orders.mode: primary
  replication.target: us-west1
  
# Pulumi.prod-west.yaml
config:
  region: us-west1
  db.orders.mode: readreplica
  replication.source: us-east1
```

### 9.4 Database Replication
```java
if (mode.equals("primary")) {
    // Master database
    var db = new DatabaseInstance(name, ...);
} else if (mode.equals("readreplica")) {
    // Read replica pointing to primary
    var replica = new DatabaseInstance(name, DatabaseInstanceArgs.builder()
        .masterInstanceName(primaryDbName)
        .replicaConfiguration(...)
        .build());
}
```

### 9.5 Kafka Cross-Region Mirroring
```java
if (replicationEnabled) {
    var mirrorMaker = new KafkaMirrorMaker("mirror", MirrorMakerArgs.builder()
        .sourceCluster(eastKafka.brokers())
        .targetCluster(westKafka.brokers())
        .topics(List.of("orders.*", "products.*"))
        .build());
}
```

### 9.6 Failover Strategy
1. Health check detects primary region down
2. DNS/Load balancer switches traffic to secondary
3. Promote read replica to primary (manual or automated)
4. Applications reconnect to new primary

---

## 10. Observability Infrastructure

### 10.1 Observability Stack
```
Prometheus (metrics) → Grafana (dashboards)
Jaeger (traces)      → Grafana (visualization)
Loki (logs)          → Grafana (log aggregation)
OpenTelemetry        → All of above
```

### 10.2 Prometheus Deployment
```java
var prometheus = new Deployment("prometheus", DeploymentArgs.builder()
    .spec(DeploymentSpecArgs.builder()
        .selector(LabelSelectorArgs.builder()
            .matchLabels(Map.of("app", "prometheus"))
            .build())
        .template(PodTemplateSpecArgs.builder()
            .spec(PodSpecArgs.builder()
                .containers(ContainerArgs.builder()
                    .name("prometheus")
                    .image("prom/prometheus:latest")
                    .ports(ContainerPortArgs.builder().containerPort(9090).build())
                    .build())
                .build())
            .build())
        .build())
    .build());
```

### 10.3 Grafana Configuration
```java
var grafana = new Deployment("grafana", ...);
var grafanaService = new Service("grafana", ServiceArgs.builder()
    .spec(ServiceSpecArgs.builder()
        .type("LoadBalancer")
        .ports(ServicePortArgs.builder()
            .port(3000)
            .targetPort(3000)
            .build())
        .selector(Map.of("app", "grafana"))
        .build())
    .build());

ctx.export("GRAFANA_URL", grafanaService.status()
    .apply(s -> s.loadBalancer().ingress().get(0).ip() + ":3000"));
```

### 10.4 OpenTelemetry Collector
```yaml
receivers:
  otlp:
    protocols:
      grpc:
      http:
processors:
  batch:
exporters:
  prometheus:
    endpoint: "prometheus:9090"
  jaeger:
    endpoint: "jaeger:14250"
```

### 10.5 Log Aggregation (Loki)
```java
var loki = new StatefulSet("loki", StatefulSetArgs.builder()
    .spec(StatefulSetSpecArgs.builder()
        .serviceName("loki")
        .replicas(1)
        .volumeClaimTemplates(PersistentVolumeClaimArgs.builder()
            .spec(PersistentVolumeClaimSpecArgs.builder()
                .accessModes("ReadWriteOnce")
                .resources(ResourceRequirementsArgs.builder()
                    .requests(Map.of("storage", "10Gi"))
                    .build())
                .build())
            .build())
        .build())
    .build());
```

### 10.6 Alerting Rules
```yaml
groups:
  - name: bitvelocity
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
        for: 5m
        annotations:
          summary: "High error rate detected"
```

---

## 11. Cost Management

### 11.1 Local Provider (Zero Cost)
```java
// Local provider returns placeholders, no cloud API calls
var db = new Database(
    Output.of("localhost:5432/orders"),
    Output.of("localhost:5432/orders-ro"),
    Output.of("postgres")
);
```
Perfect for CI, dev environments.

### 11.2 Right-Sizing Resources
```java
// Dev: Small instances
var dbTier = env.equals("dev") ? "db-f1-micro" : "db-n1-standard-2";

var db = new DatabaseInstance("db", DatabaseInstanceArgs.builder()
    .settings(DatabaseInstanceSettingsArgs.builder()
        .tier(dbTier)
        .build())
    .build());
```

### 11.3 Auto-Scaling
```java
var nodePool = new NodePool("pool", NodePoolArgs.builder()
    .autoscaling(NodePoolAutoscalingArgs.builder()
        .minNodeCount(1)
        .maxNodeCount(10)
        .build())
    .build());
```

### 11.4 Spot/Preemptible Instances
```java
var nodeConfig = NodeConfigArgs.builder()
    .preemptible(true) // 80% cheaper, can be terminated
    .machineType("e2-medium")
    .build();
```

### 11.5 Resource Tagging for Cost Attribution
```java
var vm = new Instance("vm", InstanceArgs.builder()
    .labels(Map.of(
        "cost-center", "engineering",
        "project", "bitvelocity",
        "environment", "staging"
    ))
    .build());
```

### 11.6 Scheduled Shutdown (Non-Prod)
```bash
# Cron job to destroy staging stack nightly
0 22 * * * cd /infra && pulumi destroy --stack staging --yes
0 8 * * * cd /infra && pulumi up --stack staging --yes
```

### 11.7 Budget Alerts
```java
var budget = new Budget("bitvelocity-budget", BudgetArgs.builder()
    .amount(BudgetAmountArgs.builder()
        .specifiedAmount(BudgetAmountSpecifiedAmountArgs.builder()
            .currencyCode("USD")
            .units("500")
            .build())
        .build())
    .thresholdRules(BudgetThresholdRuleArgs.builder()
        .thresholdPercent(0.8) // Alert at 80%
        .build())
    .build());
```

---

## 12. CI/CD Integration

### 12.1 GitHub Actions Workflow
```yaml
name: Deploy Infrastructure

on:
  push:
    branches: [main]
    paths: ['bv-infra-service/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Java
        uses: actions/setup-java@v3
        with:
          java-version: '21'
      
      - name: Setup Pulumi
        uses: pulumi/setup-pulumi@v2
      
      - name: Install dependencies
        run: ./gradlew build
        working-directory: bv-infra-service
      
      - name: Preview changes
        run: pulumi preview --stack prod-east
        working-directory: bv-infra-service
        env:
          PULUMI_ACCESS_TOKEN: ${{ secrets.PULUMI_ACCESS_TOKEN }}
      
      - name: Deploy
        run: pulumi up --yes --stack prod-east
        working-directory: bv-infra-service
        env:
          PULUMI_ACCESS_TOKEN: ${{ secrets.PULUMI_ACCESS_TOKEN }}
```

### 12.2 Pull Request Preview
```yaml
on:
  pull_request:
    paths: ['bv-infra-service/**']

jobs:
  preview:
    steps:
      - name: Pulumi Preview
        run: pulumi preview --stack dev
      
      - name: Comment PR
        uses: actions/github-script@v6
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              body: 'Pulumi preview:\n```\n' + previewOutput + '\n```'
            })
```

### 12.3 Ephemeral Environments
```bash
# Create temporary stack for feature branch
pulumi stack init feature-${{ github.head_ref }}
pulumi config set cloudProvider local
pulumi up --yes

# Test...

# Cleanup
pulumi destroy --yes
pulumi stack rm feature-${{ github.head_ref }} --yes
```

### 12.4 GitOps with FluxCD
```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta1
kind: GitRepository
metadata:
  name: infra-repo
spec:
  url: https://github.com/bitvelocity/infra
  ref:
    branch: main

---
apiVersion: kustomize.toolkit.fluxcd.io/v1beta1
kind: Kustomization
metadata:
  name: infra
spec:
  sourceRef:
    kind: GitRepository
    name: infra-repo
  path: ./bv-infra-service
```

### 12.5 Approval Gates
```yaml
deploy-prod:
  needs: [test, security-scan]
  environment:
    name: production
    url: https://bitvelocity.com
  steps:
    - run: pulumi up --yes
  # Requires manual approval in GitHub
```

### 12.6 Rollback Strategy
```bash
# Export current state before deployment
pulumi stack export > backup-$(date +%Y%m%d-%H%M%S).json

# Deploy
pulumi up --yes

# If issues, rollback
pulumi stack import < backup-20251231-120000.json
pulumi up --yes
```

---

## 13. Testing Infrastructure

### 13.1 Unit Testing Providers
```java
@Test
void localProviderReturnsPlaceholderDatabase() {
    var provider = new LocalCloudProvider();
    var db = provider.createPostgres("test", "us-east1", "primary");
    
    // Outputs resolve immediately for local provider
    assertEquals("localhost:5432/test", db.rwEndpoint().apply(e -> e).join());
}
```

### 13.2 Integration Testing with Testcontainers
```java
@Test
void postgresModuleCreatesDatabase() {
    var postgres = new PostgreSQLContainer<>("postgres:15");
    postgres.start();
    
    var provider = new TestCloudProvider(postgres.getJdbcUrl());
    var module = new DatabaseModule(provider, "us-east1", "primary");
    
    // Verify database accessible
    try (var conn = DriverManager.getConnection(module.ordersDb().rwEndpoint().join())) {
        assertTrue(conn.isValid(5));
    }
}
```

### 13.3 Policy Testing
```typescript
import * as testing from "@pulumi/policy/testing";

describe("no-public-lb", () => {
    it("rejects public load balancers", () => {
        const result = testing.validateResource({
            type: "gcp:compute/globalForwardingRule",
            props: { loadBalancingScheme: "EXTERNAL" }
        }, policies);
        
        expect(result.violations).toHaveLength(1);
    });
});
```

### 13.4 Smoke Testing Stacks
```bash
# Deploy to ephemeral stack
pulumi stack init test-$BUILD_ID
pulumi config set cloudProvider local
pulumi up --yes

# Run smoke tests
curl http://$(pulumi stack output KAFKA_BROKERS_EAST)

# Cleanup
pulumi destroy --yes
pulumi stack rm test-$BUILD_ID --yes
```

### 13.5 Chaos Engineering (Infra)
```bash
# Terminate random instances
gcloud compute instances delete $(pulumi stack output VM_NAMES | jq -r '.[0]') --zone us-east1-a

# Verify auto-healing
sleep 60
pulumi refresh  # Should show replacement instance
```

### 13.6 Cost Validation
```bash
# Estimate costs before deployment
pulumi preview --show-costs
# Expected cost increase: $150/month
```

---

## 14. Common Patterns

### 14.1 Component Resources
Encapsulate multiple resources:
```java
public class WebApp extends ComponentResource {
    public WebApp(String name, WebAppArgs args) {
        super("bitvelocity:WebApp", name, args);
        
        var bucket = new Bucket(name + "-static", ...);
        var cdn = new CDN(name + "-cdn", CdnArgs.builder()
            .origin(bucket.url())
            .build());
        var loadBalancer = new LoadBalancer(name + "-lb", ...);
        
        this.registerOutputs(Map.of(
            "url", cdn.url(),
            "bucket", bucket.name()
        ));
    }
}
```

### 14.2 Dynamic Providers
Generate resources from external data:
```java
var topics = fetchTopicsFromConfig();
for (String topic : topics) {
    new Topic(topic, TopicArgs.builder()
        .name(topic)
        .partitions(3)
        .build());
}
```

### 14.3 Resource Transformations
Modify all resources of type:
```java
Pulumi.run(ctx -> {
    ctx.registerStackTransformation(args -> {
        if (args.type.startsWith("gcp:compute/instance")) {
            args.props.put("labels", Map.of("managed-by", "pulumi"));
        }
        return args;
    });
});
```

### 14.4 Naming Conventions
```java
public class Naming {
    public static String resource(String type, String purpose) {
        String env = System.getenv("ENVIRONMENT");
        String region = System.getenv("REGION");
        return String.format("bv-%s-%s-%s-%s", env, region, type, purpose);
        // bv-prod-useast1-db-orders
    }
}
```

### 14.5 Conditional Resources
```java
if (env.equals("prod")) {
    // Production-only resources
    new DatabaseReplica("orders-replica", ...);
    new BackupPolicy("daily-backups", ...);
}
```

### 14.6 Output Composition
```java
Output<String> connectionString = Output.tuple(db.host(), db.port())
    .apply(tuple -> String.format("%s:%d", tuple.t1, tuple.t2));

ctx.export("DB_CONNECTION", connectionString);
```

---

## 15. Troubleshooting

### 15.1 State Conflicts
**Symptom**: `error: the current deployment has N resource(s) with pending operations`

**Fix**:
```bash
pulumi cancel  # Cancel pending operations
pulumi refresh # Sync state with cloud
pulumi up
```

### 15.2 Missing Resources
**Symptom**: Resource exists in cloud but not in state.

**Fix**:
```bash
pulumi import <type> <name> <id>
# Example
pulumi import gcp:compute/instance:Instance my-vm projects/my-proj/zones/us-east1-a/instances/my-vm
```

### 15.3 Dependency Errors
**Symptom**: `error: resource X depends on Y which is being deleted`

**Fix**: Order matters. Delete dependent resources first:
```java
// WRONG: Delete VPC before subnets
vpc.delete();
subnet.delete();

// RIGHT: Delete subnets before VPC
subnet.delete();
vpc.delete();
```

### 15.4 Secret Decryption Errors
**Symptom**: `error: failed to decrypt`

**Fix**: Set correct passphrase:
```bash
export PULUMI_CONFIG_PASSPHRASE=your-passphrase
pulumi stack select dev
```

### 15.5 Provider Authentication
**Symptom**: `error: google: could not find default credentials`

**Fix**:
```bash
gcloud auth application-default login
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json
```

### 15.6 Debugging Pulumi Programs
```java
// Enable verbose logging
System.setProperty("pulumi.log.level", "debug");

// Log intermediate values
vpcId.apply(id -> {
    System.out.println("VPC ID: " + id);
    return id;
});
```

### 15.7 State Recovery
```bash
# Export state to file
pulumi stack export > backup.json

# Edit manually if needed (advanced!)
vi backup.json

# Import corrected state
pulumi stack import < backup.json
```

### 15.8 Resource Leaks
**Symptom**: Cloud resources exist but not tracked by Pulumi.

**Prevention**:
```bash
# Always use pulumi destroy (not manual deletion)
pulumi destroy --yes

# Audit orphaned resources
gcloud compute instances list --filter="labels.managed-by!=pulumi"
```

---

## 16. Migration Strategies

### 16.1 Import Existing Resources
```bash
# Discover existing infrastructure
gcloud compute instances list --format="value(name,zone)"

# Import into Pulumi
pulumi import gcp:compute/instance:Instance prod-vm-1 \
    projects/my-proj/zones/us-east1-a/instances/prod-vm-1
```

### 16.2 Terraform to Pulumi
```bash
# Convert Terraform code
pulumi convert --from terraform --language java

# Review generated code
# Manually refactor for idiomatic Java
```

### 16.3 Gradual Migration
```
Phase 1: Import existing resources (no changes)
Phase 2: Refactor to modules
Phase 3: Add policy enforcement
Phase 4: Migrate to multi-region
```

### 16.4 Blue-Green Deployment
```bash
# Create new stack
pulumi stack init prod-green
pulumi config cp prod-blue prod-green
pulumi up --yes

# Switch traffic
# Update DNS/load balancer

# Destroy old stack
pulumi stack select prod-blue
pulumi destroy --yes
```

### 16.5 Provider Migration (GCP → AWS)
```java
// 1. Implement AwsCloudProvider
// 2. Create new stack with AWS provider
pulumi stack init prod-aws
pulumi config set cloudProvider aws

// 3. Deploy to AWS
pulumi up --yes

// 4. Migrate data
// 5. Switch traffic
// 6. Decommission GCP
```

### 16.6 Risk Mitigation
- Test in dev/staging first
- Export state before changes
- Use preview extensively
- Gradual rollout (region by region)
- Keep old infrastructure running during migration

---

## Appendices

### Appendix A: Pulumi Resources Reference
- `pulumi.Config` - Configuration management
- `pulumi.Output<T>` - Async value wrapper
- `pulumi.StackReference` - Cross-stack dependencies
- `pulumi.ComponentResource` - Composite resources
- `pulumi.ResourceOptions` - Dependencies, providers, etc.

### Appendix B: Configuration Properties
```yaml
# Core
cloudProvider: local | gcp | aws | azure
environment: dev | staging | prod
regionEast: us-east1
regionWest: us-west1

# Database
db.orders.mode: primary | replica | readreplica
db.tier: db-f1-micro | db-n1-standard-2

# Messaging
replication.kafka.enabled: true | false
kafka.partitions: 3
kafka.replicationFactor: 3

# Kubernetes
k8s.nodeCount: 3
k8s.machineType: e2-medium
k8s.autoscaling: true

# Cost
budget.monthly: 500
```

### Appendix C: Naming Conventions
```
Pattern: bv-<env>-<region>-<type>-<purpose>

Examples:
- bv-prod-useast1-db-orders
- bv-staging-uswest1-k8s-cluster
- bv-dev-local-kafka-events
```

### Appendix D: Pulumi Scripts
```bash
# scripts/pulumi-up.sh
#!/bin/bash
set -e
./gradlew build
pulumi preview --stack "$1"
read -p "Apply changes? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    pulumi up --yes --stack "$1"
fi
```

### Appendix E: Cost Estimation
| Resource | Type | Monthly Cost |
|----------|------|--------------|
| GKE Cluster | 3 e2-medium nodes | $73 |
| Cloud SQL | db-n1-standard-2 | $94 |
| Memorystore | 1GB Redis | $35 |
| Cloud Storage | 100GB | $2 |
| Load Balancer | - | $18 |
| **Total** | | **~$222/month** |

### Appendix F: Further Reading
- [Pulumi Java Docs](https://www.pulumi.com/docs/intro/languages/java/)
- [Infrastructure as Code Book](https://www.oreilly.com/library/view/infrastructure-as-code/9781098114664/)
- [GCP Architecture Framework](https://cloud.google.com/architecture/framework)
- [AWS Well-Architected](https://aws.amazon.com/architecture/well-architected/)

### Appendix G: BitVelocity ADRs
- ADR-002: Multi-repo vs mono-repo strategy
- ADR-003: Cloud provider selection (GCP first)
- ADR-010: Infrastructure as code (Pulumi over Terraform)
- ADR-011: Multi-region deployment strategy

---

**Document Complete** ✅

Comprehensive infrastructure guide covering Pulumi fundamentals, BitVelocity's cloud-portable architecture, resource provisioning, policy enforcement, multi-region deployment, and operational best practices. Ready for experienced engineers to implement and maintain infrastructure as code.
