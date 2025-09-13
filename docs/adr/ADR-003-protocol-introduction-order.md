# ADR-003: Protocol Introduction Order

## Order
1. REST + Postgres
2. Kafka events
3. gRPC (inventory)
4. WebSocket (notifications)
5. GraphQL
6. SSE (feed / flash sale)
7. SOAP (payment)
8. Webhooks + RabbitMQ
9. MQTT (IoT)
10. Streams / Batch
11. Multi-region replication
12. mTLS / OPA / Vault advanced

## Rationale
Reduce cognitive overload; each milestone adds one new major protocol.