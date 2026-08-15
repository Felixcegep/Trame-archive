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
                        .font(AppFont.titleSmall)
                        .foregroundStyle(isSelected ? Color.trameCompleted : Color.trameSubdued)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(exercise.name)
                            .font(AppFont.bodyMedium)
                            .foregroundStyle(Color.trameText)
                            .multilineTextAlignment(.leading)
                        Text(exercise.subtitle)
                            .font(AppFont.metadata)
                            .foregroundStyle(Color.trameSubdued)
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
                    .font(AppFont.headline)
                    .foregroundStyle(Color.trameStrength)
                    .frame(width: 34, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("template-exercise-link-\(exercise.name)")
            .accessibilityLabel("Show details for \(exercise.name)")
        }
        .listRowBackground(isSelected ? Color.trameCurrent : Color.trameSurface)
    }
}
