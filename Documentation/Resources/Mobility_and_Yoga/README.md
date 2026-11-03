# Mobility catalogue

The bundled [unified catalogue](master_mobility_and_yoga_unified.json) contains 188 mobility entries from Trame's authored seeds and [Free Exercise DB](https://github.com/yuhonas/free-exercise-db). The app uses the matching JSON in `GymTracker/Resources/Mobility/`.

The previous RepDB and Yoga API datasets and image links are no longer bundled. Two previously mixed-source entries were rebuilt from Free Exercise DB, including its distinct exercise-ball Pyramid. Existing on-device records are not deleted by this change. Free Exercise DB publishes its dataset under the Unlicense.

The export script `Scripts/fetch_and_unify_mobility_yoga.py` can regenerate the unified JSON and optional spreadsheet exports from the remaining sources. Live upstream content may change the number of entries produced.
