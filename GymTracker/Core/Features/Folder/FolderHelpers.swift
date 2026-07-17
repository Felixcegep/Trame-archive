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

@discardableResult
func saveModelContext(_ modelContext: ModelContext) -> Bool {
    do {
        try modelContext.save()
        return true
    } catch {
        modelContext.rollback()
        print("Failed to save folder changes: \(error)")
        return false
    }
}
