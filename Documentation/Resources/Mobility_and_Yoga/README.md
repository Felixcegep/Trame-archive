# Master Mobility, Yoga & High-Quality Exercise Database

This directory contains the machine-readable datasets, exports, and automated pipelines consolidating **Yoga Poses**, **Mobility & Stretching Routines**, and **High-Quality Illustrated Movements** from four key sources:

1. **Live Yoga API** ([`https://yoga-api-nzy4.onrender.com/v1/poses`](https://yoga-api-nzy4.onrender.com/v1/poses)) — 48 poses with Sanskrit/English names, benefits, SVG/PNG illustrations.
2. **Free Exercise DB (Stretching & Mobility)** ([`yuhonas/free-exercise-db`](https://github.com/yuhonas/free-exercise-db)) — 123 targeted stretching and joint mobility movements with step-by-step cues and dual-angle photography.
3. **RepDB High-Quality Dataset** ([`RepDB/exercise-dataset`](https://github.com/RepDB/exercise-dataset)) — 250 exercises with multi-lingual coaching (EN/DE/ES), MET energy expenditure values, and 512px WebP illustrations. *(Commercial in-app use permitted with attribution)*.
4. **Trame (GymTracker) Seeded Mobility** — 68 foundational mobility exercises across 8 specialized joint families (Hip, Spine, Shoulder, Ankle, Posterior Chain, Chest/Lat, Forearm/Wrist, Full Body).

---

## 📊 Dataset Catalog & Files

| Dataset | Records | Formats & Links | Description |
| :--- | :--- | :--- | :--- |
| **Master Mobility & Yoga Unified** | **255 Movements** | [Excel (.xlsx)](file:///Users/felixlachapelle/Desktop/GymTracker/Documentation/Resources/Mobility_and_Yoga/master_mobility_and_yoga_unified.xlsx)<br>[CSV (.csv)](file:///Users/felixlachapelle/Desktop/GymTracker/Documentation/Resources/Mobility_and_Yoga/master_mobility_and_yoga_unified.csv)<br>[JSON (.json)](file:///Users/felixlachapelle/Desktop/GymTracker/Documentation/Resources/Mobility_and_Yoga/master_mobility_and_yoga_unified.json) | Consolidated master database comparing Trame's seeded mobility with Yoga API, FreeDB stretches, and RepDB with multi-source attribution. |
| **Yoga Poses Database** | **48 Poses** | [Excel (.xlsx)](file:///Users/felixlachapelle/Desktop/GymTracker/Documentation/Resources/Mobility_and_Yoga/yoga_poses_all.xlsx)<br>[CSV (.csv)](file:///Users/felixlachapelle/Desktop/GymTracker/Documentation/Resources/Mobility_and_Yoga/yoga_poses_all.csv)<br>[JSON (.json)](file:///Users/felixlachapelle/Desktop/GymTracker/Documentation/Resources/Mobility_and_Yoga/yoga_poses_all.json) | Complete Sanskrit, English, benefits, descriptions, SVG vectors, and PNG artwork. |
| **FreeDB Stretching Database** | **123 Stretches** | [Excel (.xlsx)](file:///Users/felixlachapelle/Desktop/GymTracker/Documentation/Resources/Mobility_and_Yoga/free_exercise_db_stretching.xlsx)<br>[CSV (.csv)](file:///Users/felixlachapelle/Desktop/GymTracker/Documentation/Resources/Mobility_and_Yoga/free_exercise_db_stretching.csv)<br>[JSON (.json)](file:///Users/felixlachapelle/Desktop/GymTracker/Documentation/Resources/Mobility_and_Yoga/free_exercise_db_stretching.json) | Isolated stretching movements with primary/secondary muscle targets, equipment, and image URLs. |
| **RepDB Exercise Database** | **250 Exercises** | [Excel (.xlsx)](file:///Users/felixlachapelle/Desktop/GymTracker/Documentation/Resources/Mobility_and_Yoga/repdb_exercises_all.xlsx)<br>[CSV (.csv)](file:///Users/felixlachapelle/Desktop/GymTracker/Documentation/Resources/Mobility_and_Yoga/repdb_exercises_all.csv)<br>[JSON (.json)](file:///Users/felixlachapelle/Desktop/GymTracker/Documentation/Resources/Mobility_and_Yoga/repdb_exercises_all.json) | Multi-lingual instructions (EN/DE/ES), MET expenditure, mechanics, and WebP start/peak illustrations. |

---

## ⚖️ Legal & Attribution Policy

* **Yoga API**: Open-source MIT licensed API by Alex Cumplido.
* **Free Exercise DB**: Open Public Domain (Unlicense) exercise dataset by yuhonas.
* **RepDB Dataset**: Free for in-app commercial use provided credit is attributed to RepDB. (Included in export metadata).

---

## 🔄 Re-running & Updates

To re-fetch live data and refresh the mobility & yoga catalogs:

```bash
python3 Scripts/fetch_and_unify_mobility_yoga.py
```
