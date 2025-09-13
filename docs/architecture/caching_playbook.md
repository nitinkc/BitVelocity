# Caching Playbook
Version: 1.0  
Status: Draft  

## 1. Goals
Improve latency, reduce primary DB load, and smooth traffic bursts while preserving correctness constraints per domain.

## 2. Cache Layers
| Layer | Tech | Latency Target | Scope |
|-------|------|---------------|-------|
| L1 (In-Process) | Caffeine | ~µs | Service-local hot keys |
| L2 (Distributed) | Redis | <1ms | Cross-instance sharing |
| Materialized Views | Kafka Streams / Redis | <5ms read | Derived read models |
| Edge (future) | CDN/Workers | <20ms global | Public read-only endpoints |

## 3. Patterns
| Pattern | Use Case | Pros | Cons |
|---------|----------|------|------|
| Cache Aside (read-through) | Product detail | Simple | Stale until invalidated |
| Write Through | Config/key-value central | Consistency | Higher write latency |
| Write Behind | Feed aggregation | Smooth writes | Eventual consistency |
| Refresh Ahead | Flash sale pricing | Low tail latency | Over-refresh risk |
| Negative Cache | Non-existent products | Stampede prevention | False negatives if inserted soon |
| Partial Object | Large product blob | Memory efficiency | Assembly overhead |
| Bloom Filter Guard | High 404 rate endpoints | Reduce DB hits | Probabilistic false positives |

## 4. Invalidation Strategies
| Trigger | Action |
|---------|-------|
| product.updated | Evict product:<id> |
| inventory.adjusted | Publish cache refresh event |
| price.changed | Refresh-ahead job kicks off |
| order.created | Add order ID to recent list for user |
| flash.sale.end | Bulk invalidate price:* pattern |

Avoid mass deletes—prefer key tagging (store a version token per entity group: `product:version`).

## 5. Key Naming Convention
```
product:<id>
inventory:sku:<skuId>
user:recentOrders:<userId>
feed:hot:<region>
neg:product:<id>
price:<productId>
```

## 6. TTL Guidelines
| Data | Suggested TTL | Rationale |
|------|---------------|-----------|
| Product detail | 300s + version bump | Low mutation frequency |
| Inventory snapshot | 5–15s | Higher volatility |
| Price (flash) | <= remaining sale window | Natural expiration |
| Recent orders list | 60s | User refreshes often |
| Negative product | 30–60s | Mitigate potential existence soon |

## 7. Metrics
- `cache_hits_total{layer}`
- `cache_misses_total{layer}`
- `cache_stale_served_total`
- `hot_key_frequency`
- `refresh_ahead_trigger_total`
- `negative_cache_hits_total`

Prometheus dashboards separate L1 vs L2 effectiveness.

## 8. Stampede Prevention
1. Use mutex (Redis SET NX) around regeneration.
2. Use jittered TTL (e.g. base TTL ± random(10%)).
3. Refresh ahead when TTL < threshold.

## 9. Consistency Trade-offs
| Domain | Requirement | Strategy |
|--------|-------------|----------|
| Orders list | Eventually consistent | Event projection updates asynchronously |
| Inventory numbers | Near real-time | Short TTL + event-driven updates |
| Product price | Consistency during flash | Write-through / versioning |
| Chat presence | Ephemeral | TTL + periodic heartbeats |

## 10. Implementation Snippet (Spring)
```java
public Product getProduct(String id) {
  return cache.get(id, k -> repository.findById(k)
      .orElseThrow(() -> new NotFoundException()));
}
```

Redis refresh-ahead pseudo:
```java
if (remainingTtl < refreshThreshold && lock.acquire(key)) {
   asyncRefresh(key);
}
```

## 11. Testing Strategy
- Unit: TTL logic boundaries.
- Integration: Simulate stampede (100 concurrent requests).
- Load: Track hit ratio growth over warmup.
- Chaos: Simulate Redis down → fallback and degrade gracefully.

## 12. Backlog Seeds
- Story: Implement product cache-aside with metrics.
- Story: Add negative caching for missing product.
- Story: Inventory refresh publish/subscribe.
- Story: Introduce refresh-ahead for flash pricing.
- Story: Add cache version token system.

## 13. Future Enhancements
- Multi-region cache invalidation bus (Kafka).
- CRDT-based eventually consistent counters.
- Edge caching using CDN for public product queries.

---