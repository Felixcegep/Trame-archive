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
        HStack(spacing: Spacing.s) {
            Button {
                onSelect()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name)
                            .font(AppFont.bodyMedium)
                            .foregroundStyle(Color.gymText)
                        Text(LocalizedStringKey(exercise.trackingType.rawValue))
                            .font(AppFont.caption)
                            .foregroundStyle(WorkoutPalette.subduedText)
                    }

                    Spacer()

                    Image(systemName: isSelected ? AppIcon.checkmarkCircle : AppIcon.plus)
                        .foregroundStyle(isSelected ? Color.gymSecondary : Color.gymPrimary)
                        .frame(width: 44, height: 44)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("template-exercise-\(exercise.name)")
            .accessibilityLabel("\(isSelected ? "Remove" : "Add") \(exercise.name)")
            .accessibilityValue(isSelected ? "Selected" : "Not selected")

            NavigationLink {
                ExerciceView(exercice: exerciseDetail)
            } label: {
                Image(systemName: AppIcon.info)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
    }
}
