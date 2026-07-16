//
//  SetDetailSheet.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-12.
//

import SwiftUI
import SwiftData

/// Plain-language meaning of each RPE value, shown alongside the slider so
/// lifters don't need to memorize the scale.
enum RPEScale {
    static func meaning(for value: Int) -> String {
        switch value {
        case 10: String(localized: "Max effort — nothing left")
        case 9: String(localized: "Could do 1 more rep")
        case 8: String(localized: "Could do 2 more reps")
        case 7: String(localized: "Could do 3 more reps")
        case 6: String(localized: "Could do 4 more reps")
        case 5: String(localized: "Could do 5+ more reps")
        default: String(localized: "Very light — warm-up effort")
        }
    }
}

extension SetType {
    var icon: String {
        switch self {
        case .normal: AppIcon.circle
        case .warmup: AppIcon.warmup
        case .dropSet: "arrow.down.right"
        case .failure: "bolt.fill"
        case .backoff: "arrow.uturn.down"
        }
    }

    /// Accent used for the row chip and selection state; nil means the
    /// neutral text color (normal sets).
    var accentColor: Color? {
        switch self {
        case .normal: nil
        case .warmup: WorkoutPalette.accent
        case .dropSet: WorkoutPalette.primary
        case .failure: Color.gymDestructive
        case .backoff: WorkoutPalette.secondary
        }
    }
}

struct SetDetailSheet: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let index: Int
    @Bindable var exerciseSet: ExerciseSet
    let exerciseName: String
    let onPersist: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            header
            setTypeSection
            rpeSection
            Spacer(minLength: 0)
            deleteButton
        }
        .padding(.horizontal, Spacing.l)
        .padding(.top, Spacing.xl)
        .padding(.bottom, Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gymBackground)
        .overlay(alignment: .topLeading) {
            screenshotStateMarker("set-details-screen", label: "Set details open")
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Set \(index + 1)")
                    .font(AppFont.titleSmall)
                    .foregroundStyle(Color.gymText)
                Text(exerciseName)
                    .font(AppFont.subheadline)
                    .foregroundStyle(WorkoutPalette.subduedText)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .font(AppFont.subheadlineSemibold)
            .foregroundStyle(WorkoutPalette.primary)
            .accessibilityIdentifier("close-set-details")
        }
    }

    private var setTypeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            eyebrow("Set type")

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 104), spacing: Spacing.s)],
                alignment: .leading,
                spacing: Spacing.s
            ) {
                ForEach(SetType.allCases, id: \.self) { type in
                    setTypeChip(type)
                }
            }
        }
    }

    private func setTypeChip(_ type: SetType) -> some View {
        let isSelected = exerciseSet.setType == type
        let accent = type.accentColor ?? WorkoutPalette.primary

        return Button {
            exerciseSet.setType = type
            onPersist()
        } label: {
            Label(type.title, systemImage: type.icon)
                .font(AppFont.footnoteMedium)
                .lineLimit(1)
                .foregroundStyle(isSelected ? accent : WorkoutPalette.subduedText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(isSelected ? accent.opacity(0.14) : Color.gymCard)
                .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                        .strokeBorder(isSelected ? accent.opacity(0.5) : .clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("set-type-option-\(type.rawValue)")
    }

    private var rpeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                eyebrow("Effort · RPE")
                Spacer()
                if exerciseSet.rpe != nil {
                    Button("Clear") {
                        exerciseSet.rpe = nil
                        onPersist()
                    }
                    .font(AppFont.footnoteMedium)
                    .foregroundStyle(WorkoutPalette.primary)
                    .accessibilityLabel("Clear RPE")
                    .accessibilityIdentifier("clear-rpe")
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text(exerciseSet.rpe.map { "\($0)" } ?? "—")
                    .font(AppFont.displayMedium)
                    .monospacedDigit()
                    .foregroundStyle(exerciseSet.rpe == nil ? WorkoutPalette.subduedText : Color.gymText)
                    .contentTransition(.numericText())

                Text(rpeMeaning)
                    .font(AppFont.subheadline)
                    .foregroundStyle(WorkoutPalette.subduedText)
            }
            .animation(reduceMotion ? nil : AppMotion.compact, value: exerciseSet.rpe)

            Slider(
                value: Binding(
                    get: { Double(exerciseSet.rpe ?? 7) },
                    set: {
                        exerciseSet.rpe = Int($0.rounded())
                        onPersist()
                    }
                ),
                in: 1...10,
                step: 1
            ) {
                Text("RPE")
            } minimumValueLabel: {
                sliderBound("1")
            } maximumValueLabel: {
                sliderBound("10")
            }
            .tint(WorkoutPalette.primary)
            .accessibilityIdentifier("rpe-slider")
        }
        .padding(Spacing.l)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.section))
    }

    private var rpeMeaning: String {
        guard let rpe = exerciseSet.rpe else {
            return String(localized: "Slide to rate how hard this set felt")
        }
        return RPEScale.meaning(for: rpe)
    }

    private func sliderBound(_ text: String) -> some View {
        Text(text)
            .font(AppFont.captionSemiboldMonospaced)
            .foregroundStyle(WorkoutPalette.subduedText)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            dismiss()
            onDelete()
        } label: {
            Label("Delete set", systemImage: AppIcon.trash)
                .font(AppFont.subheadlineSemibold)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(Color.gymDestructive)
        .accessibilityIdentifier("delete-set-\(exerciseName)-\(index)")
    }

    private func eyebrow(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(AppFont.caption2Bold)
            .textCase(.uppercase)
            .tracking(0.55)
            .foregroundStyle(WorkoutPalette.subduedText)
    }
}
