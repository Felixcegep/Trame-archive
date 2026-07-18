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

enum RIRScale {
    static func meaning(for value: Int) -> String {
        switch value {
        case 0: String(localized: "No reps left")
        case 1: String(localized: "One rep left")
        case 2: String(localized: "Two reps left")
        default: String(localized: "At least \(value) reps left")
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
        case .topSet: "arrow.up"
        case .amrap: "infinity"
        case .technique: "figure.strengthtraining.traditional"
        case .dailyMaximum: "crown"
        case .test: "checkmark.seal"
        case .recovery: "heart"
        }
    }

    /// Accent used for the row chip and selection state; nil means the
    /// neutral text color (normal sets).
    var accentColor: Color? {
        switch self {
        case .normal: nil
        case .warmup: Color.gymAccent
        case .dropSet: Color.gymPrimary
        case .failure: Color.gymDestructive
        case .backoff: Color.gymSecondary
        case .topSet: Color.gymPrimary
        case .amrap: Color.gymAccent
        case .technique: Color.gymSecondary
        case .dailyMaximum: Color.gymPrimary
        case .test: Color.gymAccent
        case .recovery: Color.gymSecondary
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
            rirSection
            liftQualitySection
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
                    .foregroundStyle(Color.gymSubduedText)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .font(AppFont.subheadlineSemibold)
            .foregroundStyle(Color.gymPrimary)
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
        let accent = type.accentColor ?? Color.gymPrimary

        return Button {
            exerciseSet.setType = type
            onPersist()
        } label: {
            Label(type.title, systemImage: type.icon)
                .font(AppFont.footnoteMedium)
                .lineLimit(1)
                .foregroundStyle(isSelected ? accent : Color.gymSubduedText)
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
                    .foregroundStyle(Color.gymPrimary)
                    .accessibilityLabel("Clear RPE")
                    .accessibilityIdentifier("clear-rpe")
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text(exerciseSet.rpe.map { "\($0)" } ?? "—")
                    .font(AppFont.displayMedium)
                    .monospacedDigit()
                    .foregroundStyle(exerciseSet.rpe == nil ? Color.gymSubduedText : Color.gymText)
                    .contentTransition(.numericText())

                Text(rpeMeaning)
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymSubduedText)
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
            .tint(Color.gymPrimary)
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

    private var rirSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                eyebrow("Reps in reserve · RIR")
                Spacer()
                if exerciseSet.rir != nil {
                    Button("Clear") {
                        exerciseSet.rir = nil
                        onPersist()
                    }
                    .font(AppFont.footnoteMedium)
                    .foregroundStyle(Color.gymPrimary)
                    .accessibilityLabel("Clear RIR")
                    .accessibilityIdentifier("clear-rir")
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text(exerciseSet.rir.map { "\($0)" } ?? "—")
                    .font(AppFont.displayMedium)
                    .monospacedDigit()
                    .foregroundStyle(exerciseSet.rir == nil ? Color.gymSubduedText : Color.gymText)
                    .contentTransition(.numericText())
                Text(rirMeaning)
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymSubduedText)
            }
            .animation(reduceMotion ? nil : AppMotion.compact, value: exerciseSet.rir)

            Slider(
                value: Binding(
                    get: { Double(exerciseSet.rir ?? 2) },
                    set: {
                        exerciseSet.rir = Int($0.rounded())
                        onPersist()
                    }
                ),
                in: 0...6,
                step: 1
            ) {
                Text("RIR")
            } minimumValueLabel: {
                sliderBound("0")
            } maximumValueLabel: {
                sliderBound("6+")
            }
            .tint(Color.gymSecondary)
            .accessibilityIdentifier("rir-slider")
        }
        .padding(Spacing.l)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.section))
    }

    private var rirMeaning: String {
        guard let rir = exerciseSet.rir else {
            return String(localized: "Slide to record reps left after this set")
        }
        return RIRScale.meaning(for: rir)
    }

    private var liftQualitySection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                eyebrow("Lift quality")
                Spacer()
                if exerciseSet.liftQuality != nil {
                    Button("Clear") {
                        exerciseSet.liftQuality = nil
                        onPersist()
                    }
                    .font(AppFont.footnoteMedium)
                    .foregroundStyle(Color.gymPrimary)
                    .accessibilityLabel("Clear lift quality")
                    .accessibilityIdentifier("clear-lift-quality")
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: Spacing.s)], spacing: Spacing.s) {
                ForEach(LiftQuality.allCases, id: \.self) { quality in
                    Button {
                        exerciseSet.liftQuality = quality
                        onPersist()
                    } label: {
                        Text(quality.title)
                            .font(AppFont.footnoteMedium)
                            .foregroundStyle(exerciseSet.liftQuality == quality ? Color.gymText : Color.gymSubduedText)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(exerciseSet.liftQuality == quality ? Color.gymPrimary.opacity(0.14) : Color.gymCard)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                                    .strokeBorder(exerciseSet.liftQuality == quality ? Color.gymPrimary.opacity(0.5) : .clear, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(exerciseSet.liftQuality == quality ? .isSelected : [])
                    .accessibilityIdentifier("lift-quality-\(quality.rawValue)")
                }
            }
        }
        .padding(Spacing.l)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.section))
    }

    private func sliderBound(_ text: String) -> some View {
        Text(text)
            .font(AppFont.captionSemiboldMonospaced)
            .foregroundStyle(Color.gymSubduedText)
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
            .foregroundStyle(Color.gymSubduedText)
    }
}
