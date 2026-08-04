//
//  ExerciseSeedData.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

enum ExerciseSeedData {
    static func templates() -> [Exercise] {
        let legacyTemplates = legacyTemplates()
        // Compare NORMALIZED names, not exact strings. The legacy catalogue
        // spells some movements without punctuation ("Pull Up") while
        // ExerciseCatalogSeedData spells the same movement hyphenated
        // ("Pull-Up"). An exact-string filter let both survive as separate
        // templates -- and because SystemSeedKey.make escapes a literal "-"
        // as "--", they didn't even collide on their derived seed key
        // ("exercise.pull-up" vs "exercise.pull--up"), so both got
        // installed as separate Exercise records with separate logged
        // history. Legacy wins ties: those are the records already living
        // in shipped users' stores with history attached (see
        // ExerciseSystemSeedInstaller.install, which adopts an existing
        // legacy-named Exercise into a seed key rather than replacing it),
        // so the imported catalogue entry is the one dropped here.
        let existingNames = Set(legacyTemplates.map { SystemSeedKey.normalizedComparisonKey($0.name) })
        let importedTemplates = ExerciseCatalogSeedData.templates().filter {
            !existingNames.contains(SystemSeedKey.normalizedComparisonKey($0.name))
        }
        return legacyTemplates + importedTemplates
    }

    private static func legacyTemplates() -> [Exercise] {
        pushTemplates() + pullTemplates() + legsTemplates() + otherTemplates()
    }
}
