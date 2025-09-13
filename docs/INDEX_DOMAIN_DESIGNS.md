# BitVelocity – Domain & Cross-Cutting Architecture Index (Granular Set)

This index points to modular design documents so you can focus on one domain at a time while ensuring seamless interoperability later.

## Domain Architecture Files
1. `DOMAIN_ECOMMERCE_ARCHITECTURE.md`
2. `DOMAIN_CHAT_ARCHITECTURE.md`
3. `DOMAIN_IOT_ARCHITECTURE.md`
4. `DOMAIN_SOCIAL_ARCHITECTURE.md`
5. `DOMAIN_ML_AI_ARCHITECTURE.md` (enabler, optional early)
6. `DOMAIN_SECURITY_PLATFORM.md` (Auth / Policy / Keys)

## Cross-Cutting & Shared
1. `CROSS_DATA_PLATFORM_AND_ANALYTICS.md`
2. `CROSS_EVENT_CONTRACTS_AND_VERSIONING.md`
3. `CROSS_OBSERVABILITY_AND_TESTING.md`
4. `CROSS_INFRA_PORTABILITY_AND_DEPLOYMENT.md`
5. `CROSS_EXECUTION_BACKLOG_AND_SPRINT_PLAN.md`
6. `CROSS_REPLAY_DR_DRILLS.md`
7. `CROSS_COST_OPTIMIZATION.md`

## Usage Guidance
- Each domain repo includes only its domain file + referenced slices from cross-cutting.
- Event contracts + shared libraries are your “constitution” – do not diverge locally.
- Start with E-Commerce (acts as backbone for most protocols), then Chat, then either IoT or Social depending on interest, then ML/AI integration, finally deeper security & DR.

## Layered Dependency Contract (Do Not Violate)
Shared Libs ← (used by) All Domains  
Security Platform ← (used by) All Domains  
E-Commerce Events → consumed by others (but Order svc never imports Chat code etc.)  
Cross-cutting docs define invariants; domain docs must not redefine them.

Refer to each domain's Interoperability Checklist before implementing.
