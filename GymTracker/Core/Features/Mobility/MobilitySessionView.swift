import SwiftData
import SwiftUI

struct MobilitySessionView: View {
    @Environment(\.modelContext) private var modelContext
    let session: MobilitySession
    let onFinished: () -> Void
    @Query(sort: \MobilitySession.startTime, order: .reverse) private var mobilitySessions: [MobilitySession]

    @State private var durationsByResult: [UUID: Int] = [:]
    @State private var repetitionsByResult: [UUID: Int] = [:]
    @State private var intensitiesByResult: [UUID: Int] = [:]
    @State private var discomfortNotesByResult: [UUID: String] = [:]
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
                        previousPerformance(entry)
                        actions
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.l)
                }
            } else {
                ContentUnavailableView(
                    session.status == .completed ? "Mobility complete" : "Mobility stopped",
                    systemImage: session.status == .completed ? AppIcon.checkmarkCircle : AppIcon.stop,
                    description: Text("Your performed results have been saved."))
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
            Text(entry.definitionNameSnapshot)
                .font(AppFont.displayMedium)
                .fixedSize(horizontal: false, vertical: true)

            if let instructions = entry.instructionsSnapshot, !instructions.isEmpty {
                Text(instructions)
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymSubduedText)
            }

            HStack(spacing: Spacing.s) {
                Label(entry.side.displayName, systemImage: AppIcon.mobility)
                if entry.trackingType == .duration, let target = entry.targetDurationSeconds {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text("\(elapsedSeconds(for: entry)) / \(target) sec")
                            .monospacedDigit()
                    }
                } else if let target = entry.targetRepetitions {
                    Text("Target \(target) reps")
                }
            }
            .font(AppFont.subheadlineSemibold)
            .foregroundStyle(Color.gymPrimary)
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.gymBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(entryAccessibilityLabel(entry))
    }

    @ViewBuilder
    private func resultInputs(_ entry: MobilityEntry) -> some View {
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

                    Picker("Perceived intensity", selection: intensityBinding(for: result)) {
                        Text("Not recorded").tag(0)
                        ForEach(1...5, id: \.self) { score in Text("\(score) of 5").tag(score) }
                    }

                    TextField("Optional discomfort note", text: discomfortNoteBinding(for: result), axis: .vertical)
                        .lineLimit(2...4)
                        .accessibilityIdentifier("mobility-discomfort-note-\(result.side.rawValue)")
                }
                .padding(Spacing.m)
                .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            }
        }
    }

    private var actions: some View {
        VStack(spacing: Spacing.s) {
            Button {
                completeCurrent()
            } label: {
                Label("Complete movement", systemImage: AppIcon.checkmarkCircle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.gymPrimary)
            .accessibilityIdentifier("complete-mobility-movement")

            Button("Save partial result") { savePartialCurrent() }
                .font(AppFont.subheadlineSemibold)
                .accessibilityIdentifier("save-partial-mobility-movement")

            Button("Skip movement") { skipCurrent() }
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.gymSubduedText)
                .accessibilityIdentifier("skip-mobility-movement")
        }
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
        for priorSession in mobilitySessions where priorSession.id != session.id {
            guard let priorEntry = priorSession.orderedEntries.first(where: {
                $0.definitionIDSnapshot == entry.definitionIDSnapshot && $0.trackingType == entry.trackingType
            }) else { continue }
            if let priorResult = priorEntry.orderedResults.first(where: {
                $0.side == result.side && ($0.status == .completed || $0.status == .partial)
            }) {
                return priorResult
            }
        }
        return nil
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
        return "\(prefix) \(value)"
    }

    private func entryAccessibilityLabel(_ entry: MobilityEntry) -> String {
        let target: String
        if entry.trackingType == .duration {
            target = "\(entry.targetDurationSeconds ?? 0) seconds"
        } else {
            target = "\(entry.targetRepetitions ?? 0) repetitions"
        }
        return "\(entry.definitionNameSnapshot), \(entry.side.displayName), target \(target)"
    }

    private func loadCurrentEntry() {
        guard let entry = session.currentEntry else { return }
        durationsByResult = Dictionary(uniqueKeysWithValues: entry.results.map {
            ($0.id, $0.performedDurationSeconds ?? elapsedSeconds(for: entry))
        })
        repetitionsByResult = Dictionary(uniqueKeysWithValues: entry.results.map {
            ($0.id, $0.performedRepetitions ?? entry.targetRepetitions ?? 0)
        })
        intensitiesByResult = Dictionary(uniqueKeysWithValues: entry.results.map { ($0.id, $0.perceivedIntensity ?? 0) })
        discomfortNotesByResult = Dictionary(uniqueKeysWithValues: entry.results.map { ($0.id, $0.discomfortNote ?? "") })
    }

    private func completeCurrent() {
        guard MobilitySessionService.completeCurrent(
            in: session,
            resultInputs: currentResultInputs,
            using: modelContext
        ) else {
            error = ValidationIssue(severity: .error, message: "The movement could not be saved. Try again.")
            return
        }
        if session.status != .active { onFinished() }
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
                    performedDurationSeconds: entry.trackingType == .duration ? durationsByResult[result.id] : nil,
                    performedRepetitions: entry.trackingType == .repetitions ? repetitionsByResult[result.id] : nil,
                    perceivedIntensity: intensitiesByResult[result.id] == 0 ? nil : intensitiesByResult[result.id],
                    discomfortNote: discomfortNotesByResult[result.id]
                )
            )
        })
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
}
