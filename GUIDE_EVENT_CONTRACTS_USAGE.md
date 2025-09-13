# Event Contracts Usage Guide

Workflow:
1. Add new event schema draft under appropriate domain path.
2. Run `npm run validate-events` (custom script) to:
   - JSON Schema validation
   - Naming pattern lint
   - Backward compatibility check
3. Update `CHANGELOG.md` in event-contracts repo.
4. Reference event in service README with producer & consumers.
5. Add integration test publishing example event.

Compatibility Rules:
- Additive fields only (optional).
- No renaming/removal within same major version.
- Major version bump requires dual-publish transitional period.
