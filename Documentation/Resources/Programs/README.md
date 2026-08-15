# Master Unified Workout & Mobility Programs Catalog

This directory contains the master unified database of **82 strength, hypertrophy, powerlifting, bodybuilding, calisthenics, conditioning, and mobility programs** combining **Trame (GymTracker)**'s core program engine and mobility plans with **Liftosaur**'s community and canonical routine library.

---

## 📊 Catalog Overview

- **Total Master Programs**: **82**
- **Overlapping / Shared Archetypes (`["trame", "liftosaur"]`)**: **6** (e.g., Foundation 5x5 / Starting Strength, Heavy-Light-Medium / Texas Method, Conjugate Rotation Wave / Westside Conjugate, RPE Bridge / Barbell Medicine Bridge, Tiered Stage Ladder / GZCLP, Wave Builder / General Gainz)
- **Trame Original Programs (`["trame"]`)**: **22** (21 core strength/conditioning plans + 7 specialized mobility protocols)
- **Liftosaur Programs (`["liftosaur"]`)**: **54** (nSuns, 5/3/1 BBB, Building the Monolith, PHUL, PHAT, GVT, Deep Water, Bullmastiff, Sheiko, Smolov, PPL variations, Tactical Barbell, etc.)

---

## 📁 Export Formats & Locations

| Resource | Format | Path / Clickable Link |
| :--- | :--- | :--- |
| **Styled Excel Spreadsheet** | `.xlsx` | [liftosaur_programs_all.xlsx](file:///Users/felixlachapelle/Desktop/GymTracker/Documentation/Resources/Programs/liftosaur_programs_all.xlsx) |
| **Standard CSV** | `.csv` | [liftosaur_programs_all.csv](file:///Users/felixlachapelle/Desktop/GymTracker/Documentation/Resources/Programs/liftosaur_programs_all.csv) |
| **Complete JSON Database** | `.json` | [liftosaur_programs_all.json (Doc)](file:///Users/felixlachapelle/Desktop/GymTracker/Documentation/Resources/Programs/liftosaur_programs_all.json)<br>[liftosaur_programs_all.json (App Resources)](file:///Users/felixlachapelle/Desktop/GymTracker/GymTracker/Resources/Programs/liftosaur_programs_all.json) |
| **Pipeline Script** | `.py` | [parse_liftosaur_programs.py](file:///Users/felixlachapelle/Desktop/GymTracker/Scripts/parse_liftosaur_programs.py) |

---

## 🧬 Program Schema & Metadata Attributes

Every program record includes:

1. **Identity & Origin**:
   - `name`: Canonical program title (e.g. `Foundation Barbell 5×5`, `GZCLP`, `5/3/1: Boring But Big`).
   - `slug`: Normalized slug identifier.
   - `sources`: `["trame", "liftosaur"]`, `["trame"]`, or `["liftosaur"]`.
   - `author`: Origin author (e.g., Cody Lefever, Jim Wendler, Mark Rippetoe, Trame Engine).
2. **Scheduling & Periodization**:
   - `days_per_week`: Workout frequency (e.g. `3 days/week`, `4 days/week`, `6 days/week`).
   - `duration_weeks`: Program block duration (e.g. `6 weeks`, `8 weeks`, `12 weeks`, `16 weeks`).
   - `difficulty`: `Beginner`, `Intermediate`, `Advanced`.
   - `category`: `Powerlifting / Strength`, `Hypertrophy / Bodybuilding`, `Calisthenics / Bodyweight`, `Mobility & Flexibility`, `Hybrid / Tactical Strength`.
   - `progression_model`: Linear Progression, Wave Periodization, Percentage Cycles, RPE Bridge, Double Progression, PNF Intervals, CARs End-Range Control.
3. **Execution & Daily Routine Structure**:
   - `routines_summary`: High-level session overview.
   - `days_structure`: Detailed day-by-day workout breakdown with daily exercise prescriptions.
   - `equipment`: `Barbell / Gym`, `Dumbbell`, `Bodyweight / Mat`, `Yoga Blocks`, `Foam Roller / Band`.
   - `tags`: Filterable category and target tags.
   - `url`: Direct link to original Liftosaur documentation (when applicable).
   - `image_url`: Canonical program artwork URL.

---

## 🔄 Re-running & Updates

To re-fetch live program definitions and regenerate the unified datasets:

```bash
python3 Scripts/parse_liftosaur_programs.py
```
