# Program Engine Audit & Default Library Plan

Produced 2026-07-18 from a fresh code audit of `main` (e7657ad4).

## Implementation update — 2026-07-18

The planned implementation is now in `main`: the typed authoring DSL, the original
default library plus the synthetic Powerlifting Double-Exposure Practice recipe,
built-in JSON programs, strict idempotent seeding, stages and unequal waves,
variation ladders, velocity prescriptions and capture, Program Library browse/detail/
intake/activation UI, and all-program lifecycle coverage have landed. The runtime
still has no program-specific execution branches; definitions compile through the
same payload → plan → run → workout snapshot pipeline as user-authored programs.

The remaining gate is verification, not feature design: run the focused all-program
tests, the Program Library UI journey, catalog screenshot capture, and the serial
full UI suite once a working iOS Simulator service is available. Until those runs
are green, the test plan's behavioural and screenshot acceptance rows remain open.

The retained reference set contains only documents that still describe the shipped engine or an explicit parked gap:

1. [02-ProgramSpecifications.md](02-ProgramSpecifications.md) — complete specs for
   the original ship-safe default programs plus the current catalogue supplement,
   incl. formulas, worked examples, failure/
   deload/missed/completion behavior.
2. [03-DomainModel.md](03-DomainModel.md) — engine-specific model, formula
   reference semantics, and state-ownership table.
3. [04-SeedData.md](04-SeedData.md) + [seed/program-library.json](seed/program-library.json)
   — authoring schema, missing catalog exercises, relationship records, SwiftData
   seeding strategy, and import-ready data.
4. [06-TestPlan.md](06-TestPlan.md) — scenario matrix, 13 end-to-end program
   tests, and seed/integrity suites.
5. [08-SchemaGapBacklog.md](08-SchemaGapBacklog.md) — parked schema candidates
   that are not scheduled by the active product roadmap.
6. [09-DeepResearchCorrections.md](09-DeepResearchCorrections.md) — corrections
   applied to the authored program specifications.

Headline: no structural redesign was needed. The engine gaps identified in this audit
are implemented; verification of the full behavioural matrix is the remaining
release gate.
