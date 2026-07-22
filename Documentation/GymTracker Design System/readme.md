# GymTracker Design System

A focused iOS training log for **serious solo lifters** — fast to log a set mid-workout, trustworthy for tracking real performance history over time. Product loop: *Plan → Execute fast → Record truth → Understand performance → Progress intelligently → Repeat.* Tagline: **"Strength training that progresses with you."**

One product surface: a native SwiftUI iPhone app with four tabs — **Today, Train, Nutrition, Progress** — Settings as a gear route from Today, plus a full-screen **Active Workout** cover (the heart of the app), root-owned active Mobility sessions, a save/review flow, multi-week Plans, and a rest-timer Live Activity.

## Product direction — July 2026 pivot (see `ProductPivotAudit.md`)

The accepted PivotReport (July 17, 2026) commits **nutrition** as the second pillar (no longer beta-gated), adds an optional **daily journal / evening check-in** (a Today card + Journal section in Progress — never a tab), and elevates the **local-first vault with optional encrypted iCloud sync** to the paid anchor. Promise: *"Strength training that progresses with you — fueled by what you eat."* The target IA is now **implemented**: tabs **Today / Train / Nutrition / Progress**, Settings as a gear on the Today header, with the Lightweight Today, Mobility MVP, Nutrition MVP, and Training Calendar slices shipped (see `FeaturesList.md` §6–9). Design against the implemented app; the phased interface direction (fixed Today layout first, then Home customization, Program Path, chart presets, and the graph builder by beta phase) is owned by `RoadMap.md` §20–21. Library vocabulary (implemented): templates = **Workouts**, collections = **Folders**, plans = **Programs**.

## Sources

- GitHub: https://github.com/Felixcegep/GymTracker (private) — SwiftUI app. Design tokens live in `GymTracker/Core/DesignSystem/` (`Colors.swift`, `Fonts.swift`, `Icons.swift`, `Motion.swift`, `Radius.swift`, `Spacing.swift`); screens in `GymTracker/Core/Features/`; product docs in `Feature.md`, `FeaturesList.md`, `RoadMap.md`, `MarketAnalysis.md`, `DomainModel.md`. Reference PNGs of every canonical screen are in `Screenshots/` (a few copied to `assets/screenshots/` here). Explore the repo further to design deeper flows with full fidelity.

## Content fundamentals

- **Voice:** strong, calm, precise. Encouraging without being game-like. No confetti, no hype, no emoji.
- Speaks to "you", acts for you: "Ready when you are." · "Track your training today." · "Jump in and add exercises as you go." · "Take a breath. Your next set is ready when you are."
- **Sentence case with a period** for headers and helper copy, even short ones ("No workouts yet", "Add your first exercise.").
- **UPPERCASE micro-labels** (caption bold + 0.8px tracking) for section eyebrows: QUICK ACTIONS, HISTORY, EXERCISES, CURRENT EXERCISE, FREE WORKOUT.
- Buttons: verb-first, plain: "Start workout", "Review Workout", "Add set", "Continue workout", "Apply 52.5 kg".
- Data strings use compact separators: `1 / 3 sets · Next: Bench Press · Set 2`, `3 × 8 @ 50 kg · Jul 12`, `59 min`.
- Trust language around history: planned work is a prescription; a saved workout is "historical truth". Destructive actions always confirm ("Your logged sets will not be saved.").
- Vocabulary: Workout (template, in Library), Folder (collection), Program (plan), Exercise, Set, Rest, History, Records, Balance, Free Workout. Prescription vs performed truth wording extends to nutrition ("a logged meal is truth; a target is a prescription") and journal.

## Visual foundations

