# Rally System Roadmap

Agent-First Planning, Skill Orchestration, and Component Reuse for Gas
Town

## Purpose

Rally is a planning, design, and reuse layer that integrates with Gas
Town's Mayor to improve how software projects are conceived, structured,
and built.

Objectives: - Reduce architectural drift in AI-assisted coding - Prevent
repeated reinvention of common functionality - Encourage reusable
abstraction layers - Capture feedback and collective intelligence -
Encourage open-source reuse - Surface security risks early - Maintain
consistent brand identity across projects

Rally is **agent-first** and **local-first**.

------------------------------------------------------------------------

## System Overview

Gas Town provides: - Overseer (human intent) - Mayor (agent
orchestration) - Rigs (execution environments)

Rally extends the Mayor by adding:

1.  Planning Mode
2.  Role Skills
3.  Component Resolution
4.  Architecture Critique
5.  Security Analysis
6.  Open Source Research
7.  Abstraction Enforcement
8.  Feedback Loop

Workflow:

Idea → Planning Mode → Build Card → Mayor Convoys → Code + Tests →
Receipts → Improvements

------------------------------------------------------------------------

## Core Design Principles

### Agent-First

Artifacts must be structured and machine-readable.

### Deterministic Planning

Planning produces structured outputs instead of narrative guidance.

### Replaceability

Systems encourage abstraction boundaries so components can be swapped.

### Reuse Before Reinvention

Evaluate open-source software before building new functionality.

### Opinionated Defaults

Provide sensible stack defaults to prevent tool rediscovery.

### Security by Design

Threat modeling happens during planning.

### Continuous Learning

Each build generates feedback that improves the system.

------------------------------------------------------------------------

## Project Profile

Each project contains `project-profile.yaml`.

Example:

``` yaml
project:
  name: meety-web

facets:
  platform: [web]
  language: [python]
  framework: [fastapi]
  auth: [sso-google, sso-facebook]
  db: [postgres]
  migrations: [alembic]
  testing: [pytest]
  deployment: [docker]

needs:
  - login
  - settings
  - admin-panel

constraints:
  - local-first
  - low-ops
```

------------------------------------------------------------------------

## Build Card

Planning Mode generates `build-card.yaml`.

``` yaml
mvp_scope:
  problem_statement:
  success_metric:
  non_goals:

brand_profile:
  tone:
  audience:
  design_style:

oss_analysis:
  candidates:
  recommendations:

architecture_risks:
  issues:
  mitigation:

security_review:
  attack_vectors:
  required_controls:

abstraction_boundaries:
  - name:
    type:
    reason:

entities:
screens:
external_integrations:

recommended_components:

acceptance_criteria:

execution_plan:
  - PM
  - UX
  - Architect
  - Tester
  - Dev
```

------------------------------------------------------------------------

## Skill System

Skills are deterministic procedural modules executed by the Mayor.

Required MVP Skills: - product-manager - architect - ux-designer -
librarian - test-engineer - oss-researcher - security-auditor -
abstraction-auditor

Skills output structured data only.

------------------------------------------------------------------------

## Component System

Components represent reusable code modules.

Each component contains: - manifest.yaml - template/ - tests/ -
integration_instructions.yaml

Example manifest:

``` yaml
name: python-fastapi-oauth-starter
version: 1.2.0

provides:
  capability: user-authentication

compatibility:
  language: python
  framework: fastapi
  db: postgres

entrypoints:
  router_factory:
  config_class
```

------------------------------------------------------------------------

## Resolution Engine

Components are selected via capability resolution.

Example query:

resolve(capability=user-authentication, facets)

Resolution scoring: 1. Required facet compatibility 2. Optional facet
compatibility 3. Stability score 4. Reuse count 5. Trust tier

------------------------------------------------------------------------

## Execution Phase

Mayor orchestrates:

PM → UX → Architect → Component Integration → Testing → Development

Outputs written to:

design/ architecture/ tests/ components/ src/

------------------------------------------------------------------------

## Feedback Loop

Each build produces `build_receipt.yaml`.

``` yaml
build_receipt:
  tokens_used:
  files_changed:
  components_used:
  abstraction_score:
  test_pass_rate
```

Feedback improves: - skills - components - architecture patterns

------------------------------------------------------------------------

## Abstraction Policy

External integrations must be isolated behind interfaces or adapters.

Examples: - AuthProvider interface - Repository layer - PaymentGateway
adapter

Example:

``` yaml
abstraction_boundaries:
  - name: AuthProvider
    type: interface
    reason: OAuth flexibility
```

------------------------------------------------------------------------

## Opinionated Stack Defaults

Web: - FastAPI - Postgres - Alembic - Pytest - Ruff

iOS: - SwiftUI - MVVM - Service layer - Repository protocol

------------------------------------------------------------------------

## MVP Scope

Initial implementation includes: - Planning Mode - Build Card - Core
skills - Three reusable components - Receipt logging

No marketplace or federation yet.

------------------------------------------------------------------------

## Success Metrics

After 30 days measure:

-   reduced architecture churn
-   faster planning
-   increased component reuse
-   fewer security oversights
-   consistent project structure

------------------------------------------------------------------------

## Final Principle

Design for replaceability. Replaceability enables reuse. Reuse reduces
entropy. Reduced entropy compounds intelligence.
