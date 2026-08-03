import SwiftData
import SwiftUI

/// The elapsed/target readout for a duration-tracked hold.
///
/// A hold used to be a bare counter that ran past its target and changed
/// nothing. A lifter in a floor stretch, often with their eyes shut, had no way
/// to know the hold was over except to keep watching the number — the one thing
/// that position makes hardest. Reaching the target is now a state: stated in
/// words, announced, and felt.
///
/// Its own view rather than a builder on `MobilitySessionView` because it is
/// rebuilt once a second inside a `TimelineView` nested in that view's already
/// large `body`, and this file is close to the type-checker's budget.
private struct MobilityHoldProgressLabel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let elapsedSeconds: Int
    let targetSeconds: Int
    let movementName: String

    private var hasReachedTarget: Bool { elapsedSeconds >= targetSeconds }

    var body: some View {
        label
            .foregroundStyle(hasReachedTarget ? Color.gymSecondary : Color.gymPrimary)
            .animation(reduceMotion ? nil : AppMotion.compact, value: hasReachedTarget)
            // A Bool trigger never fires on its initial value, so re-entering a
            // movement whose target already passed stays silent: reaching the
            // target is the event, not observing that it was reached.
            .gymFeedback(.timedTargetReached, trigger: hasReachedTarget) { _, reached in
                reached
            }
            .onChange(of: hasReachedTarget) { _, reached in
                guard reached else { return }
                GymAnnouncement.post(
                    String(localized: "Target duration reached for \(movementName).")
                )
            }
    }

    @ViewBuilder
    private var label: some View {
        if hasReachedTarget {
            Label("Target reached · \(elapsedSeconds) sec", systemImage: AppIcon.checkmarkCircle)
                .monospacedDigit()
        } else {
            Text("\(elapsedSeconds) / \(targetSeconds) sec")
                .monospacedDigit()
        }
    }
}

struct MobilitySessionView: View {
    @Environment(\.modelContext) private var modelContext
    let session: MobilitySession
    let onFinished: () -> Void
    @Query(sort: \MobilitySession.startTime, order: .reverse) private var mobilitySessions: [MobilitySession]
    @Query private var mobilityEvidenceRecords: [MobilityResultEvidence]

    @State private var durationsByResult: [UUID: Int] = [:]
    @State private var repetitionsByResult: [UUID: Int] = [:]
    @State private var loadsByResult: [UUID: Double] = [:]
    @State private var loadUnitsByResult: [UUID: String] = [:]
    @State private var intensitiesByResult: [UUID: Int] = [:]
    @State private var discomfortNotesByResult: [UUID: String] = [:]
    @State private var sensationsByResult: [UUID: String] = [:]
    @State private var qualitiesByResult: [UUID: String] = [:]
    @State private var compensationsByResult: [UUID: Set<MobilityCompensationKey>] = [:]
    @State private var breathingCyclesByResult: [UUID: Int] = [:]
    @State private var assistanceLevelsByResult: [UUID: Int] = [:]
    @State private var editedAssistanceResultIDs: Set<UUID> = []
    @State private var supportLevelsByResult: [UUID: String] = [:]
    @State private var phaseDurationsByResult: [UUID: Int] = [:]
    @State private var phaseIntensityByResult: [UUID: String] = [:]
    @State private var isShowingStopConfirmation = false
    @State private var error: ValidationIssue?

