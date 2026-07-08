//
//  FolderHelpers.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import SwiftData

func toggle(_ value: String, in selection: inout Set<String>) {
    if selection.contains(value) {
        selection.remove(value)
    } else {
        selection.insert(value)
    }
}

func saveModelContext(_ modelContext: ModelContext) {
    do {
        try modelContext.save()
    } catch {
        print("Failed to save folder changes: \(error)")
    }
}
