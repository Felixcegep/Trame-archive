# GymTracker Design Reference

Status: Reference bundle
Owner: Design
Last reviewed: 2026-07-31
Source of truth: No — production tokens and the canonical design documents win

GymTracker is a focused iOS training log for serious solo lifters: fast to log
mid-workout, calm to read, and trustworthy over time. The product loop is
Plan → Execute fast → Record truth → Understand performance → Progress
intelligently → Repeat.

Use this bundle for visual direction, mockups, and prototypes. For shipped
behavior and current product scope, read [`Feature.md`](../../Feature.md),
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

## Visual foundations

- Warm cream page (`#F6F0E7`) and warm-white cards (`#FFFCF7`); near-black navy
  text (`#272635`). Blue is action/current state, sage is completed/success,
  and tan is contextual history/rest.
- Saturated colors are not background fills. Use pale tints for surfaces and
  badges; encode state with labels, icons, and values in addition to color.
- SF Rounded is for large display values and titles; SF Pro is the default body
  type. Use tabular monospaced digits only for timers, loads, reps, and stats.
- Spacing follows 2/4/8/10/12/16/20/24/32; screen inset is 20px and hit targets
  are at least 44px.
- Corners are 8/12/16/18/20 for small, medium, large, section/button, and card
  roles. Capsules are reserved for the primary CTA and tiny week badges.
- Cards group meaningful content, use a hairline border and restrained shadow,
  and never turn every row into a floating card.
- Motion is calm and quick: press response 140ms, compact changes 220ms,
  layout changes 300ms, no bounce, idle motion, confetti, gradients, or dark
  translucent UI.

## Native source references

Production UI uses the centralized tokens in `GymTracker/Core/DesignSystem/`:

- `Colors.swift`, `Fonts.swift`, `Icons.swift`, `Motion.swift`, `Radius.swift`,
  and `Spacing.swift`.
- `Documentation/DesignSystem.md` for binding component and token rules.
- `Documentation/MotionAndHaptics.md` for motion and feedback decisions.
- `Documentation/Accessibility.md` for labels, Dynamic Type, contrast, and
  verification requirements.
- [`SetEditor.md`](../Design/SetEditor.md) for the custom Active Workout keypad
  and bottom-panel constraints.
- [`ComponentPrompts.md`](ComponentPrompts.md) for reusable prototype prompts.

## Component vocabulary

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

## Interactive iOS reference kit

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
