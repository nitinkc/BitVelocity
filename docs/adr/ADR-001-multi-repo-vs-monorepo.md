# ADR-001: Multi-Repo over Monorepo

## Status
Accepted

## Context
Need isolation of domain evolution, independent versioning, separate CI cost control.

## Decision
Adopt multi-repository per domain + shared versioned libraries (BOM, core-common, security-lib, event-core, test-core).

## Consequences
+ Independent release cadence  
+ Clear domain boundaries  
- Harder cross-repo refactors (mitigate by shared libs & contract tests)  