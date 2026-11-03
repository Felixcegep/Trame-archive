# Mobility and yoga datasets

The bundled [unified catalogue](master_mobility_and_yoga_unified.json) contains 234 mobility and yoga entries assembled from Trame's authored seeds, the [Yoga API](https://github.com/alexcumplido/yoga-api), and [Free Exercise DB](https://github.com/yuhonas/free-exercise-db). The app uses the matching JSON in `GymTracker/Resources/Mobility/`.

RepDB data is excluded from the bundled catalogue and from the export pipeline. The 21 entries sourced only from RepDB are no longer bundled; three overlapping entries retain their independent Yoga API or Free Exercise DB data. Existing on-device records are not deleted by this change.

The Yoga API's code is MIT-licensed, while its image assets have separate terms and attribution requirements; consult its repository before using those assets. Free Exercise DB publishes its data under the Unlicense. Verify the rights for each asset and source before redistribution.

The export script `Scripts/fetch_and_unify_mobility_yoga.py` can generate the unified JSON and optional spreadsheet exports from its remaining sources.
