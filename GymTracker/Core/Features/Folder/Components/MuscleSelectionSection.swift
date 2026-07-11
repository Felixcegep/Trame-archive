//
//  MuscleSelectionSection.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import SwiftUI

struct MuscleSelectionSection: View {
    let title: LocalizedStringKey
    let selectedMuscles: Set<Muscle>
    let onSelect: (Muscle) -> Void

    var body: some View {
        Section(title) {
            ForEach(Muscle.allCases, id: \.self) { muscle in
                SelectionRow(
                    title: muscle.displayName,
                    isSelected: selectedMuscles.contains(muscle)
                ) {
                    onSelect(muscle)
                }
            }
        }
    }
}