- **Palette:** warm cream page `#F6F0E7`; near-white warm cards `#FFFCF7`; near-black navy text `#272635`. Blue `#3D72E2` = actions & current state; sage `#487A6C` = success/completed; tan `#A1683A` = tertiary context (dates, history, rest). **Saturated colors are never background fills** — use the pale tints (`#E7E9EF` blue-gray, `#E7EAE1` green-gray, `#F2E9DD` tan) for surfaces and badges. Icon chips use color at 12% opacity behind the colored glyph.
- **Type:** SF Rounded (via `ui-rounded`) for large display numbers/titles (34/32 bold); SF Pro for everything else at iOS text-style sizes (17 body, 15 subheadline, 13 footnote, 12/11 captions). Monospaced (tabular) digits **only** for timers, loads, reps, stats. Muted text = text color at 58% (subdued) / 42% (subtle).
- **Spacing:** 2/4/8/10/12/16/20/24/32. Screen inset 20px. Hit targets ≥44px.
- **Corners:** 8 small / 12 medium / 16 large / 18 sections+buttons / 20 cards. Not pill-shaped — capsules only for the Start-workout CTA and tiny week badges.
- **Cards:** near-white fill, 1px hairline border (text @9%), whisper shadow (text @2–3%). Cards wrap only *meaningful grouped content* — never every row. The idle primary card gets a 1.5px blue @16% outline; the expanded/current exercise card a 1px blue @42% stroke and blue-gray fill; completed exercises the green-gray fill.
- **Backgrounds:** flat cream everywhere. No images, gradients (single exception: active-workout hero card, blue→blue 85%), textures, or illustration.
- **Motion:** calm and quick — press = scale 0.97 + opacity 0.86 over 140ms ease-out; layout 300ms fully-damped; snappy 220ms, zero bounce. No confetti, no decorative motion. Delight = clarity and speed.
- **No dark UI, no blur/transparency layers**; the tab bar and nav bar are opaque cream/card.

## Iconography

- The app uses **SF Symbols exclusively**, referenced by semantic token in `Icons.swift` (e.g. `house.fill`, `dumbbell.fill`, `clock.arrow.circlepath`, `timer`, `chart.line.uptrend.xyaxis`, `trophy.fill`, `flame`). No custom SVGs, no PNG icons, no emoji.
- SF Symbols has no webfont/CDN. **Substitution flagged:** this system uses **Material Symbols Rounded** (Google Fonts CDN) with a semantic mapping in `components/core/Icon.jsx` that mirrors `AppIcon`. Closest match to SF's filled, rounded style. Ask the user for exported SF Symbol SVGs for pixel-perfect production work.
- Icons sit in tinted chips: circle (38px, quick actions) or rounded-rect 12px (34–42px, library rows), glyph in the accent color over its 12% tint.
- **No logo exists in the repo** (empty app icon set). Render "GymTracker" in plain display type wherever a mark would go.

## Fonts

No font binaries ship with the repo (system fonts). `ui-rounded` / `-apple-system` stacks resolve to SF Rounded / SF Pro on Apple devices; elsewhere they fall back to the platform sans. **If you have licensed SF Pro/SF Rounded webfonts, add them** to `tokens/typography.css` via `@font-face`.

## Index

- `styles.css` → `tokens/` (colors, typography, spacing, radius, shadows, motion)
- `components/core/` — Icon, Button, Badge, SectionLabel, Card, IconChip
- `components/forms/` — SearchField, SegmentedControl, SetInput
- `components/lists/` — ListRow, HistoryRow
- `components/workout/` — SessionHeader, RestTimer, SetRow, ExerciseCard
- `components/navigation/` — TabBar
- `ui_kits/ios-app/` — interactive recreation: Home, Active Workout, Library, History
- `guidelines/` — foundation specimen cards
- `assets/screenshots/` — reference PNGs from the repo
- `SKILL.md` — agent skill entry point
- `ProductPivotAudit.md` — July 2026 pivot: current direction, implemented-vs-planned classification
- `guidelines/navigation-spec.md` — canonical post-pivot navigation architecture (planned)
- `guidelines/screen-inventory.md` — screen inventory (implemented/refined/new/later/deferred) + current & future sitemaps

