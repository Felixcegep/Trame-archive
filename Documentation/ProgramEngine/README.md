# Program Engine Audit & Default Library Plan

Produced 2026-07-18 from a fresh code audit of `main` (e7657ad4).

## Implementation update — 2026-07-18

The planned implementation is now in `main`: the typed authoring DSL, all thirteen
built-in JSON programs, strict idempotent seeding, stages and unequal waves,
variation ladders, velocity prescriptions and capture, Program Library browse/detail/
intake/activation UI, and all-program lifecycle coverage have landed. The runtime
still has no program-specific execution branches; definitions compile through the
same payload → plan → run → workout snapshot pipeline as user-authored programs.

The remaining gate is verification, not feature design: run the focused all-program
tests, the Program Library UI journey, catalog screenshot capture, and the serial
full UI suite once a working iOS Simulator service is available. Until those runs
are green, the test plan's behavioural and screenshot acceptance rows remain open.

1. [01-ArchitectureAudit.md](01-ArchitectureAudit.md) — verified code paths,
   confirmed gaps G1–G10, compatibility matrix, licensing/product-risk table,
   final per-program verdicts (Outputs 1 + 7).
2. [02-ProgramSpecifications.md](02-ProgramSpecifications.md) — complete specs for
   the 13 ship-safe default programs, incl. formulas, worked examples, failure/
   deload/missed/completion behavior (Output 2).
3. [03-DomainModel.md](03-DomainModel.md) — canonical model = existing types +
   deltas Δ1–Δ10; formula reference semantics; state-ownership table (Output 3).
4. [04-SeedData.md](04-SeedData.md) + [seed/program-library.json](seed/program-library.json)
   — authoring schema, missing catalog exercises, relationship records, SwiftData
   seeding strategy, import-ready data (Output 4).
5. [05-ImplementationPlan.md](05-ImplementationPlan.md) — phased plan; Phases 1–3
   mostly shipped, new work concentrated in Phases 4–6 (Output 5).
6. [06-TestPlan.md](06-TestPlan.md) — scenario matrix vs existing suites, 13
   end-to-end program tests, seed/integrity suites (Output 6).
7. [07-ExecutionPlan.md](07-ExecutionPlan.md) — PR-by-PR execution roadmap:
   4 milestones, 17 PRs, dependency graph, risk register.

Headline: no structural redesign was needed. The engine gaps identified in this audit
are implemented; verification of the full behavioural matrix is the remaining
release gate.
