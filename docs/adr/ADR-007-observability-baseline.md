# ADR-007: Observability Baseline

## Decision
Adopt OpenTelemetry (traces), Prometheus (metrics), structured JSON logs (Loki/ELK). Correlation via traceId + correlationId across events.

## Metrics Governance
Service must expose: request latency histogram, error counter, domain metric(s).

## Tracing
Span for each external call; event spans carry eventType attribute.
