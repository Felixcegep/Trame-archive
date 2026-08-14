# Exercise Resources & External Catalog Datasets

This directory contains external reference datasets, structured databases, and scraping tools for exercise information and taxonomy.

## Available Files

| Resource | Format | Description |
| :--- | :--- | :--- |
| [`liftosaur_exercises_all.xlsx`](file:///Users/felixlachapelle/Desktop/GymTracker/Documentation/Resources/Exercises/liftosaur_exercises_all.xlsx) | Styled Excel (.xlsx) | Formatted workbook with dark header bar, zebra row highlighting, vertical top-alignment, text wrapping, and optimized column widths. |
| [`liftosaur_exercises_all.csv`](file:///Users/felixlachapelle/Desktop/GymTracker/Documentation/Resources/Exercises/liftosaur_exercises_all.csv) | Standard CSV (.csv) | UTF-8 encoded table ready for Google Sheets, Apple Numbers, database ingestion, or automated scripts. |
| [`liftosaur_exercises_all.json`](file:///Users/felixlachapelle/Desktop/GymTracker/Documentation/Resources/Exercises/liftosaur_exercises_all.json) | Structured JSON (.json) | Complete database of 364 exercises with detailed steps, video embeds, thumbnails, primary/target/synergist muscles, equipment, and descriptions. |
| [`parse_liftosaur.py`](file:///Users/felixlachapelle/Desktop/GymTracker/Scripts/parse_liftosaur.py) | Python 3 Script (.py) | Multi-threaded scraping pipeline that extracts exercise metadata, instructions, and video links from Liftosaur with automatic retries and Excel/CSV/JSON formatting. |

## Data Schema & Metadata Fields

Each exercise entry in [`liftosaur_exercises_all.json`](file:///Users/felixlachapelle/Desktop/GymTracker/Documentation/Resources/Exercises/liftosaur_exercises_all.json) and [`liftosaur_exercises_all.csv`](file:///Users/felixlachapelle/Desktop/GymTracker/Documentation/Resources/Exercises/liftosaur_exercises_all.csv) contains:

- `name` *(String)*: Canonical name of the exercise (e.g., `Ab Wheel`, `Barbell Squat`).
- `equipment` *(String)*: Required equipment category (e.g., `Bodyweight`, `Barbell`, `Dumbbell`, `Cable`, `Machine`).
- `url` *(String)*: Source documentation URL.
- `slug` *(String)*: Normalized identifier slug.
- `description` *(String)*: Summary of biomechanics, targeted muscles, and movement overview.
- `video_url` *(String)*: Standard YouTube demonstration URL.
- `video_embed_url` *(String)*: Embeddable iframe YouTube URL.
- `video_thumbnail` *(String)*: High-resolution video thumbnail image URL.
- `image_url` *(String)*: OpenGraph anatomical exercise illustration image URL.
- `muscle_group_types` *(Array of Strings)*: High-level muscle groups (e.g., `Core`, `Legs`, `Push`, `Pull`).
- `muscle_group_targets` *(Array of Strings)*: Primary muscle regions (e.g., `Abs`, `Chest`, `Lats`, `Quadriceps`).
- `muscle_group_synergists` *(Array of Strings)*: Secondary / assisting muscle regions.
- `target_muscles` *(Array of Strings)*: Anatomical target muscles (e.g., `Iliopsoas`, `Rectus Abdominis`, `Pectoralis Major`).
- `synergist_muscles` *(Array of Strings)*: Anatomical synergist and stabilizer muscles.
- `steps` *(Array of Step Objects)*: Ordered execution instructions containing:
  - `step`: Integer sequence (1, 2, 3, ...).
  - `title`: Short phase title (e.g., *Start in the Kneeling Position*, *Engage Your Core*).
  - `text`: Specific coaching cues and execution mechanics.

## Regeneration & Updates

To re-fetch or update the datasets from source:

```bash
python3 Scripts/parse_liftosaur.py
```
