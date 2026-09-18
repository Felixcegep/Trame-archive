# Unified Exercise Database & Taxonomy (Trame + Liftosaur)

This directory contains the master unified exercise catalog, structured database exports, and update automation scripts combining **Trame (GymTracker)**'s core biomechanical schema with **Liftosaur**'s anatomical cues, instructions, and video references.

## 📊 Catalog Overview

- **Total Unique Exercises**: 474
- **Exercises in BOTH (`["trame", "liftosaur"]`)**: 240
- **Trame Core Exercises (`["trame"]`)**: 21
- **Liftosaur Extended Exercises (`["liftosaur"]`)**: 213
- **Integrity**: 100% Unique canonical names and deterministic `seed_key` identifiers (`exercise.<slug>`).

---

## 📁 Export Files

| Resource | Format | Description |
| :--- | :--- | :--- |
| [`liftosaur_exercises_all.xlsx`](file:///Users/felixlachapelle/Desktop/GymTracker/Documentation/Resources/Exercises/liftosaur_exercises_all.xlsx) | Styled Excel (.xlsx) | Formatted workbook with dark slate header, zebra row striping, top alignment, text wrapping, and optimized column widths across 35 columns. |
| [`liftosaur_exercises_all.csv`](file:///Users/felixlachapelle/Desktop/GymTracker/Documentation/Resources/Exercises/liftosaur_exercises_all.csv) | Standard CSV (.csv) | UTF-8 encoded table ready for Google Sheets, Apple Numbers, database migration, or analytics scripts. |
| [`liftosaur_exercises_all.json`](file:///Users/felixlachapelle/Desktop/GymTracker/Documentation/Resources/Exercises/liftosaur_exercises_all.json) | Structured JSON (.json) | Full hierarchical JSON database with structured steps, anatomical muscle mappings, relationship graph, and app metadata. Also mirrored in [App Resources](file:///Users/felixlachapelle/Desktop/GymTracker/GymTracker/Resources/Exercises/liftosaur_exercises_all.json). |
| [`parse_liftosaur.py`](file:///Users/felixlachapelle/Desktop/GymTracker/Scripts/parse_liftosaur.py) | Python 3 Pipeline (.py) | Scraper and catalog merge script that syncs live data from Liftosaur with Trame's SwiftData seed definitions. |

---

## 🧬 Complete Data Schema & Parameters

Every entry in the unified catalog includes:

### 1. Identity & Provenance
* `name` *(String)*: Unique canonical exercise name (e.g. `Bench Press`, `Incline Dumbbell Bench Press`).
* `seed_key` *(String)*: Deterministic slugified seed key matching Trame's `SystemSeedKey` (e.g. `exercise.bench-press`).
* `sources` *(Array of Strings)*: Source provenance — `["trame", "liftosaur"]` for overlapping entries, `["trame"]` for Trame core, `["liftosaur"]` for Liftosaur additions.
* `french_name` *(String or null)*: French localized exercise name (e.g. `Développé couché`).
* `search_aliases` *(Array of Strings)*: Search synonyms, alternative spellings, and acronyms (e.g. `["bench", "chest press"]`).

### 2. Biomechanics & Classification
* `category` *(String)*: `Strength`, `Cardio`, `Mobility`, `Flexibility`, `Balance`, `Sport`, or `Other`.
* `tracking_type` *(String)*: `Weight & Reps`, `Reps Only`, `Weighted Bodyweight`, `Assisted Bodyweight`, `Duration`, `Duration & Distance`, `Calories`.
* `equipment` *(String)*: `Barbell`, `Dumbbell`, `Kettlebell`, `Cable`, `Machine`, `Bodyweight`, `Medicine Ball`, `Cardio Machine`, `Other`.
* `resistance_type` *(String)*: `External Weight`, `Bodyweight`, `Assisted Bodyweight`, `Weighted Bodyweight`, `Elastic`, `Machine`, `None`, `Other`.
* `movement_pattern` *(String)*: `Horizontal Push`, `Vertical Push`, `Horizontal Pull`, `Vertical Pull`, `Squat`, `Hinge`, `Lunge`, `Carry`, `Rotation`, `Anti-Rotation`, `Anti-Extension`, `Anti-Lateral Flexion`, `Locomotion`, `Other`.
* `force_type` *(String)*: `Push`, `Pull`, `Static`, `Mixed`.
* `mechanics` *(String)*: `Compound` or `Isolation`.
* `laterality` *(String)*: `Bilateral` or `Unilateral`.
* `difficulty` *(String)*: `Beginner`, `Intermediate`, `Advanced`.
* `grip_style` *(String or null)*: `Pronated`, `Supinated`, `Neutral`, `Mixed`.
* `stance` *(String or null)*: `Standing`, `Seated`, `Kneeling`, `Split`, `Staggered`, `Supine`, `Prone`.
* `range_of_motion` *(String or null)*: `Full`, `Partial`, `Extended`.
* `setup_angle_degrees` *(Int or null)*: Bench or incline angle (e.g. `0`, `30`, `45`, `90`).
* `is_plate_loaded` *(Boolean)*: `true` if weight plates are loaded on barbell/machine.

### 3. Loading & Sport Discipline
* `rep_counting_style` *(String)*: `Total` or `Per Side`.
* `weight_entry_style` *(String)*: `Total Load`, `Per Load Unit`, `Bodyweight Plus Additional`.
* `load_unit_count` *(Int)*: `1` (barbell/machine) or `2` (dumbbells).
* `sport_discipline` *(String or null)*: `powerlifting`, `weightlifting`, `crossTraining`, `strongman`, `calisthenics`, `running`, `cycling`, `rowing`.
* `strongman_event_family` *(String or null)*: Event category for strongman lifts.
* `variation_family_id` *(String or null)*: Movement cluster identifier (e.g. `bench-press`, `back-squat`).
* `tags` *(Array of Strings)*: Search and filter tags.

### 4. Muscle Anatomy
* `primary_muscles` *(Array of Strings)*: Target muscle enum cases (`middleChest`, `quadriceps`, `latissimusDorsi`, etc.).
* `secondary_muscles` *(Array of Strings)*: Assisting muscle enum cases (`frontDeltoid`, `tricepLateralHead`, etc.).
* `muscle_groups` *(Array of Strings)*: High-level muscle groups (`Chest`, `Arms`, `Shoulders`, `Back`, `Core`, `Glutes`, `Legs`, `Other Muscles`).
* `target_muscles_anatomical` *(Array of Strings)*: Detailed anatomical agonist muscles.
* `synergist_muscles_anatomical` *(Array of Strings)*: Detailed anatomical synergist / stabilizer muscles.

### 5. Graph Relationships & Execution Coaching
* `substitutions` *(Array of Strings)*: Interchangeable exercise alternatives.
* `progressions` *(Array of Strings)*: Harder progressive variations.
* `regressions` *(Array of Strings)*: Easier regressive variations.
* `description` *(String)*: Biomechanical and performance overview.
* `instructions` *(Array of Step Objects)*: Step-by-step coaching cues (`[{"step": 1, "title": "...", "text": "..."}]`).
* `video_url` *(String)*: Standard YouTube demonstration URL.
* `video_embed_url` *(String)*: Embeddable iframe YouTube URL.
* `video_thumbnail` *(String)*: High-resolution video thumbnail image URL.
* `image_url` *(String)*: Anatomical diagram / OpenGraph image URL.
* `liftosaur_url` *(String)*: Source reference URL on Liftosaur.
* `liftosaur_slug` *(String)*: Source slug on Liftosaur.

---

## 🔄 Regeneration Script

To re-run the merge and update all files at any time:

```bash
# Re-run Trame catalog merge with current data
python3 Scripts/parse_liftosaur.py

# Or perform a fresh live scrape from Liftosaur and merge
python3 Scripts/parse_liftosaur.py --scrape
```
