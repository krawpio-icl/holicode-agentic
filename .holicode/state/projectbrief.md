---
mb_meta:
  projectID: "epic-integration-proxy"
  version: "0.1.0"
  lastUpdated: "2026-03-08"
  templateVersion: "1.0"
  fileType: "projectbrief"
---

# Epic Integration Proxy - Project Brief

## Core Goal
Build a secure integration proxy between Epic (hospital system) and a custom application, exposing only the required endpoints and data contracts.

## Scope
The project delivers an API mediation layer for authenticated request forwarding, response normalization, error handling, observability, and operational controls required for healthcare integrations.

## Key Milestones
1. Integration discovery and technical design baseline (Week 1-2)
2. First end-to-end proxy flow (auth + one clinical/business use case) (Week 3-5)
3. Hardening for production readiness (security, auditability, reliability) (Week 6-8)

## Success Metrics
- End-to-end request success rate: >= 99.5% for supported flows
- P95 proxy overhead latency: <= 300 ms over upstream response time
- Traceability coverage: 100% of requests include correlation/audit metadata

## Scope Boundaries
### In Scope
- Proxy/API gateway behavior between Epic and the custom app
- Integration contracts, mapping, authentication, logging, and monitoring

### Out of Scope
- Replacing Epic workflows or core Epic data model
- Building full hospital product features outside integration needs
