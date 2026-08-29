# Trame Reference Artifacts

This directory is reserved for reviewed visual contracts. Do not add invented or placeholder screenshots. Captures must come from the deterministic screenshot workflow and be recorded in [`ScreenshotCoverage.md`](../../../ScreenshotCoverage.md).

## Canonical capture set

The intended visual contract covers:

- Today — Pale and Dark;
- Train;
- Workout Preview;
- Active Workout;
- Input Instrument;
- Rest;
- Mobility;
- Gyroscope;
- Progress Global;
- Powerlifting;
- Bodybuilding;
- Weightlifting;
- HYROX;
- Cardio.

Use the current `Screenshots/` paths and capture-scene names as the authoritative filenames. This manifest does not claim that a capture exists or is current. A new artifact is accepted only after the matching scene runs, the image is inspected, and `ScreenshotCoverage.md` records its status.

## Interaction research specimen

The noncanonical interaction research specimen is:

`/Users/felixlachapelle/Documents/redesign/Favorie/trame-theme-lab (1).html`

Reviewed source fingerprint:

```text
SHA-256 3612378085f78b52dfcfbbbc971506772edd2c5a8f2ad0821c2dc591273ce7cc
```

It contains earlier Performance Lab theme definitions plus older palette
experiments and later CSS overrides. Only `performance-dark` and
`performance-pale` represent production appearances; the other palette entries
are laboratory material, not user-selectable production themes. The current file
also remembers a local selection and otherwise initializes Pale, so its launch
state is not evidence of the production default.

Where an experimental override conflicts with the Trame Constitution or the
exact Performance Lab 2.0/2.1 contract in `Documentation/DesignSystem.md`, the
written contract wins until a sanitized in-repository specimen is reviewed. Use
the HTML to extract hierarchy, interaction flow, color occupancy, surface
language, and minimal-copy method while preserving native iOS behavior and the
project domain contract.

Known noncanonical experiments include appearance-dependent Today geometry and
unmapped abstract Progress marks. Production must preserve meaning-bearing
silhouettes across Pale and Dark, and no custom Progress form is approved until
it satisfies `DiagramGrammar.md` with a complete accessible equivalent.
