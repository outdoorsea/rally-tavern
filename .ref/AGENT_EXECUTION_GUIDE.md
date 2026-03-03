# Agent Execution Guide for Rally + Gas Town

This guide explains how a coding agent should implement and operate the
Rally system.

------------------------------------------------------------------------

## Step 1: Initialize Project

1.  Check if `project-profile.yaml` exists.
2.  If missing, generate one using Planning Mode prompts.
3.  Save profile to project root.

------------------------------------------------------------------------

## Step 2: Run Planning Mode

Invoke skills in this order:

1.  Product Manager Skill
2.  OSS Research Skill
3.  Architecture Critique Skill
4.  Security Auditor Skill
5.  Brand Analysis
6.  Architect Skill
7.  Component Librarian

Output: - `build-card.yaml`

Planning Mode must not modify code.

------------------------------------------------------------------------

## Step 3: Resolve Components

For each capability in build-card:

call:

resolve(capability, facets)

Return best compatible component.

If none exist: - mark as build candidate.

------------------------------------------------------------------------

## Step 4: Create Execution Tasks

Generate `tasks.yaml`:

PM tasks UX tasks Architecture tasks Test tasks Implementation tasks

Mayor dispatches tasks to rigs.

------------------------------------------------------------------------

## Step 5: Execute Convoys

Convoy order:

1.  PM
2.  UX
3.  Architect
4.  Tester
5.  Development

Each convoy writes structured output to designated folders.

------------------------------------------------------------------------

## Step 6: Enforce Abstraction Policy

Before code merge:

Run Abstraction Auditor:

Check: - external APIs isolated - DB behind repository - business logic
separated - interfaces defined

If violations occur: - request refactor.

------------------------------------------------------------------------

## Step 7: Run Test Harness

Tester skill generates:

-   unit tests
-   integration tests
-   edge case tests

Tests must pass before build completion.

------------------------------------------------------------------------

## Step 8: Produce Build Receipt

Generate `build_receipt.yaml`.

Record:

tokens_used components_used files_changed test_pass_rate

------------------------------------------------------------------------

## Step 9: Feedback Loop

After build completion:

1.  Identify reusable logic.
2.  Promote to component candidate.
3.  Update skills if friction discovered.
4.  Increment component reuse counters.

------------------------------------------------------------------------

## Step 10: Continuous Improvement

Over time the system should:

-   refine skills
-   improve architecture defaults
-   increase component reuse
-   reduce token waste

Agents should prioritize reuse and maintain abstraction boundaries.

------------------------------------------------------------------------

End of Agent Execution Guide.
