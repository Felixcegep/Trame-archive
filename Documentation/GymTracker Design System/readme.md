# GymTracker Design Reference — Historical Bundle

Status: Historical/noncanonical reference bundle
Owner: Design
Last reviewed: 2026-07-31
Source of truth: No — superseded by the Trame Performance Editorial documents

> **Do not use this bundle as the current visual specification.** New production
> UI and new prototypes must follow [`TrameDesignConstitution.md`](../Design/TrameDesignConstitution.md),
> [`DesignSystem.md`](../DesignSystem.md), the approved specimen/calibration
> manifest [`Documentation/Design/Reference/README.md`](../Design/Reference/README.md),
> and [`TrameMigrationPlan.md`](../Design/TrameMigrationPlan.md). The approved
> specimen is `/Users/felixlachapelle/Documents/redesign/Favorie/trame-theme-lab (1).html`.
> Performance Lab — Dark is principal/default; Performance Lab — Pale is the
> supported alternate. Do not copy the legacy warm-cream palette, tinted-card
> treatment, or SF Rounded roles into new work.

The screenshots, prototype components, and token files in this bundle remain
historical evidence of earlier GymTracker decisions. They are useful for
understanding existing behavior and migration context, but they are not current
tokens, component prescriptions, or visual acceptance criteria.

GymTracker is a focused iOS training log for serious solo lifters: fast to log
mid-workout, calm to read, and trustworthy over time. The product loop is
Plan → Execute fast → Record truth → Understand performance → Progress
intelligently → Repeat.

Use this bundle only to inspect historical visual decisions, mockups, and
prototype behavior during migration. For new visual direction, shipped
behavior, and current product scope, read [`Feature.md`](../../Feature.md),
[`FeaturesList.md`](../../FeaturesList.md), and [`RoadMap.md`](../../RoadMap.md).

## Design character

- Strong, calm, precise, and encouraging without gamification.
- Sentence case for headings and helper copy; uppercase, tracked eyebrow labels
  for section markers.
- Plain, verb-first actions: “Start workout”, “Add set”, “Review Workout”.
- A prescription describes intended work; a saved workout records performed
  truth. Never imply that a recommendation overwrote logged history.
- One native SwiftUI iPhone surface: Today, Train, Nutrition, Progress, Settings
  from Today, and a root-owned Active Workout cover.

## Historical visual foundations — do not extend

The following values describe the retired bundle only: warm cream page
(`#F6F0E7`), warm-white cards (`#FFFCF7`), navy text (`#272635`), pale tinted
surfaces, SF Rounded display roles, the former corner/inset scale, and its
card/border/shadow treatment. They must not be used as new production tokens or
prototype defaults. Consult the current Trame documents for opaque semantic
surfaces, Performance Lab color architecture, editorial typography, and the
current radius/spacing roles.

## Native source references

Production UI uses the centralized tokens in `GymTracker/Core/DesignSystem/`:

- `Colors.swift`, `Fonts.swift`, `Icons.swift`, `Motion.swift`, `Radius.swift`,
  and `Spacing.swift`.
- `Documentation/DesignSystem.md` for binding component and token rules.
- `Documentation/MotionAndHaptics.md` for motion and feedback decisions.
- `Documentation/Accessibility.md` for labels, Dynamic Type, contrast, and
  verification requirements.
- For new work, also read [`TrameDesignConstitution.md`](../Design/TrameDesignConstitution.md),
  [`ComponentCatalog.md`](../Design/ComponentCatalog.md), and
  [`TrameMigrationPlan.md`](../Design/TrameMigrationPlan.md). Use the specimen
  and capture manifest for calibration; do not treat this bundle's assets as
  current visual baselines.
- [`SetEditor.md`](../Design/SetEditor.md) for the custom Active Workout keypad
  and bottom-panel constraints.
- [`ComponentPrompts.md`](ComponentPrompts.md) for reusable prototype prompts.

## Historical component vocabulary — do not extend

Core components are semantic icon wrappers, tinted icon chips, section labels,
cards, badges, and verb-first buttons. Forms use the shared search field,
segmented control, numeric set input, and system-grouped stepper rows. Lists
use icon-led rows and compact history metadata. Progress uses the activity
heatmap, planned-versus-performed comparison, recommendation card, status row,
and upcoming calendar. Workout surfaces use the session header, exercise card,
set row, and rest timer.

The reusable prompt details for these components live in
[`ComponentPrompts.md`](ComponentPrompts.md); do not create separate prompt
files for individual components.

## Historical interactive iOS reference kit

The `ui_kits/ios-app/` directory contains an interactive recreation of four
canonical surfaces, grounded in the SwiftUI source and the repository's
screenshots:

- `index.html` provides a click-through shell: Home → Start workout → Active
  Workout → log sets and rest → Review → Home.
- Screens include Home, Active Workout, Library/Train, and History, with shared
  status-bar and circular-button chrome.
- It intentionally omits Settings, Plans/calendar, the plate calculator,
  exercise picker, and the full save/review flow. Use `assets/screenshots/` and
  the production source for those surfaces.

The kit is a prototype reference, not a second product implementation. Keep
its vocabulary and visual decisions aligned with the native source.

## Brand assets and prototype files

- `assets/screenshots/` contains selected reference PNGs copied from
  `Screenshots/`.
- `components/` contains prototype component examples and styles.
- `tokens/` contains prototype color, typography, spacing, radius, shadow, and
  motion tokens.
- `Documentation/Brand/` contains the official logo and motion identity assets.
- `SKILL.md` is the entry point for agents using this design reference bundle.
