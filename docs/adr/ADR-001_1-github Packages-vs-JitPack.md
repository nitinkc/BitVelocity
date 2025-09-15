# ADR-001_1: Github Package vs JitPack

## Status
Accepted

## Context
Easier package management and dissemination within team

## Decision
- Avoid Github packages as PAT requirement and github treats packages of public repo as private
- Avoid maven due to few set up steps
- Go with [Jitpack](https://jitpack.io/). Have at least a release in github.

## Consequences
+ Easy distribution of packages 
- Locking with Jitpack and in case the project is abandoned, maven has to be used 