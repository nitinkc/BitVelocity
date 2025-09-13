# Domain Architecture – Security & Policy Platform

## 1. Purpose
Central identity, authorization, secrets, policy, and cryptographic services reused by all domains.

## 2. Services
| Service | Responsibility |
|---------|----------------|
| auth-service | JWT issuance (HS256 → RS256), OAuth2 provider integration |
| policy-service (OPA bundle mgmt) | Distribute & version Rego policies |
| key-management (Vault integration) | Key rotation, secret leasing |
| audit-service | Central audit event capture & query |
| token-introspection (optional) | Central validation alternative |

## 3. Protocols
| Use Case | Protocol |
|----------|----------|
| Token issuance | REST |
| Policy query (early) | HTTP/OPA API |
| Secret retrieval | Vault HTTP API |
| Audit ingestion | Kafka (audit.events.*) |

## 4. Data Model
Postgres:
- users(id, email_hash, roles, status, created_at)
- client_apps(id, name, secret_hash, scopes)
- audit_log(id, actor, action, resource, ts, meta)
Vault (later):
- dynamic DB creds
- transit keys: payment-token, signing-jwt

## 5. JWT Claims
```
{
  "sub":"user-123",
  "roles":["CUSTOMER"],
  "tenant":"default",
  "exp":...,
  "jti":"..."
}
```

## 6. Policy Distribution
- Rego bundles versioned: /bundles/{version}/
- Services poll or sidecar injection
- Example policy: restrict cancel after PAID

## 7. Security Metrics
- auth_token_issuances_total
- auth_failed_logins_total
- policy_denials_total
- key_rotation_age_seconds
- vault_secret_lease_renew_failures

## 8. Testing
| Layer | Focus |
|-------|-------|
| Unit | Token builder correctness |
| Integration | Vault secret retrieval simulation |
| Contract | Auth REST endpoints |
| Security | Negative tests (expired token) |
| Performance | Token issuance throughput |

## 9. Implementation Order
1. JWT issuance & validation library (shared)
2. Auth service REST endpoints (login/refresh)
3. OPA baseline policies + sidecar integration
4. Audit event producer (user login)
5. Vault dev integration (secret fetch)
6. Key rotation simulation
7. Policy version rollout test

## 10. Interoperability Checklist
- [ ] Shared libs published with semantic version
- [ ] Public JWK endpoint if RS256 used (/oauth/jwks)
- [ ] Policy decisions include traceId
- [ ] Services do not bypass central validation

## 11. Exit Criteria
- All other domains enforce JWT auth
- At least one OPA policy denies invalid mutation
- Vault secret retrieved and rotated in a sample service
