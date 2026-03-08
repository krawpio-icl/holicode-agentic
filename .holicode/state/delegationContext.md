---
mb_meta:
  projectID: "epic-integration-proxy"
  version: "0.1.0"
  lastUpdated: "2026-03-08"
  templateVersion: "1.0"
  fileType: "delegationContext"
---

# Delegation Context - Epic Integration Proxy

## Decision Delegation Settings

### Business Decisions
- **Default Mode**: require_human_approval
- **Delegated to AI**: false
- **Approval Roles**: [Product_Owner, Product_Manager, Founder]
- **Delegation Scope**: []
- **Explicit Opt-outs**: []

### Technical Decisions
- **Default Mode**: require_human_approval
- **Delegated to AI**: false
- **Approval Roles**: [Architect, CTO, Tech_Lead]
- **Delegation Scope**: []
- **Explicit Opt-outs**: []

### UI/Design Decisions
- **Default Mode**: require_human_approval
- **Delegated to AI**: false
- **Approval Roles**: [Designer, UX_Lead]
- **Delegation Scope**: []
- **Explicit Opt-outs**: []

### Autonomous Roles

#### TPM (Tech Project Manager)
- **Enabled**: false
- **Cadence**: on_demand

## Maturity Indicators

### Business Context
- **Quality Level**: low
- **Assessment Date**: 2026-03-08
- **Indicators**:
  - [x] Clear problem statement exists
  - [ ] Success metrics defined
  - [x] Stakeholders identified
  - [ ] Constraints documented
  - [ ] Scope boundaries clear

### Technical Architecture
- **Maturity Level**: exploratory
- **Assessment Date**: 2026-03-08
- **Indicators**:
  - [x] Architecture patterns established
  - [ ] Technology stack finalized
  - [ ] Security model defined
  - [ ] Performance requirements clear
  - [ ] Operational model documented

### Team Experience
- **Level**: intermediate
- **With HoliCode**: beginner
- **Domain Expertise**: intermediate
- **AI Collaboration**: intermediate

## Delegation History
<!-- Track when and why delegation settings changed -->

### 2026-03-08 - Initial Setup
- All decisions default to human approval
- No delegations configured
- Reason: New project initialization

## Notes
- Delegation requires explicit opt-out with documented reasoning
- Changes to delegation settings should be tracked in history
- Regular review recommended (monthly/quarterly)
