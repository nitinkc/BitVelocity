# Event Contracts Changelog

All notable changes to the event contracts will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial event contract structure for all domains
- Envelope schema validation framework
- Documentation for event contract usage patterns

## [1.0.0] - 2024-01-15

### Added

#### E-Commerce Domain
- `ecommerce.order.created.v1` - Order creation events
- `ecommerce.inventory.stock.adjusted.v1` - Inventory level changes

#### Chat Domain  
- `chat.message.sent.v1` - Chat message events

#### IoT Domain
- `iot.telemetry.raw.v1` - Raw telemetry data from IoT devices

#### ML/AI Domain
- `ml.fraud.order.scored.v1` - Fraud scoring results for orders

#### Schema Infrastructure
- `envelope.schema.json` - Base envelope schema for all events
- Validation pipeline for backward compatibility
- Required fields standard across all events

### Schema Requirements
All events must include the following envelope fields:
- `eventId` (UUID)
- `eventType` (string with domain.context.entity.action.version format)
- `occurredAt` (ISO 8601 timestamp)
- `producer` (service identifier)
- `traceId` (distributed tracing correlation)
- `correlationId` (business transaction correlation)
- `partitionKey` (message partitioning strategy)
- `schemaVersion` (envelope schema version)
- `payload` (domain-specific business data)

### Breaking Change Policy
- **Minor versions**: Additive changes only (new optional fields)
- **Major versions**: Breaking changes require dual-publishing period
- **Deprecation**: Mark v1 deprecated when v2 is available
- **Retirement**: Remove v1 only after consumer migration complete

## Future Planned Events

### E-Commerce Domain
- `ecommerce.order.paid.v1` - Payment completion events
- `ecommerce.product.updated.v1` - Product catalog changes
- `ecommerce.order.shipped.v1` - Order fulfillment events

### Social Domain
- `social.post.created.v1` - Social media post creation
- `social.post.liked.v1` - Post engagement events

### Security Domain
- `security.policy.updated.v1` - Security policy changes
- `security.access.granted.v1` - Access control events

## Migration Notes

### From v0.x to v1.0
- All events now require standard envelope fields
- Field naming changed to snake_case in payload, camelCase in envelope
- Event type naming convention standardized
- Backward compatibility validation added to CI pipeline

## Validation Rules

### Naming Conventions
- Event files: `<entity>.<action>.v<version>.json`
- Event types: `<domain>.<context>.<entity>.<action>.v<version>`
- Payload fields: `snake_case`
- Envelope fields: `camelCase`

### Content Rules
- No personally identifiable information (PII) in raw form
- All monetary amounts in smallest currency unit (cents)
- All timestamps in ISO 8601 format
- All UUIDs in standard UUID format
- All enums explicitly defined

### CI Pipeline Validation
1. JSON Schema validation against envelope.schema.json
2. Backward compatibility check within major version
3. Field naming convention enforcement
4. Required fields validation
5. PII leakage detection

For detailed usage instructions, see [GUIDE_EVENT_CONTRACTS_USAGE.md](../GUIDE_EVENT_CONTRACTS_USAGE.md).