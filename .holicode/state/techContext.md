---
mb_meta:
  projectID: "epic-integration-proxy"
  version: "0.1.0"
  lastUpdated: "2026-03-08"
  templateVersion: "1.0"
  fileType: "techContext"
---

# Epic Integration Proxy - Technical Context

## Issue Tracker
- **Provider**: Vibe Kanban
- **issue_tracker**: vibe_kanban <!-- vibe_kanban | github | local | jira -->
- **MCP Server**: vibe_kanban
- **Organization**: n/a (n/a)
- **Project**: n/a (n/a)
- **ID Prefix**: GIF
- **Statuses**: To do, In progress, In review, Done
- **Issue Type Convention**: Tag-based taxonomy
- **Type Taxonomy**: epic, story, task, technical-design, spike, bug
- **Taxonomy Strictness**: recommended <!-- recommended | required -->
- **ID Resolution**: Native tracker IDs (for example GIF-15)
- **Local Mode Note**: if `issue_tracker = local`, MCP/org/project fields may be left as `n/a`

## PR/Git Operations
- **PR Workflow**: GitHub PRs via `gh` CLI
- **Branch Convention**: `type/issue-id-short-description`
- **Commit Convention**: Conventional Commits (`type(scope): subject`)

## Technology Stack
### Frontend
- **Framework**: n/a (backend integration service)
- **Language**: n/a
- **Key Libraries**:
  - n/a
  - n/a
  - n/a

### Backend
- **Framework**: TBD (service framework to be finalized)
- **Language**: TBD
- **Runtime**: TBD
- **Key Libraries**:
  - HTTP client library (TBD)
  - Validation library (TBD)
  - Observability SDK (TBD)

### Database
- **Primary Database**: Minimal operational store (TBD)
- **Caching**: Optional short-lived cache (TBD)
- **Search**: n/a

### Infrastructure
- **Cloud Provider**: TBD
- **Container Platform**: TBD
- **CI/CD**: GitHub Actions (planned)
- **Monitoring**: Structured logs + metrics + tracing (stack TBD)

## Development Environment
### Required Tools
- Git: latest stable
- gh CLI: latest stable
- Runtime toolchain: TBD

### Development Setup
#### Prerequisites
```bash
# Finalized after stack selection
```

#### Installation Steps
```bash
# Finalized after stack selection
```

#### Environment Configuration
```bash
# EPIC base URL and credentials are managed via environment secrets
```

### IDE/Editor Configuration
- **Recommended IDE**: VS Code or JetBrains
- **Required Extensions**:
    - EditorConfig
    - Markdown linting
    - Language tooling for selected runtime

### Technical Constraints
#### Platform Constraints
Must integrate with Epic APIs available in the target hospital environment and network restrictions.

#### Performance Constraints
Proxy overhead should remain low and predictable for synchronous flows.

#### Security Constraints
No plaintext secrets in code; strict authN/authZ; audit logging and PHI-safe log policy.

#### Compliance Requirements
Healthcare compliance requirements apply (exact regulatory scope to be confirmed).

### Dependencies & Integrations
#### External APIs
- Epic API: clinical/operational data exchange (version TBD)
- Identity Provider: token issuing/validation for service calls (version TBD)
- Observability endpoint: logs/metrics/traces export (version TBD)

#### Third-Party Services
- Secret manager: credentials and key material storage
- CI platform: automated checks and quality gates
- Alerting system: incident notifications

#### Internal Dependencies
- Custom application backend: consumer of proxy contracts
- Domain mapping definitions: source of request/response transformations

### Build & Deployment
#### Build Process
```bash
# Defined after runtime selection
```

#### Testing Strategy
Unit Tests: mapping/validation and adapter behavior
Integration Tests: proxy to Epic sandbox/non-prod connectivity
E2E Tests: critical end-to-end integration scenarios

#### Deployment Strategy
Environment: non-prod -> staging -> production
Deployment Method: CI pipeline with gated promotions
Rollback Strategy: rollback to previous stable release and disable affected route

#### Environment Variables
```bash
# EPIC_BASE_URL=
# EPIC_CLIENT_ID=
# EPIC_CLIENT_SECRET=
# PROXY_AUDIENCE=
```

### Quality & Standards
#### Code Quality Tools
- Linting: TBD
- Formatting: TBD
- Type Checking: TBD

#### Coding Standards
- Conventional commits
- Stable public contracts with versioning
- Explicit error mapping and no silent failures

#### Documentation Standards
- Keep state files current after each major workflow
- Maintain technical design docs for architecture-level decisions

### Known Technical Issues
#### Current Limitations
- Runtime/framework not finalized yet
- Epic API endpoint inventory and auth details not finalized
- Compliance detail checklist not finalized

#### Technical Debt
- Initial docs-first setup before implementation: expected early uncertainty
- Tracker metadata bootstrap pending: minor operational debt

#### Planned Improvements
- Finalize runtime and baseline project skeleton: Week 1
- Add CI quality gates and smoke integration tests: Week 2
