# ADR-008: Pulumi Cloud Provider Abstraction

## Decision
Abstract provider resources behind `CloudProvider` interface; environment switches via config.

## Rationale
Portability & DR / migration practice.

## Consequence
+ Easy multi-cloud labs
- Slight abstraction overhead