## App flow (implemented)

Root = `TabView` (4 tabs), each in its own `NavigationStack`. The **Active Workout is root-owned**: a full-screen cover above the tabs, never inside a tab's stack.

- **Home** → state-driven card stack, by precedence: (1) Active workout exists → "Continue workout" hero (elapsed time, current exercise, set progress); (2) Planned workout due → "Today's Workout" + current program row; (3) Active program, nothing due → program context + free-workout CTA; (4) No program → free-workout + template quick actions. Starting anything opens the root Active Workout cover; starting while one is active shows a Resume / Discard & Start New conflict dialog.
- **Library** → landing shows exactly three categories: **Workouts** (templates; contains Folders), **Programs** (plans), **Exercises**. Drill-downs: Workouts → folder → workout detail → start; Programs → program detail (weeks, calendar, equipment) → start planned workout; Exercises → search/filters → exercise detail → insights / relationships / archived (Hidden Exercises).
- **History** → segmented **Workouts / Progress / Records**: Workouts → workout detail → planned-vs-performed comparison; Progress → trends + Muscle Balance; Records → PRs. Empty state offers "Start free workout".
- **Settings** → units, default rest timer, data export / import (preview → confirm replace), reset.
- **Active Workout cover** (from Home or Library) → exercise entry cards (current = blue stroke, completed = green-gray collapsed) → set rows → complete set → rest countdown (+ Live Activity) → progression recommendation (Accept / Keep last / Edit) → plate calculator & set-detail sheets → **Finish → Save review** (planned-vs-performed, notes, partial-save confirm) → saved to History, or Discard (confirmed) from anywhere.

### Future app flow — the post-pivot product (planned, not implemented)

One atomic migration ships the new IA with Nutrition wave 1: tabs become **Today / Train / Nutrition / Progress**; Settings moves to a gear on the Today header. The Active Workout stays root-owned above the tabs. **Canonical detail: `guidelines/navigation-spec.md`** (presentation rules, Today card contract, mini-player spec, TabRouter contract, cross-feature transitions, migration priority).

- **Today** (replaces Home) — the daily command surface: "what should I do and eat now?" At most one compact card per domain, each deep-linking to its owner tab, stacked by precedence:
  1. **Workout card** — same state model as today (continue → due planned workout → program context → free workout).
  2. **Nutrition card** — calories + protein/carbs/fat vs today's target (training-day vs rest-day aware); tap → Nutrition tab.
  3. **Journal card** — evening check-in prompt (mood, sleep quality, workout difficulty, one note); skippable, one entry/day.
  Today never embeds editors or calendars beyond the UpcomingCalendar week strip — it summarizes and links. Progression recommendations render inside the workout card's prescription line, never as a fourth card.
- **Train** (Library renamed, structure unchanged) — Workouts (+ Folders), Programs, Exercises. Later phases add: per-set prescription types (warm-up/AMRAP/top/back-off), reusable progression policies (percentage, Training Max, RPE/RIR, block), deload rules, a generic program library, and the AI plan assistant (Apple Intelligence phase 6) that drafts a program the user confirms.
- **Nutrition** (new) — today's food log by meal slot → fast add (search, recents, one-tap repeat of previous meals; wave 2: barcode scan, photo/natural-language entry with mandatory confirmation) → meal templates → targets editor (bulk/cut/maintenance phases, training-day vs rest-day). Wave 1 starts thin: macro targets + compliance-style log. Later: deterministic, explainable daily nutrition score (judges whole days, never foods).
- **Progress** (History renamed) — a filter-chip hub (not a 4-way segmented control): **Workouts / Charts / Records / Nutrition / Journal** chips; workout detail with planned-vs-performed; ActivityHeatmap + trends + muscle balance + e1RM; PRs; nutrition trends; journal timeline. Advanced wave: combined nutrition–training insights (observed correlations, never medical claims) and post-workout check-ins.
- **Cross-cutting** — evening check-in via one self-scheduled notification; Siri workout controls and natural workout search (Apple Intelligence phases 1–3); in-app AI summaries that suggest but never mutate truth; optional encrypted **iCloud vault sync** (off by default, last-write-wins with visible restore — the Pro paid anchor); full export + account deletion for the compliance-audited v1.0 (mid-2027).

