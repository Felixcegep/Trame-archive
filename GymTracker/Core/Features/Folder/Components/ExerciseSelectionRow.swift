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
        HStack(alignment: .top, spacing: Spacing.s) {
            NavigationLink {
                ExerciceView(exercice: exerciseDetail)
            } label: {
                HStack(alignment: .top, spacing: Spacing.m) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(exercise.name)
                            .font(AppFont.bodyMedium)
                            .foregroundStyle(Color.gymText)
                            .multilineTextAlignment(.leading)
                        Text(exercise.subtitle)
                            .font(AppFont.caption)
                            .foregroundStyle(WorkoutPalette.subduedText)
                            .multilineTextAlignment(.leading)
                    }
                    .layoutPriority(1)
                    Spacer(minLength: Spacing.s)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("template-exercise-link-\(exercise.name)")

            Button {
                onSelect()
            } label: {
                Image(systemName: isSelected ? AppIcon.checkmarkCircle : AppIcon.plus)
                    .foregroundStyle(isSelected ? Color.gymSecondary : Color.gymPrimary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("template-exercise-\(exercise.name)")
            .accessibilityLabel("\(isSelected ? "Remove" : "Add") \(exercise.name)")
            .accessibilityValue(isSelected ? "Selected" : "Not selected")
        }
    }
}
