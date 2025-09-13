# Domain Architecture – Messaging & Chat

## 1. Purpose
Real-time bidirectional communication, presence tracking, and message propagation across regions.

## 2. Services
| Service | Responsibility | Store |
|---------|----------------|-------|
| chat-service | Room membership, message ingestion | Kafka (event log), optional Postgres for metadata |
| presence-service | Track online/offline (TTL) | Redis |
| attachment-service | Metadata + object storage pointer | Postgres + Object store (MinIO/S3) |
| chat-gateway (optional) | Aggregated WebSocket entrypoint | N/A (routing layer) |

## 3. Protocol Mapping
| Use Case | Protocol |
|----------|----------|
| Send/Receive messages | WebSocket |
| Presence updates | gRPC (internal) + WebSocket broadcast |
| Message persistence | Kafka event stream |
| Cross-region sync | Kafka MirrorMaker |
| Attachment upload | REST |
| Moderation (future) | Event to ML/AI API (REST/gRPC) |

## 4. Data Model (Minimal)
Postgres (metadata):
- chat_rooms(id, name, created_at)
- chat_room_members(room_id, user_id, joined_at)
- attachments(id, owner_id, room_id, file_key, mime_type, size, created_at)

Redis (presence):
- presence:user:{userId} = { status: ONLINE, lastSeen: epoch } (TTL 90s)
Kafka events:
- chat.message.sent.v1
- chat.message.edited.v1 (optional)
- chat.message.deleted.v1 (optional)

Message payload example:
```
{
  "eventType": "chat.message.sent.v1",
  "payload": {
    "messageId": "M123",
    "roomId": "R88",
    "senderId": "U9",
    "content": "hello",
    "sentAt": "...",
    "attachments": []
  }
}
```

## 5. WebSocket Contract
Client → Server:
```
{
  "type": "SEND_MESSAGE",
  "roomId": "R88",
  "content": "hello"
}
```
Server → Client:
```
{
  "type": "MESSAGE",
  "roomId": "R88",
  "messageId":"M123",
  "senderId":"U9",
  "content":"hello",
  "ts":"..."
}
```
Presence event push:
```
{ "type": "PRESENCE", "userId": "U10", "status": "ONLINE" }
```

## 6. Caching & Session Model
- Redis pub/sub optional for local fan-out.
- Primary ordering guarantee relies on Kafka partition by roomId.
- WebSocket session registry in-memory + fallback index in Redis (for targeted push on node failover).

## 7. Resilience
| Failure | Strategy |
|---------|----------|
| Spike in messages | Backpressure: queue limit per connection |
| Slow consumer client | Drop connection after send buffer breach |
| Kafka outage | Buffer ephemeral in-memory (bounded, drop oldest) with warning |
| Presence TTL expiration | Auto OFFLINE event broadcast without explicit disconnect |

## 8. Security
- JWT required to open WebSocket; token revalidation every N minutes.
- Authorization: membership check before accepting SEND_MESSAGE for a room.
- Content moderation (future): emit chat.message.flagged.v1 from ML classification.

## 9. Observability
Metrics:
- chat_ws_active_sessions
- chat_messages_ingested_total
- chat_messages_fanout_latency_ms
- presence_online_users
Tracing:
- WS handshake spans
- Kafka publish/consume spans with roomId attribute

## 10. Testing Matrix
| Layer | Focus |
|-------|-------|
| Unit | Room membership validation |
| Integration | Kafka message ordering per roomId |
| WebSocket functional | End-to-end fan-out under load |
| Performance | 95th percentile message latency |
| Chaos | Kill chat-service pod mid-stream |
| Security | Unauthorized send attempt blocked |

## 11. Implementation Sequence
1. Basic WebSocket send/echo (single node, in-memory)
2. Kafka-backed message persistence
3. Presence TTL with Redis
4. Multi-room support + membership enforcement
5. Attachments (REST upload stub)
6. MirrorMaker cross-region test
7. Performance tuning + backpressure
8. (Optional) Moderation event integration

## 12. Interoperability Checklist
- [ ] Uses shared event envelope
- [ ] Room-level partition keys consistent across regions
- [ ] Presence events not required by other domains (no coupling)
- [ ] Attachment metadata events (if any) documented
- [ ] DR scenario: failover retains at-least-once delivery semantics

## 13. Cost Controls
- Defer attachments (object storage) initially.
- Single Kafka broker early (no replication).
- Presence alone only Redis + WS.

## 14. Exit Criteria
- Message visible to all subscribed room members < 150ms intra-region
- Cross-region replication < 2s
- Backpressure test dropping or delaying sends gracefully
- Presence state auto-clears on disconnect / TTL expiry
