# GymTracker Documentation

This directory contains the small set of supporting documents that remain
useful beside the repository-level source-of-truth files. Temporary plans and
audits have explicit exit conditions; completed work is folded into the owning
document and then removed. Git history preserves obsolete material.

## Source-of-truth documents

- [`Feature.md`](../Feature.md) — product positioning, boundaries, vocabulary, and the current checkpoint.
- [`FeaturesList.md`](../FeaturesList.md) — implemented status, gaps, acceptance criteria, release scope, and implementation order.
- [`RoadMap.md`](../RoadMap.md) — unified product strategy and beta phasing.
- [`DomainModel.md`](../DomainModel.md) — authoritative domain vocabulary, lifecycle invariants, snapshots, deletion, and backup guarantees.
- [`ModelsAndEntities.md`](../ModelsAndEntities.md) — descriptive implementation reference; `DomainModel.md` wins in conflicts.
- [`ScreenshotCoverage.md`](../ScreenshotCoverage.md) — canonical UI states, PNG paths, and capture status.
- [`MarketAnalysis.md`](../MarketAnalysis.md) — competitor evidence and beta protocol.
- [`Gym Tracker Pivot.md`](Gym%20Tracker%20Pivot.md) — long-form north-star requirements; capabilities remain Later unless promoted.

## Design rules and references

- [`DesignSystem.md`](DesignSystem.md) — visual tokens, hierarchy, and component rules.
- [`MotionAndHaptics.md`](MotionAndHaptics.md) — animation, gesture, and tactile-feedback rules.
- [`Accessibility.md`](Accessibility.md) — accessibility requirements and verification checklist.
- [`Design/SetEditor.md`](Design/SetEditor.md) — active-workout set-editor rationale and constraints.
- [`GymTracker Design System/readme.md`](GymTracker%20Design%20System/readme.md) — design-reference bundle overview.
- [`GymTracker Design System/ComponentPrompts.md`](GymTracker%20Design%20System/ComponentPrompts.md) — reusable mockup and prototype prompts.
- [`GymTracker Design System/SKILL.md`](GymTracker%20Design%20System/SKILL.md) — entry point for the GymTracker design skill.

## Active plans

- [`Plans/MobilityAssessmentPlan.md`](Plans/MobilityAssessmentPlan.md) — mobility assessment scope and remaining verification.

## Release verification and audits

These documents provide evidence or implementation-gap analysis. They do not
override the source-of-truth documents above.

- [`Verification/ReleaseGate.md`](Verification/ReleaseGate.md) — single checklist for open release verification.
- [`Verification/UIUXAudit.md`](Verification/UIUXAudit.md) — repository-wide UI, accessibility, motion, and haptics audit.
- [`Verification/UIUXInteractionPlan.md`](Verification/UIUXInteractionPlan.md) — implementation-gap plan for motion, haptics, and feedback.
- [`Verification/RefactorAudit.md`](Verification/RefactorAudit.md) — repository-wide maintainability and architecture findings.

## Program Engine

- [`ProgramEngine/README.md`](ProgramEngine/README.md) — program-engine document map.
- [`ProgramEngine/02-ProgramSpecifications.md`](ProgramEngine/02-ProgramSpecifications.md) — program and progression specifications.
- [`ProgramEngine/03-DomainModel.md`](ProgramEngine/03-DomainModel.md) — program-engine domain model.
- [`ProgramEngine/04-SeedData.md`](ProgramEngine/04-SeedData.md) — deterministic seed data.
- [`ProgramEngine/06-TestPlan.md`](ProgramEngine/06-TestPlan.md) — program-engine test plan.
- [`ProgramEngine/08-SchemaGapBacklog.md`](ProgramEngine/08-SchemaGapBacklog.md) — schema gaps and follow-up work.
- [`ProgramEngine/09-DeepResearchCorrections.md`](ProgramEngine/09-DeepResearchCorrections.md) — research corrections and evidence notes.

## Document lifecycle rules

- `FeaturesList.md` owns implementation status and implementation order.
- `DomainModel.md` owns domain invariants and lifecycle semantics.
- `ScreenshotCoverage.md` owns screenshot state and capture status.
- Temporary plans and audits declare an owner, review date, and exit condition.
- When a plan is complete, move its decisions into the owning source-of-truth
  document and remove the plan unless it still contains active work.
- Git history, not an in-tree archive, preserves obsolete documents.
- Generated documentation bundles are derived snapshots, not source-of-truth documents, and should not be edited manually.
