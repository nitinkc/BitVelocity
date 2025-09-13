# ADR-005: Security Layering Strategy

## Layers
Gateway (JWT/OAuth2, rate limits) → Service (Spring Security RBAC) → OPA (fine-grain) → mTLS mesh → Vault secrets.

## Evolution
JWT HS256 → RS256 via Vault → mTLS → dynamic DB creds → key rotation automation.

## Rationale
Progressive hardening aligned with learning milestones.