**Effort rule** — RPE is a strength-set concept only. Stretches/mobility never show RPE: log **hold duration + felt intensity** (léger / modéré / profond, always "sans douleur"). Cardio uses effort zones (Zone 1–5 / talk test). Components (`SetRow`, `ExerciseCard`) take these as tracking-type-driven columns and notes. Source `TrackingType` cases: weight×reps, bodyweight, duration, duration+distance, calories. `SetType` badges: warmup, drop, failure, back-off, top set, AMRAP, technique, daily maximum, test, recovery.

Guardrails carried through every future surface: no fifth tab, journal never becomes a tab, prescriptions vs logged truth stay visually distinct, nothing auto-writes history, and the one-tap free workout must never gain friction.

## UI rules (binding — from the 82-screen audit)

Full rationale in `guidelines/ux-issues.md`, `guidelines/screen-critique.md`, and the refactor order in `guidelines/ui-refactor-plan.md`. Illustrated cards: Numbers & precision, Primary action, Copy discipline, Charts & insights, Flows & sheets.

1. **Numbers** — integer-first: kcal/grams integers, estimates ≈ nearest kg, loads in 0.5-kg steps, never trailing ".0".
2. **Primary action** — exactly one filled-blue pill per screen; actions never styled as list rows; disabled primaries say why inline; destructive never flush against primary.
3. **Copy** — each fact once per screen; empty states name the next step (never hollow zeros); pluralize units ("1 week"); "Bodyweight" / "Load not set", never "No load".
4. **Effort** — one editable metric (RPE or RIR) per exercise; the other read-only/derived. Stretch/mobility never shows RPE.
5. **Charts** — never color-only (tap-to-reveal or direct labels, ≤4 hues then "Other"); timelines never skip periods silently; every insight cites its evidence.
6. **Flows** — one shared sheet per job (reschedule); conflicts lead with the data-safe choice; import/restore states its effect on existing data; sheets opaque; folders styled distinctly from items.

## Intentional additions

- `Icon` wrapper (glyph substitution layer for SF Symbols) — needed on the web.
- `ActivityHeatmap` — GitHub-contributions-style training-consistency grid (Progress tab; sage-green level scale, never raw GitHub green).
- `UpcomingCalendar` — week strip of the next planned workouts (Today tab above the workout card; today = solid blue pill, planned = blue tint chip, trained past = sage check).
- `ComparisonPanel` — green-tinted "planned vs performed" panel with Met/Missed badge (Save review, History detail; per screenshot audit).
- `StatusRow` — plan-calendar day row using the app's canonical status vocabulary (completed/skipped/missed/in-progress/ready/scheduled).
- `RecommendationCard` — progression recommendation (blue trend eyebrow, plain-language rationale, Accept / Keep pills, Edit manually); suggestions only, logged weight always wins.
- `StepperRow` — iOS systemGrouped form-sheet row in three variants: stepper (−/+), picker (value + chevron), toggle (switch); program builder, template editor, deload, prescription sheets.

## Component inventory (from source)

Button styles (`GymPressButtonStyle`, capsule CTA, borderless text), icon chips, uppercase section labels, cards (`quickActionRow`, `LibraryCategoryRow`, `LibraryItemRow`, `RecentLibraryRow`, `HistoryWorkoutRow`), search field, segmented History tabs, set rows with numeric inputs, session header with progress, rest timer card, exercise entry card (current/completed states), week capsule badge, tab bar.
