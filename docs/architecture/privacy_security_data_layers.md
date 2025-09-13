# Privacy & Security – Data Layer Enforcement
Version: 1.0  
Status: Draft  

## 1. Objectives
Protect sensitive and personal data across transactional, analytical, and derived layers while enabling legitimate analytical and ML use.

## 2. Data Classification
| Level | Description | Examples | Protection |
|-------|-------------|----------|------------|
| Public | Non-sensitive | Product name | None |
| Internal | Operational, non-PII | Order status | AuthZ |
| Sensitive | Personal identifiers | Email, phone | Masking, encryption |
| Highly Sensitive | Payment tokens, secrets | payment_token | Strong encryption, restricted roles |

## 3. Controls Matrix
| Control | Layer | Tool |
|---------|-------|------|
| Column Encryption | OLTP | Vault transit |
| Row-Level Security | Postgres | RLS policies |
| Field Masking | Warehouse | SQL views / masking functions |
| Tokenization | Payment tokens | Vault / custom service |
| Access Auditing | All | Central log pipeline |
| Data Minimization | Events | Filter PII from payloads |
| Retention Policies | Raw telemetry | Partition drop |

## 4. Vault Transit Encryption
Encrypt on write (service side):
```java
String cipher = vaultTransit.encrypt("payments", plaintext);
```
Store cipher text in DB column. Decrypt only when necessary.

## 5. Row-Level Security (Orders)
Example:
```sql
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY order_owner_policy ON orders
USING (tenant_id = current_setting('app.tenant_id')::uuid);
```
App sets `SET app.tenant_id = '<tenant-uuid>'` after auth.

## 6. Masked Analytics Views
```sql
CREATE VIEW analytics.orders_masked AS
SELECT
  order_id,
  customer_id,
  total_amount,
  regexp_replace(email, '(.+)@(.+)', '***@\\2') AS email_masked,
  payment_token_hash
FROM orders;
```

## 7. Event Payload Hygiene
Do not emit:
- Raw email
- Full payment card token
Instead:
- `customerRef`
- `payment_token_hash`
Perform static analysis check for banned fields (CI script).

## 8. Data Retention
| Data | Retention | Action |
|------|-----------|--------|
| Raw order events | 180 days | Archive Parquet then purge |
| Telemetry raw | 7 days | Partition drop |
| Payment logs | 90 days | Redact after 30, purge after 90 |
| Access audit | 365 days | Cold storage compression |

## 9. Access Roles
| Role | Permissions |
|------|-------------|
| svc_order | RW orders only |
| svc_payment | RW payment_token (decrypt) |
| analyst_read | Read masked views only |
| ml_engineer | Read feature tables (no raw PII) |

## 10. Secrets Handling
- All DB credentials dynamic (Vault leases).
- Rotate every 24h (dev) or 7d (prod-like).
- Invalidation triggers redeploy or sidecar reload.

## 11. Monitoring & Alerts
Metrics:
- Decryption requests per interval
- RLS policy violation attempts
- Masking function usage
Alerts:
- Sudden spike decryption > threshold
- Access from unknown service account

## 12. Compliance Simulation
- Pseudo “Right to Erasure”: soft-delete + anonymize (replace identifying fields with null/hashed).
- Audit log events: `privacy.erasure.requested`, `privacy.erasure.completed`.

## 13. Tooling
| Function | Tool |
|----------|------|
| Secrets | Vault |
| Key Mgmt | Vault KMS or cloud KMS |
| Tokenization
