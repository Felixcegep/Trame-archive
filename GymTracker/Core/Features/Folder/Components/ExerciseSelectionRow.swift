//
//  ExerciseSelectionRow.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import SwiftUI

struct ExerciseSelectionRow: View {
    let exercise: ExerciceTemplate
    let isSelected: Bool
    let onSelect: () -> Void
    private let exerciseDetail: ExerciceDetailSnapshot

    init(exercise: ExerciceTemplate, isSelected: Bool, onSelect: @escaping () -> Void) {
        self.exercise = exercise
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.exerciseDetail = ExerciceDetailSnapshot(exercice: exercise)
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onSelect()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name)
                            .foregroundStyle(.primary)
                        Text(exercise.trackingType.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            NavigationLink {
                ExerciceView(exercice: exerciseDetail)
            } label: {
                Image(systemName: "info.circle")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
    }
}
