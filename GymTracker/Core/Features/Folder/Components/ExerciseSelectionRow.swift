//
//  ExerciseSelectionRow.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import SwiftUI

struct ExerciseSelectionRow: View {
    let exercise: Exercise
    let isSelected: Bool
    let onSelect: () -> Void
    let onShowDetail: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.s) {
            Button(action: onSelect) {
                HStack(alignment: .center, spacing: Spacing.m) {
                    Image(systemName: isSelected ? AppIcon.checkmarkCircle : AppIcon.circle)
                        .font(.system(size: 22))
                        .foregroundStyle(isSelected ? Color.gymSecondary : Color.gymText.opacity(0.25))

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(exercise.name)
                            .font(AppFont.bodyMedium)
                            .foregroundStyle(Color.gymText)
                            .multilineTextAlignment(.leading)
                        Text(exercise.subtitle)
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                            .multilineTextAlignment(.leading)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: Spacing.s)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("template-exercise-\(exercise.name)")
            .accessibilityLabel("\(isSelected ? "Remove" : "Add") \(exercise.name)")
            .accessibilityValue(isSelected ? "Selected" : "Not selected")

            Button(action: onShowDetail) {
                Image(systemName: AppIcon.info)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.gymPrimary)
                    .frame(width: 34, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("template-exercise-link-\(exercise.name)")
            .accessibilityLabel("Show details for \(exercise.name)")
        }
        .listRowBackground(isSelected ? Color.gymSecondarySurface : Color.gymCard)
    }
}
