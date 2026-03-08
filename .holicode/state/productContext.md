---
mb_meta:
  projectID: "epic-integration-proxy"
  version: "0.1.0"
  lastUpdated: "2026-03-08"
  templateVersion: "1.0"
  fileType: "productContext"
---

# Epic Integration Proxy - Product Context

## Why We're Building This
- Hospital and custom app need controlled, reliable interoperability with Epic APIs.
- Direct client-to-Epic coupling increases security, compliance, and change-management risk.
- Teams need a stable integration layer that absorbs upstream API variation.

## Target Users
1. **Integration Engineers**: Build and maintain flows between Epic and the app.
2. **Clinical/Operations Teams**: Depend on consistent data exchange for workflows.
3. **Security/Compliance Stakeholders**: Require auditability and controlled access.

## Problem Solving
- Provide one integration boundary with strict auth and policy enforcement.
- Translate and validate payloads so app-side contracts remain stable.
- Improve incident response with centralized observability and correlation IDs.

## Key Benefits
- Lower coupling between the app and Epic-specific API details.
- Safer rollout of integration changes through one gateway path.
- Better diagnostics, governance, and operational reliability.

## How It Should Work (High-Level Flow)
Client app sends authenticated request to proxy. Proxy validates identity and authorization, enriches metadata, applies mapping/validation, forwards to Epic endpoint, normalizes the response, and returns a consistent contract to the app while logging audit and trace events.
