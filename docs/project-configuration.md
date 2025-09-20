# BitVelocity Sprint 1 Project Configuration

This configuration can be used to set up a GitHub Project for tracking Sprint 1 progress.

## Project Details
- **Name:** BitVelocity Sprint 1 - Foundation Infrastructure
- **Description:** Foundational infrastructure and authentication sprint for BitVelocity platform
- **Template:** Team planning

## Columns/Status Fields
1. **Backlog** 
   - Description: New issues awaiting triage and planning
   - Automation: New issues automatically added here

2. **Ready**
   - Description: Issues that are refined and ready to be worked on
   - Automation: Issues moved here when assigned and estimated

3. **In Progress**
   - Description: Issues currently being worked on
   - Automation: Issues moved here when status changed to "In Progress"

4. **Review**
   - Description: Completed work awaiting code review and testing
   - Automation: Issues moved here when PR is opened

5. **Done**
   - Description: Completed and merged work
   - Automation: Issues moved here when PR is merged

## Labels
```yaml
labels:
  # Type labels
  - name: "type:epic"
    color: "0052CC"
    description: "Epic-level issue grouping multiple stories"
  
  - name: "type:story"
    color: "0E8A16"
    description: "User story describing a feature from user perspective"
  
  - name: "type:task"
    color: "1D76DB"
    description: "Specific development task"
  
  # Priority labels
  - name: "priority:high"
    color: "D93F0B"
    description: "High priority item"
  
  - name: "priority:medium"
    color: "FBCA04"
    description: "Medium priority item"
  
  - name: "priority:low"
    color: "0E8A16"
    description: "Low priority item"
  
  # Epic labels
  - name: "epic:infrastructure-foundation"
    color: "5319E7"
    description: "Infrastructure Foundation epic"
  
  - name: "epic:authentication-service"
    color: "B60205"
    description: "Authentication Service epic"
  
  - name: "epic:product-service"
    color: "0052CC"
    description: "Product Service epic"
  
  - name: "epic:observability-foundation"
    color: "0E8A16"
    description: "Observability Foundation epic"
  
  # Status labels
  - name: "status:blocked"
    color: "D93F0B"
    description: "Issue is blocked by dependencies"
  
  - name: "status:needs-review"
    color: "FBCA04"
    description: "Ready for review"
  
  # Area labels
  - name: "area:backend"
    color: "C2E0C6"
    description: "Backend development"
  
  - name: "area:infrastructure"
    color: "F9D0C4"
    description: "Infrastructure and DevOps"
  
  - name: "area:security"
    color: "D4C5F9"
    description: "Security-related work"
  
  - name: "area:monitoring"
    color: "FEF2C0"
    description: "Monitoring and observability"
```

## Custom Fields
```yaml
custom_fields:
  - name: "Story Points"
    type: "number"
    description: "Estimation in story points"
  
  - name: "Epic"
    type: "single_select"
    options:
      - "Infrastructure Foundation"
      - "Authentication Service"
      - "Product Service"
      - "Observability Foundation"
  
  - name: "Sprint"
    type: "single_select"
    options:
      - "Sprint 1"
      - "Sprint 2"
      - "Sprint 3"
      - "Future"
```

## Automation Rules
```yaml
automation:
  - name: "Auto-assign to backlog"
    trigger: "Issue created"
    action: "Move to Backlog column"
  
  - name: "Move to In Progress"
    trigger: "Issue assigned"
    action: "Move to In Progress column"
  
  - name: "Move to Review"
    trigger: "Pull request opened"
    action: "Move to Review column"
  
  - name: "Move to Done"
    trigger: "Pull request merged"
    action: "Move to Done column"
```

## Initial Issues to Create
Based on the documentation, create these GitHub issues:

### Epic Issues
1. **Epic: Infrastructure Foundation**
   - Use epic template
   - Copy content from `docs/epics/01-infrastructure-foundation.md`
   - Labels: `type:epic`, `epic:infrastructure-foundation`, `priority:high`

2. **Epic: Authentication Service**
   - Use epic template
   - Copy content from `docs/epics/02-authentication-service.md`
   - Labels: `type:epic`, `epic:authentication-service`, `priority:high`

3. **Epic: Product Service**
   - Use epic template
   - Copy content from `docs/epics/03-product-service.md`
   - Labels: `type:epic`, `epic:product-service`, `priority:high`

4. **Epic: Observability Foundation**
   - Use epic template
   - Copy content from `docs/epics/04-observability-foundation.md`
   - Labels: `type:epic`, `epic:observability-foundation`, `priority:medium`

### Story Issues
1. **Story: Consistent Development Environment**
   - Use user story template
   - Copy content from `docs/issues/001-consistent-development-environment.md`
   - Labels: `type:story`, `epic:infrastructure-foundation`, `priority:high`

2. **Story: Secure Authentication System**
   - Use user story template
   - Copy content from `docs/issues/002-secure-authentication-system.md`
   - Labels: `type:story`, `epic:authentication-service`, `priority:high`

3. **Story: Product Catalog Management**
   - Use user story template
   - Copy content from `docs/issues/003-product-catalog-management.md`
   - Labels: `type:story`, `epic:product-service`, `priority:high`

4. **Story: System Health Visibility**
   - Use user story template
   - Copy content from `docs/issues/004-system-health-visibility.md`
   - Labels: `type:story`, `epic:observability-foundation`, `priority:medium`

## Sprint Planning Notes
- Total story points: 68
- Recommended team velocity: 15-25 points per week
- Estimated sprint duration: 3-4 weeks
- Critical path: Infrastructure Foundation → Authentication Service → Product Service
- Observability can be developed in parallel after week 2