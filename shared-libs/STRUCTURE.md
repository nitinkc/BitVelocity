# Shared Libraries Aggregate (Optional)

```
shared-libs/
  README.md
  pom.xml (aggregator)
  bv-platform-bom/
    pom.xml
  bv-core-common/
    src/main/java/... (ErrorModel, CorrelationFilter, BaseDTO)
  bv-event-core/
    src/main/java/... (Envelope, SerDe)
  bv-test-core/
    src/main/java/... (Testcontainers utils)
  bv-security-lib/
    src/main/java/... (JWT filter, KeyResolver)
```
