# BitVelocity Scripts

This directory contains utility scripts for the BitVelocity platform.

## Available Scripts

### Event Contract Validation

#### `validate-events.sh`
Validates event contract schemas for compliance with BitVelocity standards.

**Usage:**
```bash
./scripts/validate-events.sh
```

**What it validates:**
- ✅ File naming convention: `entity.action.v<version>.json`
- ✅ EventType format: `<domain>.<context>.<entity>.<action>.v<version>`
- ✅ Required envelope fields (eventId, eventType, occurredAt, etc.)
- ✅ Payload field naming (snake_case preferred)
- ✅ JSON schema structure validation (if ajv-cli available)

**Requirements:**
- `jq` (required) - JSON processor
- `ajv-cli` (optional) - JSON Schema validator
  ```bash
  npm install -g ajv-cli
  ```

**Example output:**
```
🔍 BitVelocity Event Contracts Validation
==========================================
📁 Scanning event contracts directory: /path/to/event-contracts

🔍 Validating: order.created.v1.json
   ✅ Valid

🔍 Validating: message.sent.v1.json
   ✅ Valid

==========================================
📊 Validation Summary
   Total files: 5
   Errors: 0
   🎉 All event contracts are valid!
```

## Adding New Scripts

When adding new scripts to this directory:

1. **Make them executable**: `chmod +x scripts/script-name.sh`
2. **Follow naming convention**: Use kebab-case (script-name.sh)
3. **Include usage documentation** in this README
4. **Add proper error handling** and user-friendly output
5. **Include required dependencies** and installation instructions

## Future Script Ideas

- `replay-events.sh` - Event replay utilities
- `cost-analysis.sh` - Infrastructure cost analysis
- `setup-dev-env.sh` - Local development environment setup
- `backup-data.sh` - Data backup automation
- `health-check.sh` - System health validation

## Contributing

When contributing scripts:
1. Test thoroughly in different environments
2. Use proper error handling (`set -e`)
3. Include colored output for better UX
4. Document all command-line options
5. Add examples of usage