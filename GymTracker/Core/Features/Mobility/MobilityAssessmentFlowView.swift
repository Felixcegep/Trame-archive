import SwiftData
import SwiftUI

/// The assessment itself: instruction → conditions and entry → confirmation,
/// once per chosen assessment, then a summary.
///
/// The session owns the step position, the saved observations, and the skip
/// list, so an interruption — a call, a backgrounded app, a closed cover —
/// never costs more than the entry currently on screen. This view holds only
/// the in-flight draft.
struct MobilityAssessmentFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let session: MobilityAssessmentSession
    /// The presenter dismisses and cleans up; this view only reports that it is
    /// finished with the session.
    let onFinished: () -> Void

    @State private var definitions: [MobilityAssessmentDefinition] = []
    @State private var phase: Phase = .instruction
    @State private var draft = EntryDraft()
    @State private var confirmedResultIDs: [UUID] = []
    /// Increments only after a save is persisted, which is what the success
    /// haptic is allowed to represent.
    @State private var saveCount = 0
    @State private var error: String?
    @State private var isShowingStopConfirmation = false

    private enum Phase: Equatable {
        case instruction
        case entry
        case confirmation
        case summary
    }

    /// The values being entered right now. Conditions are shared across the
    /// sides of one assessment because that is how a person actually performs
    /// it; each side is still persisted with its own copy of them.
    private struct EntryDraft: Equatable {
        var definitionKey: String = ""
        var setupKey: String = ""
        var isActiveRange: Bool = true
        var isWarm: Bool = false
        var numericValues: [String: Double] = [:]
        var criteria: [String: MobilityAssessmentCriteriaObservation] = [:]
    }

    var body: some View {
        flowSurface
            .confirmationDialog(
                "Stop this assessment?",
                isPresented: $isShowingStopConfirmation,
                titleVisibility: .visible
            ) {
                Button("Stop assessment", role: .destructive, action: stop)
                Button("Keep going", role: .cancel) {}
            } message: {
                Text("Observations you already saved are kept. The assessment you are entering right now is not saved.")
            }
            .alert(
                "Couldn’t save this observation",
                isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
            ) {
                Button("OK", role: .cancel) { error = nil }
            } message: {
                Text(error ?? MobilityAssessmentErrorCopy.generic)
            }
    }

    private var flowSurface: some View {
        scrollingContent
            .background(Color.gymBackground)
            .navigationTitle("Assessment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { flowToolbar }
            .task { load() }
            .onChange(of: session.currentDefinitionIndex) { _, _ in
                prepareDraftForCurrentStep()
            }
            // Fires only after a save is persisted — never on appearance, and
            // never during the entry itself.
            .gymFeedback(.sessionSaved, trigger: saveCount)
    }

    private var scrollingContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                if phase != .summary {
                    progressHeader
                }
                stepContent
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.l)
            .animation(reduceMotion ? nil : AppMotion.compact, value: phase)
        }
    }

    @ToolbarContentBuilder
    private var flowToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close") { onFinished() }
                .accessibilityIdentifier("close-mobility-assessment")
                .accessibilityHint(Text("Leaves the assessment in progress. Saved observations are kept."))
        }
        if session.status == .active {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Stop", role: .destructive) { isShowingStopConfirmation = true }
                    .accessibilityIdentifier("stop-mobility-assessment")
            }
        }
    }

    // MARK: - Header

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            GymEyebrow("Mobility assessment", tint: .gymAccent)
            Text(stepCountText)
                .font(AppFont.subheadline)
                .foregroundStyle(Color.gymSubduedText)
            ProgressView(
                value: Double(min(currentIndex, orderedDefinitions.count)),
                total: Double(max(orderedDefinitions.count, 1))
            )
            .tint(Color.gymPrimary)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("mobility-assessment-progress")
    }

    private var stepCountText: String {
        String(
            localized: "mobility.assessment.step.count",
            defaultValue: "Assessment \(min(currentIndex + 1, orderedDefinitions.count).formatted()) of \(orderedDefinitions.count.formatted())"
        )
    }

    // MARK: - Steps

    @ViewBuilder
    private var stepContent: some View {
        switch phase {
        case .summary:
            summaryStep
        case .instruction, .entry, .confirmation:
            if let definition = currentDefinition {
                switch phase {
                case .instruction: instructionStep(definition)
                case .entry: entryStep(definition)
                case .confirmation: confirmationStep(definition)
                case .summary: EmptyView()
                }
            } else {
                // The step index ran past the catalogue — a selection that no
                // longer resolves. The summary still holds everything saved.
                summaryStep
            }
        }
    }

    // MARK: Instruction

    private func instructionStep(_ definition: MobilityAssessmentDefinition) -> some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            GymCard {
                Text(MobilityAssessmentCopy.name(for: definition))
                    .font(AppFont.titleSmall)
                    .foregroundStyle(Color.gymText)
                GymTagChip(
                    title: definition.zone.displayName,
                    systemImage: AppIcon.mobilityAssessment,
                    style: .outlined
                )

                instructionSection(
                    title: "What this records",
                    body: MobilityAssessmentCopy.measurementDescription(for: definition)
                )
                instructionSection(
                    title: "How to set up",
                    body: MobilityAssessmentCopy.setupInstructions(for: definition)
                )
                instructionSection(
                    title: "How to perform it",
                    body: MobilityAssessmentCopy.instructions(for: definition)
                )
                // Stating the limits of the observation in the flow — not in a
                // footnote elsewhere — is what keeps the record honest.
                instructionSection(
                    title: "What this cannot tell you",
                    body: MobilityAssessmentCopy.measurementLimitations(for: definition)
                )
            }

            GymCard(variant: .accent) {
                Label {
                    Text("You enter this value yourself and it is recorded as entered by hand.")
                        .font(AppFont.subheadline)
                        .foregroundStyle(Color.gymText)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: AppIcon.edit)
                        .font(AppFont.subheadline)
                        .foregroundStyle(Color.gymAccent)
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
            }

            VStack(spacing: Spacing.m) {
                Button("Enter what you observed") {
                    prepareDraftForCurrentStep()
                    phase = .entry
                }
                .buttonStyle(.gymPrimary)
                .accessibilityIdentifier("record-mobility-assessment-result")

                Button("Skip this assessment", action: skipCurrent)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.gymSubduedText)
                    .frame(minHeight: ComponentSize.minimumTouchTarget)
                    .accessibilityIdentifier("skip-mobility-assessment")
            }
        }
    }

    @ViewBuilder
    private func instructionSection(title: LocalizedStringKey, body text: String) -> some View {
        if text.isEmpty == false {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                GymEyebrow(title)
                Text(text)
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Entry

    private func entryStep(_ definition: MobilityAssessmentDefinition) -> some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            GymCard {
                Text(MobilityAssessmentCopy.name(for: definition))
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymText)

                GymEyebrow("Conditions")
                Text("These are recorded with the observation. A later observation is only compared with this one when all of them match.")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)

                setupControl(definition)

                Picker("Range", selection: $draft.isActiveRange) {
                    Text("Active range").tag(true)
                    Text("Passive range").tag(false)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("mobility-assessment-range-picker")

                Picker("Timing", selection: $draft.isWarm) {
                    Text("Before training").tag(false)
                    Text("After training").tag(true)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("mobility-assessment-timing-picker")
            }

            GymCard {
                GymEyebrow("What you observed")
                if definition.unit == .criteria {
                    criteriaControls(definition)
                } else {
                    numericControls(definition)
                }
            }

            VStack(spacing: Spacing.m) {
                Button("Save observation") { save(definition) }
                    .buttonStyle(.gymPrimary)
                    .accessibilityIdentifier("save-mobility-assessment-result")

                Button("Back to instructions") { phase = .instruction }
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.gymSubduedText)
                    .frame(minHeight: ComponentSize.minimumTouchTarget)
                    .accessibilityIdentifier("mobility-assessment-back-to-instructions")

                Button("Skip this assessment", action: skipCurrent)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.gymSubduedText)
                    .frame(minHeight: ComponentSize.minimumTouchTarget)
                    .accessibilityIdentifier("skip-mobility-assessment-from-entry")
            }
        }
    }

    /// The seeded catalogue authors one setup per assessment today. A single
    /// option is stated as a fact rather than dressed up as a choice, but it is
    /// still shown: it is a recorded condition, and hiding it would make the
    /// comparison rule invisible.
    @ViewBuilder
    private func setupControl(_ definition: MobilityAssessmentDefinition) -> some View {
        if definition.setupKeys.count > 1 {
            Picker("Setup", selection: $draft.setupKey) {
                ForEach(definition.setupKeys, id: \.self) { key in
                    Text(MobilityAssessmentCopy.setupName(key)).tag(key)
                }
            }
            .accessibilityIdentifier("mobility-assessment-setup-picker")
        } else {
            HStack(spacing: Spacing.s) {
                Text("Setup")
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymSubduedText)
                Spacer(minLength: Spacing.s)
                Text(MobilityAssessmentCopy.setupName(draft.setupKey))
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymText)
                    .multilineTextAlignment(.trailing)
            }
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("mobility-assessment-setup-value")
        }
    }

    private func numericControls(_ definition: MobilityAssessmentDefinition) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            ForEach(definition.supportedSides, id: \.self) { side in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(side.displayName)
                        .font(AppFont.subheadlineSemibold)
                        .foregroundStyle(Color.gymText)
                    HStack(spacing: Spacing.s) {
                        DecimalField(
                            "Value",
                            value: numericBinding(for: side),
                            prompt: MobilityAssessmentValueFormatter.placeholder,
                            range: valueRange(for: definition.unit)
                        )
                        .gymFieldStyle()
                        .accessibilityLabel(fieldAccessibilityLabel(side: side, unit: definition.unit))
                        .accessibilityIdentifier("mobility-assessment-value-\(side.rawValue)")

                        Text(MobilityAssessmentValueFormatter.unitSuffix(definition.unit))
                            .font(AppFont.subheadlineSemibold)
                            .foregroundStyle(Color.gymSubduedText)
                            .accessibilityHidden(true)
                    }
                }
            }

            Text("Leave a side empty if you did not observe it. Left and right are saved as separate observations.")
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func criteriaControls(_ definition: MobilityAssessmentDefinition) -> some View {
        let side = definition.supportedSides.first ?? .combined
        return VStack(alignment: .leading, spacing: Spacing.s) {
            ForEach(MobilityAssessmentCriteriaObservation.allCases, id: \.self) { observation in
                let isSelected = draft.criteria[side.rawValue] == observation
                Button {
                    draft.criteria[side.rawValue] = observation
                } label: {
                    HStack(spacing: Spacing.m) {
                        Image(systemName: isSelected ? AppIcon.checkmarkCircle : AppIcon.circle)
                            .font(AppFont.subheadline)
                            .foregroundStyle(isSelected ? Color.gymPrimary : Color.gymSubtleText)
                            .accessibilityHidden(true)
                        Text(observation.displayName)
                            .font(AppFont.subheadline)
                            .foregroundStyle(Color.gymText)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: ComponentSize.minimumTouchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("mobility-assessment-criteria-\(observation.rawValue)")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    // MARK: Confirmation

    private func confirmationStep(_ definition: MobilityAssessmentDefinition) -> some View {
        let observations = confirmedObservations
        return VStack(alignment: .leading, spacing: Spacing.l) {
            GymCard {
                GymEyebrow("Saved", tint: .gymSecondary)
                Text(MobilityAssessmentCopy.name(for: definition))
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymText)

                ForEach(observations) { observation in
                    MobilityAssessmentObservationRow(observation: observation, showsTitle: false)
                }

                if let gapText = sideGapText(for: observations) {
                    // A plain difference between two sides. It is an
                    // observation about two numbers, not a finding about a body.
                    Text(gapText)
                        .font(AppFont.subheadlineSemiboldMonospaced)
                        .foregroundStyle(Color.gymText)
                        .accessibilityIdentifier("mobility-assessment-side-difference")
                }
            }

            VStack(spacing: Spacing.m) {
                Button(isLastStep ? "Finish assessment" : "Next assessment") { advance() }
                    .buttonStyle(.gymPrimary)
                    .accessibilityIdentifier("mobility-assessment-next")

                Button("Change these values") { phase = .entry }
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.gymSubduedText)
                    .frame(minHeight: ComponentSize.minimumTouchTarget)
                    .accessibilityIdentifier("mobility-assessment-retake")
            }
        }
    }

    // MARK: Summary

    private var summaryStep: some View {
        // Resolved once: each observation's comparison costs a fetch, so the
        // grouping is built here rather than recomputed per zone.
        let groups = summaryGroups
        return VStack(alignment: .leading, spacing: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Assessment complete")
                    .font(AppFont.titleSmall)
                    .foregroundStyle(Color.gymText)
                Text(summaryCountText)
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymSubduedText)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("mobility-assessment-summary")

            if groups.isEmpty {
                GymCard {
                    ContentUnavailableView(
                        "Nothing recorded",
                        systemImage: AppIcon.mobilityAssessment,
                        description: Text("You skipped every assessment in this session. Nothing was saved.")
                    )
                }
            } else {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        GymSectionHeader(title: group.title)
                        GymCard {
                            ForEach(group.observations) { observation in
                                MobilityAssessmentObservationRow(observation: observation)
                            }
                        }
                    }
                }
            }

            if skippedNames.isEmpty == false {
                GymCard {
                    GymEyebrow("Skipped assessments")
                    // Skipped is unknown, never a low value. It is listed by
                    // name so it can be recorded later on purpose.
                    ForEach(skippedNames, id: \.self) { name in
                        MobilityAssessmentBulletRow(systemImage: AppIcon.skip, text: name)
                    }
                }
            }

            MobilityAssessmentScopeNote()

            Button("Done", action: complete)
                .buttonStyle(.gymPrimary)
                .accessibilityIdentifier("finish-mobility-assessment")
        }
    }

    // MARK: - Derived state

    private var orderedDefinitions: [MobilityAssessmentDefinition] {
        session.selectedDefinitionKeys.compactMap { key in
            definitions.first { $0.catalogueKey == key }
        }
    }

    private var currentIndex: Int { session.currentDefinitionIndex }

    private var currentDefinition: MobilityAssessmentDefinition? {
        guard orderedDefinitions.indices.contains(currentIndex) else { return nil }
        return orderedDefinitions[currentIndex]
    }

    private var isLastStep: Bool {
        currentIndex >= orderedDefinitions.count - 1
    }

    private var confirmedObservations: [MobilityAssessmentObservation] {
        confirmedResultIDs
            .compactMap { id in session.results.first { $0.id == id } }
            .map { result in
                MobilityAssessmentObservation(
                    result: result,
                    comparison: MobilityAssessmentComparisonPresenter.note(
                        for: result,
                        using: modelContext
                    )
                )
            }
    }

    /// Observations grouped by zone, in the catalogue's presentation order. A
    /// zone with nothing recorded is absent rather than shown at zero: missing
    /// data is unknown, not a low value.
    private var summaryGroups: [MobilityAssessmentZoneGroup] {
        MobilityAssessmentZoneGroup.groups(
            for: session.orderedResults,
            zonesByCatalogueKey: zonesByCatalogueKey,
            using: modelContext
        )
    }

    private var zonesByCatalogueKey: [String: MobilityAssessmentZone] {
        Dictionary(
            definitions.map { ($0.catalogueKey, $0.zone) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private var skippedNames: [String] {
        session.skippedDefinitionKeys.compactMap { key in
            definitions.first { $0.catalogueKey == key }.map(MobilityAssessmentCopy.name(for:))
        }
    }

    private var summaryCountText: String {
        String(
            localized: "mobility.assessment.summary.count",
            defaultValue: "\(CountPhrase.observations(session.results.count)) saved · \(CountPhrase.assessments(session.skippedDefinitionKeys.count)) skipped"
        )
    }

    /// The gap between a left and a right observation of the same assessment,
    /// available only when both were recorded in this step.
    private func sideGapText(for observations: [MobilityAssessmentObservation]) -> String? {
        guard observations.count == 2,
              let left = observations.first(where: { $0.side == .left })?.numericValue,
              let right = observations.first(where: { $0.side == .right })?.numericValue,
              let unit = observations.first?.unit else {
            return nil
        }
        return MobilityAssessmentValueFormatter.gapText(left - right, unit: unit)
    }

    private func fieldAccessibilityLabel(
        side: MobilityAssessmentSide,
        unit: MobilityMeasurementUnit
    ) -> String {
        switch unit {
        case .degrees:
            String(
                localized: "mobility.assessment.field.degrees",
                defaultValue: "\(side.displayName), degrees"
            )
        case .centimetres:
            String(
                localized: "mobility.assessment.field.centimetres",
                defaultValue: "\(side.displayName), centimetres"
            )
        case .criteria:
            side.displayName
        }
    }

    private func valueRange(for unit: MobilityMeasurementUnit) -> ClosedRange<Double>? {
        switch unit {
        case .degrees: 0...180
        case .centimetres: 0...100
        case .criteria: nil
        }
    }

    private func numericBinding(for side: MobilityAssessmentSide) -> Binding<Double?> {
        Binding(
            get: { draft.numericValues[side.rawValue] },
            set: { newValue in
                if let newValue {
                    draft.numericValues[side.rawValue] = newValue
                } else {
                    draft.numericValues.removeValue(forKey: side.rawValue)
                }
            }
        )
    }

    // MARK: - Actions

    private func load() {
        definitions = (try? MobilityAssessmentCatalogService.definitions(
            using: modelContext,
            includeArchived: true
        )) ?? []
        prepareDraftForCurrentStep()
        if currentDefinition == nil {
            phase = .summary
        }
    }

    /// Rebuilds the draft from what the session already holds, so returning to
    /// an assessment shows the values that were saved for it rather than an
    /// empty form.
    private func prepareDraftForCurrentStep() {
        guard let definition = currentDefinition else {
            phase = .summary
            return
        }
        guard draft.definitionKey != definition.catalogueKey || phase != .entry else { return }

        let existing = session.results.filter {
            $0.definitionCatalogueKeySnapshot == definition.catalogueKey
        }
        var newDraft = EntryDraft()
        newDraft.definitionKey = definition.catalogueKey
        newDraft.setupKey = existing.first?.setupKey ?? definition.defaultSetupKey
        newDraft.isActiveRange = existing.first?.isActiveRange ?? definition.defaultIsActiveRange
        newDraft.isWarm = existing.first?.isWarm ?? false
        for result in existing {
            if let value = result.numericValue {
                newDraft.numericValues[result.sideRaw] = value
            }
            if let criteria = result.criteria {
                newDraft.criteria[result.sideRaw] = criteria
            }
        }
        draft = newDraft
        if phase == .confirmation { confirmedResultIDs = existing.map(\.id) }
    }

    private func save(_ definition: MobilityAssessmentDefinition) {
        var savedIDs: [UUID] = []
        for side in definition.supportedSides {
            guard let input = makeInput(side: side, definition: definition) else { continue }
            // Validate before writing so a rejected entry never leaves a
            // partial pair behind, and so the message names the actual problem.
            if let validationError = MobilityAssessmentValidationService.validate(
                input,
                for: definition
            ) {
                error = MobilityAssessmentErrorCopy.message(for: validationError)
                return
            }
            do {
                let result = try MobilityAssessmentSessionService.saveResult(
                    in: session,
                    definition: definition,
                    input: input,
                    using: modelContext
                )
                savedIDs.append(result.id)
            } catch {
                self.error = MobilityAssessmentErrorCopy.message(for: error)
                return
            }
        }

        guard savedIDs.isEmpty == false else {
            error = MobilityAssessmentErrorCopy.message(
                for: definition.unit == .criteria
                    ? MobilityAssessmentValidationError.missingCriteriaObservation
                    : MobilityAssessmentValidationError.missingNumericValue
            )
            return
        }

        // Everything recorded for this assessment, not only what this pass
        // wrote: a side saved on an earlier pass is still part of the record,
        // and showing it is what makes the confirmation trustworthy.
        confirmedResultIDs = session.orderedResults
            .filter { $0.definitionCatalogueKeySnapshot == definition.catalogueKey }
            .map(\.id)
        saveCount += 1
        phase = .confirmation
    }

    private func makeInput(
        side: MobilityAssessmentSide,
        definition: MobilityAssessmentDefinition
    ) -> MobilityAssessmentResultInput? {
        let numericValue = draft.numericValues[side.rawValue]
        let criteria = draft.criteria[side.rawValue]
        switch definition.unit {
        case .criteria:
            guard criteria != nil else { return nil }
        case .degrees, .centimetres:
            guard numericValue != nil else { return nil }
        }

        return MobilityAssessmentResultInput(
            numericValue: definition.unit == .criteria ? nil : numericValue,
            criteria: definition.unit == .criteria ? criteria : nil,
            side: side,
            isWarm: draft.isWarm,
            setupKey: draft.setupKey,
            method: definition.manualMode,
            unit: definition.unit,
            isActiveRange: draft.isActiveRange,
            // The session's day, not today's: an assessment started before
            // midnight stays one sitting.
            day: session.day,
            source: .manual,
            // A hand-entered value is moderate at best, and the record says so.
            confidence: .moderate
        )
    }

    private func advance() {
        do {
            try MobilityAssessmentSessionService.advance(session, using: modelContext)
        } catch {
            self.error = MobilityAssessmentErrorCopy.message(for: error)
            return
        }
        confirmedResultIDs = []
        moveToNextStep()
    }

    private func skipCurrent() {
        do {
            try MobilityAssessmentSessionService.skipCurrent(session, using: modelContext)
        } catch {
            self.error = MobilityAssessmentErrorCopy.message(for: error)
            return
        }
        confirmedResultIDs = []
        moveToNextStep()
    }

    private func moveToNextStep() {
        if currentDefinition == nil {
            phase = .summary
        } else {
            // Phase first: the draft rebuild reads it, and rebuilding while the
            // view still believes it is confirming would restore the identifiers
            // that were just cleared.
            phase = .instruction
            prepareDraftForCurrentStep()
        }
    }

    private func complete() {
        do {
            try MobilityAssessmentSessionService.complete(session, using: modelContext)
        } catch {
            self.error = MobilityAssessmentErrorCopy.message(for: error)
            return
        }
        onFinished()
    }

    private func stop() {
        do {
            try MobilityAssessmentSessionService.stop(session, using: modelContext)
        } catch {
            self.error = MobilityAssessmentErrorCopy.message(for: error)
            return
        }
        onFinished()
    }
}
