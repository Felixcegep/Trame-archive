import SwiftData
import SwiftUI

struct SetRowSecondaryContent: View {
    let index: Int
    @Bindable var exerciseSet: ExerciseSet
    let exerciseEntry: ExerciseEntry
    let viewModel: ActiveWorkoutViewModel
    let coordinator: SetInputCoordinator
    let previousSet: PreviousSetPerformance?
    let isCurrentSet: Bool
    @Binding var completionValidationMessage: String?
    @Binding var isTimerRunning: Bool
    @Binding var isShowingSetDetails: Bool

    private var trackingType: TrackingType {
        exerciseEntry.trackingTypeSnapshot
    }

    var body: some View {
        Group {
            if !exerciseSet.orderedComplexComponents.isEmpty {
                ComplexComponentResultsView(
                    components: exerciseSet.orderedComplexComponents,
                    onChange: updateComplexComponentResults
                )
                .padding(.leading, 45)
            }

            if let notes = exerciseSet.prescriptionNotes,
               notes.hasPrefix("Complex:") {
                Text(notes)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                    .padding(.leading, 45)
                    .accessibilityLabel(notes)
            }

            if isDailyMaximum, exerciseSet.done {
                dailyMaximumButton
            }

            if let tempo = exerciseSet.prescribedTempo,
               !tempo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Tempo \(tempo)")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                    .padding(.leading, 45)
                    .accessibilityLabel("Prescribed tempo \(tempo)")
            }

            if trackingType.usesDuration, !exerciseSet.done {
                SetDurationCountdownView(
                    index: index,
                    exerciseSet: exerciseSet,
                    exerciseEntry: exerciseEntry,
                    viewModel: viewModel,
                    coordinator: coordinator,
                    completionValidationMessage: $completionValidationMessage,
                    isTimerRunning: $isTimerRunning
                )
            }

            if let completionValidationMessage {
                Text(completionValidationMessage)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymAccent)
                    .padding(.leading, 45)
                    .accessibilityLabel(completionValidationMessage)
            }

            if let previousSet, !exerciseSet.done, isCurrentSet {
                previousSetButton(previousSet)
            }

            effortButton
        }
    }

    private var dailyMaximumButton: some View {
        Button {
            viewModel.selectDailyMaximum(exerciseSet, in: exerciseEntry)
        } label: {
            Label(
                exerciseSet.isSelectedDailyMaximum ? "Daily maximum selected" : "Use as daily maximum",
                systemImage: exerciseSet.isSelectedDailyMaximum ? AppIcon.checkmarkCircle : AppIcon.circle
            )
            .font(AppFont.caption)
            .foregroundStyle(exerciseSet.isSelectedDailyMaximum ? Color.gymSecondary : Color.gymPrimary)
            .frame(minHeight: 44)
        }
        .buttonStyle(.borderless)
        .padding(.leading, 45)
        .accessibilityLabel(exerciseSet.isSelectedDailyMaximum ? "Selected daily maximum" : "Use this attempt as the daily maximum")
        .accessibilityHint("Derived back-off sets use the selected attempt.")
        .accessibilityIdentifier("select-daily-maximum-\(exerciseEntry.exercise.name)-\(index)")
    }

    private func previousSetButton(_ previousSet: PreviousSetPerformance) -> some View {
        Button {
            viewModel.applyPreviousPerformance(to: exerciseSet, in: exerciseEntry, index: index)
            coordinator.focus = SetInputFocus(
                exerciseID: exerciseEntry.persistentModelID,
                setID: exerciseSet.persistentModelID,
                field: firstInputField
            )
        } label: {
            Label("Use last time · \(previousSetText(previousSet))", systemImage: AppIcon.copy)
                .font(AppFont.footnoteMedium)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .foregroundStyle(Color.gymPrimary)
        .accessibilityLabel("Use last time values for set \(index + 1)")
        .accessibilityIdentifier("copy-previous-set-\(exerciseEntry.exercise.name)-\(index)")
    }

    @ViewBuilder
    private var effortButton: some View {
        if let rpe = exerciseSet.rpe {
            let formattedRPE = Formatters.formatFloat(Float(rpe))
            Button {
                isShowingSetDetails = true
            } label: {
                Text("RPE \(formattedRPE) · \(RPEScale.meaning(for: rpe))")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
            .buttonStyle(.borderless)
            .padding(.leading, 45)
            .accessibilityLabel("RPE \(formattedRPE), \(RPEScale.meaning(for: rpe))")
            .accessibilityHint("Edit set details")
            .accessibilityIdentifier("rpe-badge-\(exerciseEntry.exercise.name)-\(index)")
        } else if let rir = exerciseSet.rir {
            Button {
                isShowingSetDetails = true
            } label: {
                Text("RIR \(rir) · \(RIRScale.meaning(for: rir))")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
            .buttonStyle(.borderless)
            .padding(.leading, 45)
            .accessibilityLabel("RIR \(rir), \(RIRScale.meaning(for: rir))")
            .accessibilityHint("Edit set details")
            .accessibilityIdentifier("rir-badge-\(exerciseEntry.exercise.name)-\(index)")
        }
    }

    private var isDailyMaximum: Bool {
        exerciseSet.prescribedSetType == .dailyMaximum || exerciseSet.setType == .dailyMaximum
    }

    private var firstInputField: SetInputFocus.Field {
        if trackingType.usesReps { return .repetitions }
        if trackingType.usesWeight { return .weight }
        if trackingType.usesDuration { return .duration }
        if trackingType.usesDistance { return .distance }
        return .calories
    }

    private func updateComplexComponentResults() {
        exerciseSet.liftQuality = exerciseSet.orderedComplexComponents.contains(where: { $0.outcome == .missed }) ? .missed : nil
        viewModel.persistChanges()
    }

    private func previousSetText(_ previousSet: PreviousSetPerformance) -> String {
        if trackingType.usesWeight {
            return "\(Formatters.formatFloat(previousSet.repetitions)) × \(Formatters.formatFloat(displayWeight(for: previousSet))) \(exerciseSet.weightType.rawValue)"
        }
        if trackingType.usesDuration {
            return "\(Int(previousSet.duration ?? 0)) sec"
        }
        if trackingType.usesCalories {
            return "\(Formatters.formatFloat(Float(previousSet.calories ?? 0))) cal"
        }
        return "\(Formatters.formatFloat(previousSet.repetitions)) reps"
    }

    private func displayWeight(for previousSet: PreviousSetPerformance) -> Float {
        UnitConversion.weight(previousSet.weight, from: previousSet.weightType, to: exerciseSet.weightType)
    }
}
