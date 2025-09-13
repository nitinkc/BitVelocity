# Cross-Cutting – Cost Optimization Strategy

## 1. Philosophy
Spend only when a concept requires real infra; default to local containers & ephemeral clusters.

## 2. Cost Levers
| Lever | Tactic |
|-------|--------|
| Runtime | Destroy non-active stacks (Pulumi TTL tags) |
| Storage | Compact logs, short retention early |
| Observability | Reduce scrape interval in dev |
| Messaging | Single broker until replication exercises |
| Search/Analytics | Delay OpenSearch/ClickHouse |
| Multi-Region | Activate only during drills |

## 3. Baseline Monthly (If Always On – Avoid)
| Stack | Est. Cost (USD) |
|-------|-----------------|
| Single region dev cluster small | 20–40 |
| Add Kafka + Postgres managed | +40–60 |
| Multi-region active | +80–120 |
| Full analytics + search | +100–150 |

## 4. Recommended Practice
| Phase | Practice |
|-------|---------|
| 1–4 | Local only (kind + Docker compose) |
| 5–7 | Short GCP windows (<6h/week) |
| 8–10 | Add AWS migration windows (destroy same day) |
| 11–12 | Performance runs scheduled + immediate teardown |

## 5. Automation
Scripts:
- cost-report.sh (list active infra + hourly burn estimate)
- prune-old-stacks.sh (Pulumi stack TTL check)
- toggle-feature-flags.sh (disable costly domains)

## 6. Cost KPIs
- % time cloud cluster active vs planned window
- Unused resource count after teardown (should trend to zero)
- Average monthly spend vs budget threshold

## 7. Exit Criteria
- Infra reproducible on demand, not persistent
- Budget tracked sprintly
- No orphaned resources after destroy script run