    var body: some View {
        Group {
            if session.status == .active, let entry = session.currentEntry {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.xl) {
                        progressHeader
                        currentEntry(entry)
                        resultInputs(entry)
                        if entry.isPhaseDriven == false {
                            previousPerformance(entry)
                        }
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.l)
                }
                // Pinned, exactly as Active Workout pins its finish button.
                // Mobility execution and workout execution are separate
                // domains but the same *act* — work through prescribed items,
                // record what was performed, commit — and a lifter should not
                // have to relearn where the committing action lives when they
                // cross from one to the other. It also stops the action from
                // scrolling off under a long list of result inputs.
                .safeAreaInset(edge: .bottom) { actions }
            } else {
                terminalContent
            }
        }
        .foregroundStyle(Color.gymText)
        .background(Color.gymBackground)
        .navigationTitle(session.nameSnapshot)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { onFinished() }
            }
            if session.status == .active {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Stop", role: .destructive) { isShowingStopConfirmation = true }
                        .accessibilityIdentifier("stop-mobility-session")
                }
            }
        }
        .confirmationDialog("Stop this mobility session?", isPresented: $isShowingStopConfirmation, titleVisibility: .visible) {
            Button("Stop Session", role: .destructive) {
                guard MobilitySessionService.stop(session, using: modelContext) else {
                    error = ValidationIssue(severity: .error, message: "The session could not be stopped. Try again.")
                    return
                }
                onFinished()
            }
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text("Unfinished movements will be saved as stopped. Completed results will remain unchanged.")
        }
        .alert("Couldn’t save mobility", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { error = nil }
        } message: {
            Text(error?.message ?? "Please try again.")
        }
        .onAppear(perform: loadCurrentEntry)
        .onChange(of: session.currentEntryIndex) { _, _ in loadCurrentEntry() }
        .onChange(of: currentPhaseResultID) { _, _ in loadCurrentEntry() }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("MOBILITY SESSION")
                .font(AppFont.captionBold)
                .tracking(0.8)
                .foregroundStyle(Color.gymAccent)
            Text("Movement \(min(session.currentEntryIndex + 1, session.entries.count)) of \(session.entries.count)")
                .font(AppFont.subheadline)
                .foregroundStyle(Color.gymSubduedText)
            ProgressView(value: Double(session.currentEntryIndex), total: Double(max(session.entries.count, 1)))
                .tint(Color.gymPrimary)
        }
    }

    private func currentEntry(_ entry: MobilityEntry) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            // Says "you are here" in words, the way Active Workout's exercise
            // card does, so the state does not rest on the tinted surface
            // alone — which is invisible in grayscale and under Increase
            // Contrast.
            Label("CURRENT MOVEMENT", systemImage: AppIcon.circleFill)
                .font(AppFont.caption2Bold)
                .tracking(0.55)
                .foregroundStyle(Color.gymPrimary)

            Text(entry.definitionNameSnapshot)
                .font(AppFont.displayMedium)
                .fixedSize(horizontal: false, vertical: true)

            if let instructions = entry.instructionsSnapshot, !instructions.isEmpty {
                Text(instructions)
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymSubduedText)
            }

            if let context = prescriptionContext(for: entry) {
                Text(context)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }

            if let blockContext = blockContextLabel(for: entry) {
                Label(blockContext, systemImage: AppIcon.mobility)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                    .accessibilityIdentifier("mobility-block-context")
            }

            if let phase = entry.currentPhaseResult {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Label(phase.phaseType.title, systemImage: AppIcon.timer)
                    Text(phaseProgressLabel(phase, in: entry))
                        .foregroundStyle(Color.gymSubduedText)
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        if entry.isTimerPaused {
                            Label("Paused at \(elapsedSeconds(for: entry)) sec", systemImage: AppIcon.pause)
                                .monospacedDigit()
                        } else {
                            MobilityHoldProgressLabel(
                                elapsedSeconds: elapsedSeconds(for: entry),
                                targetSeconds: phase.prescribedDurationSeconds,
                                movementName: "\(entry.definitionNameSnapshot), \(phase.phaseType.title)"
                            )
                        }
                    }
                    if let intensity = phase.prescribedIntensity {
                        Text("Prescribed effort: \(intensity.title)")
                            .foregroundStyle(Color.gymSubduedText)
                    }
                }
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.gymPrimary)
            } else {
                HStack(spacing: Spacing.s) {
                    Label(entry.side.displayName, systemImage: AppIcon.mobility)
                    if entry.trackingType == .duration, let target = entry.targetDurationSeconds {
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            if entry.isTimerPaused {
                                Label("Paused at \(elapsedSeconds(for: entry)) sec", systemImage: AppIcon.pause)
                                    .monospacedDigit()
                            } else {
                                MobilityHoldProgressLabel(
                                    elapsedSeconds: elapsedSeconds(for: entry),
                                    targetSeconds: target,
                                    movementName: entry.definitionNameSnapshot
                                )
                            }
                        }
                    } else if let target = entry.targetRepetitions {
                        Text("Target \(target) reps")
                    }
                }
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.gymPrimary)
            }
            if let load = entry.prescribedLoadValue,
               let unit = entry.prescribedLoadUnit {
                Text("Target load: \(load.formatted(.number.precision(.fractionLength(0...2)))) \(unit.abbreviation)")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        // `gymPrimarySurface`, the same fill Active Workout gives the exercise
        // being worked. Mobility used the neutral card surface, so the item
        // under the lifter's attention looked identical to every other card on
        // the screen.
        .background(Color.gymPrimarySurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.gymBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(entryAccessibilityLabel(entry))
    }

    @ViewBuilder
    private func resultInputs(_ entry: MobilityEntry) -> some View {
        if let phase = entry.currentPhaseResult {
            phaseResultInput(phase)
        } else {
            legacyResultInputs(entry)
        }
    }

    private func phaseResultInput(_ phase: MobilityPhaseResult) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("PHASE RESULT")
                .font(AppFont.captionBold)
                .tracking(0.8)
                .foregroundStyle(Color.gymSubduedText)

            VStack(alignment: .leading, spacing: Spacing.s) {
                Text(phase.side == .none ? phase.phaseType.title : phase.side.displayName)
                    .font(AppFont.subheadlineSemibold)

                Stepper(
                    "Performed duration: \(phaseDuration(for: phase)) sec",
                    value: phaseDurationBinding(for: phase),
                    in: 0...max(600, phase.prescribedDurationSeconds),
                    step: 5
                )
                .accessibilityIdentifier("mobility-phase-duration")

                if phaseUsesIntensity(phase) {
                    Picker("Performed effort", selection: phaseIntensityBinding(for: phase)) {
                        Text("Not recorded").tag("")
                        ForEach(ContractionIntensity.allCases, id: \.self) { intensity in
                            Text(intensity.title).tag(intensity.rawValue)
                        }
                    }
                    .accessibilityIdentifier("mobility-phase-intensity")
                }

                if let resultID = session.currentEntry?.results.first(where: { $0.side == phase.side })?.id {
                    mobilityEvidenceInputs(resultID: resultID)
                }
            }
            .padding(Spacing.m)
            .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        }
    }

    private func legacyResultInputs(_ entry: MobilityEntry) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("RESULT")
                .font(AppFont.captionBold)
                .tracking(0.8)
                .foregroundStyle(Color.gymSubduedText)

            ForEach(entry.orderedResults) { result in
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text(entry.orderedResults.count > 1 ? result.side.displayName : "Performed result")
                        .font(AppFont.subheadlineSemibold)

                    if entry.trackingType == .duration {
                        Stepper(
                            "Performed duration: \(durationsByResult[result.id, default: 0]) sec",
                            value: durationBinding(for: result, defaultValue: elapsedSeconds(for: entry)),
                            in: 0...600,
                            step: 5
                        )
                    } else {
                        Stepper(
                            "Performed repetitions: \(repetitionsByResult[result.id, default: 0])",
                            value: repetitionsBinding(for: result, defaultValue: entry.targetRepetitions ?? 0),
                            in: 0...100
                        )
                        .accessibilityIdentifier("mobility-repetitions-\(result.side.rawValue)")
                    }

                    if requiresLoadInput(resultID: result.id, entry: entry) {
                        Stepper(
                            "Performed load: \(loadsByResult[result.id, default: 0].formatted(.number.precision(.fractionLength(0...2))))",
                            value: Binding(
                                get: { loadsByResult[result.id] ?? 0 },
                                set: { loadsByResult[result.id] = $0 }
                            ),
                            in: 0...1000,
                            step: 0.5
                        )
                        .accessibilityIdentifier("mobility-load-\(result.side.rawValue)")

                        Picker("Load unit", selection: Binding(
                            get: { loadUnitsByResult[result.id] ?? entry.prescribedLoadUnit?.rawValue ?? "" },
                            set: { loadUnitsByResult[result.id] = $0 }
                        )) {
                            Text("Select unit").tag("")
                            ForEach(MobilityLoadUnit.allCases, id: \.self) { unit in
                                Text(unit.abbreviation).tag(unit.rawValue)
                            }
                        }
                        .accessibilityIdentifier("mobility-load-unit-\(result.side.rawValue)")
                    }

                    Picker("Perceived intensity", selection: intensityBinding(for: result)) {
                        Text("Not recorded").tag(0)
                        ForEach(1...5, id: \.self) { score in Text("\(score) of 5").tag(score) }
                    }

                    TextField("Optional discomfort note", text: discomfortNoteBinding(for: result), axis: .vertical)
                        .lineLimit(2...4)
                        .accessibilityIdentifier("mobility-discomfort-note-\(result.side.rawValue)")

                    mobilityEvidenceInputs(resultID: result.id)
                }
                .padding(Spacing.m)
                .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            }
        }
    }

    private var actions: some View {
        VStack(spacing: Spacing.m) {
            executionControls
            if let stop = currentStopSignal {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Stop and pay attention to what you feel. This records your observation; it is not a diagnosis.")
                        .font(AppFont.subheadline)
                        .foregroundStyle(Color.gymSubduedText)
                    Button(role: .destructive) {
                        stopForSensation(stop.sensation, resultID: stop.resultID)
                    } label: {
                        Label("Stop session now", systemImage: AppIcon.stop)
                    }
                    .buttonStyle(.gymPrimary)
                    .accessibilityIdentifier("stop-mobility-for-sensation")
                }
            } else if session.currentEntry?.isPhaseDriven == true {
                Button {
                    completeCurrentPhase()
                } label: {
                    Label("Complete phase", systemImage: AppIcon.checkmarkCircle)
                }
                .buttonStyle(.gymPrimaryProminent)
                .accessibilityIdentifier("complete-mobility-phase")

                HStack(spacing: Spacing.xl) {
                    Button("Save partial phase") { savePartialCurrentPhase() }
                        .accessibilityIdentifier("save-partial-mobility-phase")

                    Spacer(minLength: Spacing.s)

                    Button("Skip phase") { skipCurrentPhase() }
                        .foregroundStyle(Color.gymSubduedText)
                        .accessibilityIdentifier("skip-mobility-phase")
                }
                .font(AppFont.subheadlineSemibold)
                .frame(minHeight: ComponentSize.minimumTouchTarget)
            } else {
                Button {
                    completeCurrent()
                } label: {
                    Label("Complete movement", systemImage: AppIcon.checkmarkCircle)
                }
                // The app's own prominent style, not `.borderedProminent`: this is
                // the same committing action as Active Workout's, and it was the
                // one place in an execution flow still wearing a system button.
                .buttonStyle(.gymPrimaryProminent)
                .accessibilityIdentifier("complete-mobility-movement")

                HStack(spacing: Spacing.xl) {
                    Button("Save partial result") { savePartialCurrent() }
                        .accessibilityIdentifier("save-partial-mobility-movement")

                    Spacer(minLength: Spacing.s)

                    Button("Skip movement") { skipCurrent() }
                        .foregroundStyle(Color.gymSubduedText)
                        .accessibilityIdentifier("skip-mobility-movement")
                }
                .font(AppFont.subheadlineSemibold)
                .frame(minHeight: ComponentSize.minimumTouchTarget)
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.m)
        .background(Color.gymBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.gymBorder)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var executionControls: some View {
        if let entry = session.currentEntry {
            HStack(spacing: Spacing.xl) {
                Button {
                    entry.isTimerPaused ? resumeTimer() : pauseTimer()
                } label: {
                    Label(
                        entry.isTimerPaused ? "Resume timer" : "Pause timer",
                        systemImage: entry.isTimerPaused ? AppIcon.play : AppIcon.pause
                    )
                }
                .accessibilityIdentifier(entry.isTimerPaused ? "resume-mobility-timer" : "pause-mobility-timer")

                Spacer(minLength: Spacing.s)

                if MobilitySessionService.canUndo(in: session, using: modelContext) {
                    Button {
                        undoLatestCompletion()
                    } label: {
                        Label("Undo last", systemImage: AppIcon.restore)
                    }
                    .accessibilityIdentifier("undo-mobility-completion")
                }
            }
            .font(AppFont.subheadlineSemibold)
            .foregroundStyle(Color.gymPrimary)
            .frame(minHeight: ComponentSize.minimumTouchTarget)
        }
    }

    private var terminalContent: some View {
        VStack(spacing: Spacing.l) {
            ContentUnavailableView(
                session.status == .completed ? "Mobility complete" : "Mobility stopped",
                systemImage: session.status == .completed ? AppIcon.checkmarkCircle : AppIcon.stop,
                description: Text("Your performed results have been saved."))

            if session.status == .completed,
               session.orderedEntries.contains(where: { $0.isPhaseDriven }),
               MobilitySessionService.canUndo(in: session, using: modelContext) {
                Button {
                    undoLatestCompletion()
                } label: {
                    Label("Undo last phase", systemImage: AppIcon.restore)
                }
                .buttonStyle(.gymPrimary)
                .accessibilityIdentifier("undo-completed-mobility-phase")
            }

            Button("Done") { onFinished() }
                .frame(minHeight: ComponentSize.minimumTouchTarget)
                .accessibilityIdentifier("finish-mobility-session")
        }
        .padding(Spacing.xl)
    }

    @ViewBuilder
    private func previousPerformance(_ entry: MobilityEntry) -> some View {
        if entry.orderedResults.contains(where: { previousResult(for: $0, matching: entry) != nil }) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("PREVIOUS RESULT")
                    .font(AppFont.captionBold)
                    .tracking(0.8)
                    .foregroundStyle(Color.gymSubduedText)

                ForEach(entry.orderedResults) { result in
                    if let previousResult = previousResult(for: result, matching: entry) {
                        Text(previousResultLabel(previousResult, side: result.side, trackingType: entry.trackingType))
                            .font(AppFont.subheadline)
                            .foregroundStyle(Color.gymSubduedText)
                    }
                }
            }
            .padding(Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gymAccentSurface, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        }
    }

    private func elapsedSeconds(for entry: MobilityEntry) -> Int {
        MobilitySessionService.elapsedSeconds(for: entry)
    }

    private func previousResult(for result: MobilityResult, matching entry: MobilityEntry) -> MobilityResult? {
        let currentEvidence = mobilityEvidenceByResultID[result.id]
        for priorSession in mobilitySessions where priorSession.id != session.id {
            guard let priorEntry = priorSession.orderedEntries.first(where: {
                $0.definitionIDSnapshot == entry.definitionIDSnapshot && $0.trackingType == entry.trackingType
            }) else { continue }
            if let priorResult = priorEntry.orderedResults.first(where: {
                guard $0.side == result.side && ($0.status == .completed || $0.status == .partial) else {
                    return false
                }
                let priorEvidence = mobilityEvidenceByResultID[$0.id]
                return priorEvidence?.isComparable(to: currentEvidence) ?? currentEvidence == nil
            }) {
                return priorResult
            }
        }
        return nil
    }

    private var mobilityEvidenceByResultID: [UUID: MobilityResultEvidence] {
        Dictionary(mobilityEvidenceRecords.map { ($0.resultID, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func prescriptionContext(for entry: MobilityEntry) -> String? {
        guard let evidence = entry.orderedResults.compactMap({ mobilityEvidenceByResultID[$0.id] }).first else {
            return nil
        }
        var labels = [evidence.methodSnapshot?.displayName, evidence.purposeSnapshot?.displayName]
            .compactMap { $0 }
        if let breathing = evidence.breathingPrescriptionSnapshot?.targetBreaths {
            labels.append(String(localized: "\(breathing) breathing cycles"))
        }
        if let tempo = evidence.tempoPrescriptionSnapshot {
            let components = [
                tempo.moveIntoRangeSeconds,
                tempo.holdSeconds,
                tempo.returnSeconds,
                tempo.pauseSeconds
            ].map { $0.map(String.init) ?? "–" }
            labels.append(String(localized: "Tempo \(components.joined(separator: "–")) sec"))
        }
        if let assistance = evidence.assistancePrescriptionSnapshot {
            labels.append(assistance.assistanceType?.displayName ?? assistance.assistanceTypeRaw)
        }
        if let support = evidence.supportLevelSnapshot {
            labels.append(support.displayName)
        }
        return labels.isEmpty ? nil : labels.joined(separator: " · ")
    }

    private func previousResultLabel(
        _ result: MobilityResult,
        side: MobilitySide,
        trackingType: MobilityTrackingType
    ) -> String {
        let prefix = side == .none ? "Last time" : "\(side.displayName):"
        let value: String
        switch trackingType {
        case .duration:
            value = "\(result.performedDurationSeconds ?? 0) sec"
        case .repetitions:
            value = "\(result.performedRepetitions ?? 0) reps"
        }
        let load = result.performedLoadValue.flatMap { performedLoad in
            result.performedLoadUnit.map {
                "\(performedLoad.formatted(.number.precision(.fractionLength(0...2)))) \($0.abbreviation)"
            }
        }
        return ["\(prefix) \(value)", load].compactMap { $0 }.joined(separator: " · ")
    }

    private func entryAccessibilityLabel(_ entry: MobilityEntry) -> String {
        let blockPrefix = blockContextLabel(for: entry).map { "\($0). " } ?? ""
        if let phase = entry.currentPhaseResult {
            let timerState = entry.isTimerPaused
                ? String(localized: "Timer paused at \(elapsedSeconds(for: entry)) seconds.")
                : String(localized: "Timer running.")
            return blockPrefix + String(
                localized: "Current movement. \(entry.definitionNameSnapshot). Current phase \(phase.phaseType.title), \(phase.side.displayName), cycle \(phase.cycleIndex + 1) of \(entry.cycleCount), target \(phase.prescribedDurationSeconds) seconds. \(timerState)"
            )
        }
        let target: String
        if entry.trackingType == .duration {
            target = "\(entry.targetDurationSeconds ?? 0) seconds"
        } else {
            target = "\(entry.targetRepetitions ?? 0) repetitions"
        }
        // The eyebrow is inside a combined element, so without this the spoken
        // label loses the one word that says which movement this is.
        let timerState = entry.isTimerPaused
            ? String(localized: "Timer paused at \(elapsedSeconds(for: entry)) seconds.")
            : String(localized: "Timer running.")
        return blockPrefix + String(localized: "Current movement. \(entry.definitionNameSnapshot), \(entry.side.displayName), target \(target). \(timerState)")
    }

    /// Reports the block a movement belongs to and, for a round-based block,
    /// which repetition of the whole block this is — the round position the
    /// spec requires stay visible during execution. `nil` for an unblocked
    /// movement, which behaves exactly as it always has.
    private func blockContextLabel(for entry: MobilityEntry) -> String? {
        guard let evidence = MobilityEvidenceService.entryEvidence(for: entry.id, using: modelContext),
              let blockKind = evidence.blockKindSnapshot else { return nil }
        let name = evidence.blockNameSnapshot?.isEmpty == false
            ? evidence.blockNameSnapshot ?? blockKind.displayName
            : blockKind.displayName
        if let rounds = evidence.blockTargetRoundsSnapshot, rounds > 1 {
            return String(localized: "\(name) · Round \(evidence.roundIndexSnapshot + 1) of \(rounds)")
        }
        return name
    }

    private func loadCurrentEntry() {
        guard let entry = session.currentEntry else { return }
        durationsByResult = Dictionary(uniqueKeysWithValues: entry.results.map {
            ($0.id, $0.performedDurationSeconds ?? elapsedSeconds(for: entry))
        })
        repetitionsByResult = Dictionary(uniqueKeysWithValues: entry.results.map {
            ($0.id, $0.performedRepetitions ?? 0)
        })
        loadsByResult = Dictionary(uniqueKeysWithValues: entry.results.map {
            ($0.id, $0.performedLoadValue ?? 0)
        })
        loadUnitsByResult = Dictionary(uniqueKeysWithValues: entry.results.map {
            ($0.id, $0.performedLoadUnitRaw ?? entry.prescribedLoadUnitRaw ?? "")
        })
        intensitiesByResult = Dictionary(uniqueKeysWithValues: entry.results.map { ($0.id, $0.perceivedIntensity ?? 0) })
        discomfortNotesByResult = Dictionary(uniqueKeysWithValues: entry.results.map { ($0.id, $0.discomfortNote ?? "") })
        let evidence = MobilityEvidenceService.resultEvidence(using: modelContext)
        sensationsByResult = Dictionary(uniqueKeysWithValues: entry.results.map {
            ($0.id, evidence[$0.id]?.sensationRaw ?? "")
        })
        qualitiesByResult = Dictionary(uniqueKeysWithValues: entry.results.map {
            ($0.id, evidence[$0.id]?.movementQualityRaw ?? "")
        })
        compensationsByResult = Dictionary(uniqueKeysWithValues: entry.results.map {
            ($0.id, evidence[$0.id]?.compensationKeys ?? [])
        })
        breathingCyclesByResult = Dictionary(uniqueKeysWithValues: entry.results.map {
            let record = evidence[$0.id]
            return ($0.id, record?.performedBreathingCycles ?? 0)
        })
        assistanceLevelsByResult = Dictionary(uniqueKeysWithValues: entry.results.map {
            let record = evidence[$0.id]
            return ($0.id, record?.performedAssistanceLevel ?? 0)
        })
        editedAssistanceResultIDs = Set(entry.results.compactMap {
            evidence[$0.id]?.performedAssistanceLevel == nil ? nil : $0.id
        })
        supportLevelsByResult = Dictionary(uniqueKeysWithValues: entry.results.map {
            let record = evidence[$0.id]
            return ($0.id, record?.performedSupportLevelRaw ?? "")
        })
        if let phase = entry.currentPhaseResult {
            phaseDurationsByResult = [
                phase.id: phase.performedDurationSeconds ?? elapsedSeconds(for: entry)
            ]
            phaseIntensityByResult = [phase.id: phase.performedIntensity?.rawValue ?? ""]
        } else {
            phaseDurationsByResult = [:]
            phaseIntensityByResult = [:]
        }
    }

    private func completeCurrent() {
        guard MobilitySessionService.completeCurrent(
            in: session,
            resultInputs: currentResultInputs,
            using: modelContext
        ) else {
            error = ValidationIssue(
                severity: .error,
                message: "Enter each required performed value before completing this movement."
            )
            return
        }
        if session.status != .active { onFinished() }
    }

    private func completeCurrentPhase() {
        guard let entry = session.currentEntry,
              let phase = entry.currentPhaseResult else {
            error = ValidationIssue(severity: .error, message: "The current phase changed. Review it and try again.")
            return
        }
        let outcome = MobilitySessionService.completeCurrentPhase(
            in: session,
            performedDurationSeconds: phaseDurationsByResult[phase.id] ?? elapsedSeconds(for: entry),
            performedIntensity: phaseIntensityByResult[phase.id].flatMap(ContractionIntensity.init(rawValue:)),
            sensation: sensation(for: phase.side),
            movementQuality: movementQuality(for: phase.side),
            compensationKeys: compensationKeys(for: phase.side),
            performedBreathingCycles: breathingCycles(for: phase.side),
            performedAssistanceLevel: assistanceLevel(for: phase.side),
            performedSupportLevel: supportLevel(for: phase.side),
            using: modelContext
        )
        switch outcome {
        case .applied:
            break
        case .stale:
            loadCurrentEntry()
            error = ValidationIssue(severity: .error, message: "The current phase changed. Review it and try again.")
        case .invalidPerformedDuration:
            error = ValidationIssue(severity: .error, message: "Enter a valid performed duration before continuing.")
        case .stopSignalRequiresStop:
            error = ValidationIssue(severity: .error, message: "Use Stop session now to save this observation without completing later work.")
        case .persistenceFailure:
            error = ValidationIssue(severity: .error, message: "The phase could not be saved. Try again.")
        }
    }

    private func savePartialCurrentPhase() {
        guard let entry = session.currentEntry,
              let phase = entry.currentPhaseResult else {
            error = ValidationIssue(severity: .error, message: "The current phase changed. Review it and try again.")
            return
        }
        handlePhaseOutcome(
            MobilitySessionService.savePartialCurrentPhase(
                in: session,
                performedDurationSeconds: phaseDurationsByResult[phase.id] ?? elapsedSeconds(for: entry),
                performedIntensity: phaseIntensityByResult[phase.id].flatMap(ContractionIntensity.init(rawValue:)),
                sensation: sensation(for: phase.side),
                movementQuality: movementQuality(for: phase.side),
                compensationKeys: compensationKeys(for: phase.side),
                performedBreathingCycles: breathingCycles(for: phase.side),
                performedAssistanceLevel: assistanceLevel(for: phase.side),
                performedSupportLevel: supportLevel(for: phase.side),
                using: modelContext
            ),
            failureMessage: "The partial phase could not be saved. Try again."
        )
    }

    private func skipCurrentPhase() {
        handlePhaseOutcome(
            MobilitySessionService.skipCurrentPhase(in: session, using: modelContext),
            failureMessage: "The phase could not be skipped. Try again."
        )
    }

    private func handlePhaseOutcome(
        _ outcome: MobilityPhaseCompletionOutcome,
        failureMessage: String
    ) {
        switch outcome {
        case .applied:
            break
        case .stale:
            loadCurrentEntry()
            error = ValidationIssue(severity: .error, message: "The current phase changed. Review it and try again.")
        case .invalidPerformedDuration:
            error = ValidationIssue(severity: .error, message: "Enter a valid performed duration before continuing.")
        case .stopSignalRequiresStop:
            error = ValidationIssue(severity: .error, message: "Use Stop session now to save this observation without completing later work.")
        case .persistenceFailure:
            error = ValidationIssue(severity: .error, message: failureMessage)
        }
    }

    private func pauseTimer() {
        switch MobilitySessionService.pause(session, using: modelContext) {
        case .applied, .alreadyPaused:
            loadCurrentEntry()
        case .alreadyRunning:
            break
        case .stale:
            error = ValidationIssue(severity: .error, message: "The current movement changed. Review it and try again.")
        case .persistenceFailure:
            error = ValidationIssue(severity: .error, message: "The timer could not be paused. Try again.")
        }
    }

    private func resumeTimer() {
        switch MobilitySessionService.resume(session, using: modelContext) {
        case .applied, .alreadyRunning:
            loadCurrentEntry()
        case .alreadyPaused:
            break
        case .stale:
            error = ValidationIssue(severity: .error, message: "The current movement changed. Review it and try again.")
        case .persistenceFailure:
            error = ValidationIssue(severity: .error, message: "The timer could not be resumed. Try again.")
        }
    }

    private func undoLatestCompletion() {
        switch MobilitySessionService.undoLatestCompletion(in: session, using: modelContext) {
        case .applied:
            loadCurrentEntry()
        case .nothingToUndo:
            break
        case .stale:
            error = ValidationIssue(severity: .error, message: "The latest result changed and could not be undone.")
        case .persistenceFailure:
            error = ValidationIssue(severity: .error, message: "The latest result could not be undone. Try again.")
        }
    }

    private func skipCurrent() {
        guard MobilitySessionService.skipCurrent(in: session, using: modelContext) else {
            error = ValidationIssue(severity: .error, message: "The movement could not be skipped. Try again.")
            return
        }
        if session.status != .active { onFinished() }
    }

    private func savePartialCurrent() {
        guard MobilitySessionService.savePartialCurrent(
            in: session,
            resultInputs: currentResultInputs,
            using: modelContext
        ) else {
            error = ValidationIssue(severity: .error, message: "The partial result could not be saved. Try again.")
            return
        }
        if session.status != .active { onFinished() }
    }

    private var currentResultInputs: [UUID: MobilityResultInput] {
        guard let entry = session.currentEntry else { return [:] }
        return Dictionary(uniqueKeysWithValues: entry.results.map { result in
            (
                result.id,
                MobilityResultInput(
                    performedDurationSeconds: entry.trackingType == .duration
                        ? positiveValue(durationsByResult[result.id]) : nil,
                    performedRepetitions: entry.trackingType == .repetitions
                        ? positiveValue(repetitionsByResult[result.id]) : nil,
                    performedLoadValue: performedLoadValue(for: result.id),
                    performedLoadUnit: performedLoadUnit(for: result.id),
                    perceivedIntensity: intensitiesByResult[result.id] == 0 ? nil : intensitiesByResult[result.id],
                    discomfortNote: discomfortNotesByResult[result.id],
                    sensation: sensationsByResult[result.id].flatMap(MobilitySensation.init(rawValue:)),
                    movementQuality: qualitiesByResult[result.id].flatMap(MobilityMovementQuality.init(rawValue:)),
                    compensationKeys: compensationsByResult[result.id] ?? [],
                    performedBreathingCycles: breathingCyclesValue(for: result.id),
                    performedAssistanceLevel: assistanceLevelValue(for: result.id),
                    performedSupportLevel: supportLevelsByResult[result.id].flatMap(MobilitySupportLevel.init(rawValue:))
                )
            )
        })
    }

    private var currentPhaseResultID: UUID? {
        session.currentEntry?.currentPhaseResult?.id
    }

    private func phaseProgressLabel(_ phase: MobilityPhaseResult, in entry: MobilityEntry) -> String {
        let phaseCount = entry.phaseResults.filter {
            $0.side == phase.side && $0.cycleIndex == phase.cycleIndex
        }.count
        return String(
            localized: "\(phase.side.displayName) · Cycle \(phase.cycleIndex + 1) of \(entry.cycleCount) · Phase \(entry.currentPhaseIndex + 1) of \(phaseCount)"
        )
    }

    private func phaseUsesIntensity(_ phase: MobilityPhaseResult) -> Bool {
        phase.prescribedIntensity != nil
            || phase.phaseType == .contraction
            || phase.phaseType == .activeContraction
    }

    private func phaseDuration(for phase: MobilityPhaseResult) -> Int {
        phaseDurationsByResult[phase.id]
            ?? session.currentEntry.map { elapsedSeconds(for: $0) }
            ?? 0
    }

    private func phaseDurationBinding(for phase: MobilityPhaseResult) -> Binding<Int> {
        Binding(
            get: { phaseDuration(for: phase) },
            set: { phaseDurationsByResult[phase.id] = $0 }
        )
    }

    private func phaseIntensityBinding(for phase: MobilityPhaseResult) -> Binding<String> {
        Binding(
            get: { phaseIntensityByResult[phase.id] ?? "" },
            set: { phaseIntensityByResult[phase.id] = $0 }
        )
    }

    private func durationBinding(for result: MobilityResult, defaultValue: Int) -> Binding<Int> {
        Binding(get: { durationsByResult[result.id] ?? defaultValue }, set: { durationsByResult[result.id] = $0 })
    }

    private func repetitionsBinding(for result: MobilityResult, defaultValue: Int) -> Binding<Int> {
        Binding(get: { repetitionsByResult[result.id] ?? defaultValue }, set: { repetitionsByResult[result.id] = $0 })
    }

    private func intensityBinding(for result: MobilityResult) -> Binding<Int> {
        Binding(get: { intensitiesByResult[result.id] ?? 0 }, set: { intensitiesByResult[result.id] = $0 })
    }

    private func discomfortNoteBinding(for result: MobilityResult) -> Binding<String> {
        Binding(get: { discomfortNotesByResult[result.id] ?? "" }, set: { discomfortNotesByResult[result.id] = $0 })
    }

    @ViewBuilder
    private func mobilityEvidenceInputs(resultID: UUID) -> some View {
        let evidence = mobilityEvidenceByResultID[resultID]
        if evidence?.breathingPrescriptionSnapshot != nil
            || evidence?.assistancePrescriptionSnapshot != nil
            || evidence?.supportLevelSnapshot != nil {
            DisclosureGroup("Setup and breathing") {
                if let breathing = evidence?.breathingPrescriptionSnapshot {
                    if breathing.targetBreaths != nil {
                        Stepper(
                            "Breathing cycles: \(breathingCyclesByResult[resultID, default: 0])",
                            value: Binding(
                                get: { breathingCyclesByResult[resultID] ?? 0 },
                                set: { breathingCyclesByResult[resultID] = $0 }
                            ),
                            in: 0...100
                        )
                    }
                    if let inhale = breathing.inhaleSeconds, let exhale = breathing.exhaleSeconds {
                        Text("Breathing pace: \(inhale) sec in · \(exhale) sec out")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                    }
                }
                if let assistance = evidence?.assistancePrescriptionSnapshot {
                    Text(assistance.assistanceType?.displayName ?? assistance.assistanceTypeRaw)
                        .font(AppFont.subheadlineSemibold)
                    if assistance.level != nil {
                        Stepper(
                            "Assistance level: \(assistanceLevelsByResult[resultID, default: 0])",
                            value: Binding(
                                get: { assistanceLevelsByResult[resultID] ?? 0 },
                                set: {
                                    assistanceLevelsByResult[resultID] = $0
                                    editedAssistanceResultIDs.insert(resultID)
                                }
                            ),
                            in: 0...10
                        )
                    }
                    if let equipment = assistance.equipmentRaw, equipment.isEmpty == false {
                        Text(equipment)
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                    }
                }
                if evidence?.supportLevelSnapshot != nil {
                    Picker("Support used", selection: Binding(
                        get: { supportLevelsByResult[resultID] ?? "" },
                        set: { supportLevelsByResult[resultID] = $0 }
                    )) {
                        Text("Not recorded").tag("")
                        ForEach(MobilitySupportLevel.allCases) { support in
                            Text(support.displayName).tag(support.rawValue)
                        }
                    }
                    Text("Support is saved as comparison context, not as a score.")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                }
            }
        }

        Picker("Sensation", selection: Binding(
            get: { sensationsByResult[resultID] ?? "" },
            set: { sensationsByResult[resultID] = $0 }
        )) {
            Text("Not recorded").tag("")
            ForEach(MobilitySensation.allCases) { sensation in
                Text(sensation.displayName).tag(sensation.rawValue)
            }
        }
        .accessibilityIdentifier("mobility-sensation-\(resultID.uuidString)")

        Picker("Movement quality", selection: Binding(
            get: { qualitiesByResult[resultID] ?? "" },
            set: { qualitiesByResult[resultID] = $0 }
        )) {
            Text("Not recorded").tag("")
            ForEach(MobilityMovementQuality.allCases) { quality in
                Text(quality.displayName).tag(quality.rawValue)
            }
        }

        if qualitiesByResult[resultID] == MobilityMovementQuality.compensationObserved.rawValue {
            DisclosureGroup("Neutral observations") {
                ForEach(MobilityCompensationKey.allCases) { key in
                    Button {
                        var selected = compensationsByResult[resultID] ?? []
                        if selected.contains(key) { selected.remove(key) } else { selected.insert(key) }
                        compensationsByResult[resultID] = selected
                    } label: {
                        Label(
                            key.displayName,
                            systemImage: (compensationsByResult[resultID] ?? []).contains(key)
                                ? AppIcon.checkmarkCircle
                                : AppIcon.circle
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: ComponentSize.minimumTouchTarget)
                }
            }
        }
    }

    private var currentStopSignal: (resultID: UUID, sensation: MobilitySensation)? {
        guard let entry = session.currentEntry else { return nil }
        for result in entry.orderedResults {
            if let sensation = sensationsByResult[result.id].flatMap(MobilitySensation.init(rawValue:)),
               sensation.isStopSignal {
                return (result.id, sensation)
            }
        }
        return nil
    }

    private func stopForSensation(_ sensation: MobilitySensation, resultID: UUID) {
        let quality = qualitiesByResult[resultID].flatMap(MobilityMovementQuality.init(rawValue:))
        guard MobilitySessionService.stopDueToSensation(
            sensation,
            resultID: resultID,
            movementQuality: quality,
            compensationKeys: compensationsByResult[resultID] ?? [],
            performedBreathingCycles: breathingCyclesValue(for: resultID),
            performedAssistanceLevel: assistanceLevelValue(for: resultID),
            performedSupportLevel: supportLevelsByResult[resultID].flatMap(MobilitySupportLevel.init(rawValue:)),
            in: session,
            using: modelContext
        ) else {
            error = ValidationIssue(severity: .error, message: "The observation could not be saved. Try again.")
            return
        }
        onFinished()
    }

    private func resultID(for side: MobilitySide) -> UUID? {
        session.currentEntry?.results.first(where: { $0.side == side })?.id
    }

    private func sensation(for side: MobilitySide) -> MobilitySensation? {
        resultID(for: side).flatMap { sensationsByResult[$0] }.flatMap(MobilitySensation.init(rawValue:))
    }

    private func movementQuality(for side: MobilitySide) -> MobilityMovementQuality? {
        resultID(for: side).flatMap { qualitiesByResult[$0] }.flatMap(MobilityMovementQuality.init(rawValue:))
    }

    private func compensationKeys(for side: MobilitySide) -> Set<MobilityCompensationKey> {
        resultID(for: side).flatMap { compensationsByResult[$0] } ?? []
    }

    private func breathingCycles(for side: MobilitySide) -> Int? {
        resultID(for: side).flatMap { breathingCyclesValue(for: $0) }
    }

    private func assistanceLevel(for side: MobilitySide) -> Int? {
        resultID(for: side).flatMap { assistanceLevelValue(for: $0) }
    }

    private func supportLevel(for side: MobilitySide) -> MobilitySupportLevel? {
        resultID(for: side)
            .flatMap { supportLevelsByResult[$0] }
            .flatMap(MobilitySupportLevel.init(rawValue:))
    }

    private func breathingCyclesValue(for resultID: UUID) -> Int? {
        guard mobilityEvidenceByResultID[resultID]?.breathingPrescriptionSnapshot?.targetBreaths != nil else { return nil }
        return positiveValue(breathingCyclesByResult[resultID])
    }

    private func requiresLoadInput(resultID: UUID, entry: MobilityEntry) -> Bool {
        entry.prescribedLoadValue != nil
            || mobilityEvidenceByResultID[resultID]?.metricProfileSnapshot?
                .supportedMetrics.contains(.load) == true
    }

    private func performedLoadValue(for resultID: UUID) -> Double? {
        guard let value = loadsByResult[resultID], value > 0 else { return nil }
        return value
    }

    private func performedLoadUnit(for resultID: UUID) -> MobilityLoadUnit? {
        guard performedLoadValue(for: resultID) != nil else { return nil }
        return loadUnitsByResult[resultID].flatMap(MobilityLoadUnit.init(rawValue:))
    }

    private func assistanceLevelValue(for resultID: UUID) -> Int? {
        guard mobilityEvidenceByResultID[resultID]?.assistancePrescriptionSnapshot?.level != nil,
              editedAssistanceResultIDs.contains(resultID) else { return nil }
        return assistanceLevelsByResult[resultID]
    }

    private func positiveValue(_ value: Int?) -> Int? {
        guard let value, value > 0 else { return nil }
        return value
    }
}
