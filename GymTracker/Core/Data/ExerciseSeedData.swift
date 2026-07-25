//
//  ExerciseSeedData.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

enum ExerciseSeedData {
    static func templates() -> [Exercise] {
        let legacyTemplates = legacyTemplates()
        let existingNames = Set(legacyTemplates.map(\.name))
        let importedTemplates = ExerciseCatalogSeedData.templates().filter {
            !existingNames.contains($0.name)
        }
        return legacyTemplates + importedTemplates
    }

    private static func legacyTemplates() -> [Exercise] {
        pushTemplates() + pullTemplates() + legsTemplates() + otherTemplates()
    }
}
