import SwiftData
import SwiftUI

/// One fact about a plan.
///
/// Deliberately neutral rather than `gymPrimary`: this design system reserves
/// the primary tint for actions, and three primary-coloured capsules sitting
/// directly above the one real action on this screen competed with it instead
/// of supporting it. Metadata describes; it does not invite a tap.
struct ProgramMetaChip: View {
    let text: String

    var body: some View {
        // Not `LocalizedStringKey`. Every call site passes a string that is
        // already localized or already interpolated, so the lookup could only
        // ever miss and fall back to the text it was handed.
        Text(text)
            .font(AppFont.captionBold)
            .foregroundStyle(Color.gymSubduedText)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(Color.gymRowSurface, in: Capsule())
    }
}

/// What the owner of this screen did with a compiled plan.
///
/// Activation cannot be decided here. Whether a plan may start depends on what
/// else is already running, and that is knowledge the navigation owner holds —
/// see `ProgramCatalogDetailView.activate(_:startDate:)` for why this screen
/// stopped starting runs itself.
enum ProgramActivationOutcome: Equatable {
    /// The run started.
    case started
    /// The owner took the decision over — a conflict dialog, or its own error
    /// presentation. Nothing started, and this screen must not claim it did.
    case handledByOwner
    /// Nothing started, and this screen owns telling the lifter why.
    case refused(String)
}

struct ProgramCatalogDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var exercises: [Exercise]
    /// The persisted answers, read live so editing them in Settings and
    /// returning here re-evaluates with nothing to invalidate.
    @Query private var trainingProfiles: [TrainingProfile]
    let record: ProgramDefinitionRecord
    /// Starts the compiled plan through the owner's guarded path.
    ///
    /// This screen used to call `PlanCoordinator.startRun` directly, which made
    /// it the one activation surface in the app that could not see an existing
    /// run: activating a catalogue plan while already following one produced two
    /// active `PlanRun`s, and `HomeView` shows a plan only when there is exactly
    /// one — so Today went blank while two plans were running.
    let onStartPlan: (WorkoutPlan, Date) -> ProgramActivationOutcome
    /// Activation used to leave the user on this screen with a disabled "Plan
    /// added" label and no indication of what changed. The owner of the
    /// navigation stack pops back to Train instead, where the plan is now
    /// visible as the one being followed.
    let onActivated: () -> Void

    @State private var errorMessage: String?
    @State private var isShowingSetup = false

    private var payload: ProgramDefinitionPayload? { try? record.payload() }

    init(
        record: ProgramDefinitionRecord,
        onStartPlan: @escaping (WorkoutPlan, Date) -> ProgramActivationOutcome,
        onActivated: @escaping () -> Void
    ) {
        self.record = record
        self.onStartPlan = onStartPlan
        self.onActivated = onActivated

        var descriptor = FetchDescriptor<TrainingProfile>()
        descriptor.fetchLimit = 1
        _trainingProfiles = Query(descriptor)
    }

    private var exerciseNamesByID: [UUID: String] {
        Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.name) })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                overview
                whyItFits
                requirements
                prescription
                provenance
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.l)
        }
        .accessibilityIdentifier("program-catalog-detail")
        .folderScreenStyle()
        // The action is pinned rather than trailing the scroll. It used to be
        // the last element of a screen whose length depends on how much a plan
        // declares, so a plan with several prerequisites pushed the only way
        // forward below the fold. `OnboardingRecommendationsView` pins its
        // primary action for the same reason.
        .safeAreaInset(edge: .bottom) { activation }
        // Named, so the screen is still identifiable once the display title has
        // scrolled away — it is reached from a list of twenty-odd plans that
        // differ mainly by name.
        .navigationTitle(record.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingSetup) {
            if let payload {
                NavigationStack {
                    ProgramActivationSetupView(payload: payload) { configuredPayload, startDate in
                        try activate(configuredPayload, startDate: startDate)
                    }
                }
            }
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(record.name)
                .font(AppFont.displayMedium)
                .foregroundStyle(Color.gymText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let summary = record.summary {
                Text(summary)
                    .font(AppFont.body)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // Flowing rather than a fixed `HStack`: four capsules on one line
            // overflow the moment Dynamic Type grows, and this screen is the
            // last thing a lifter reads before committing twelve weeks.
            ChipFlowLayout(spacing: Spacing.s) {
                ForEach(metaChips, id: \.self) { chip in
                    ProgramMetaChip(text: chip)
                }
            }
            // One VoiceOver stop for the whole strip. Read individually, four
            // capsules are four swipes of context-free fragments.
            .accessibilityElement(children: .combine)
            .accessibilityLabel(metaChips.joined(separator: ", "))
        }
    }

    /// The facts a lifter needs before opening a plan, in decision order.
    ///
    /// Goal leads because it is the one thing that says what the plan is *for*,
    /// it is authored on every bundled definition, and it was previously shown
    /// nowhere in discovery — neither here nor on the row that reaches here.
    private var metaChips: [String] {
        var chips = [
            record.goal.onboardingTitle,
            record.experienceLevel.onboardingTitle
        ]
        // A plan that supports several week shapes says so — collapsing "3 or 4
        // days" to one number would be a quiet half-truth on the screen where
        // the choice is made. A plan that declares none says nothing at all
        // rather than "0 days/week".
        switch record.supportedDaysPerWeek.count {
        case 0:
            break
        case 1:
            chips.append(CountPhrase.daysPerWeekAbbreviated(record.supportedDaysPerWeek[0]))
        default:
            chips.append(
                record.supportedDaysPerWeek.map(String.init).joined(separator: "/")
                    + String(localized: " days/week")
            )
        }
        chips.append(String(localized: "\(record.durationWeeks) weeks"))
        if let payload, payload.scheduleMode == .sequential {
            // Only the non-obvious mode is worth a chip. "Fixed weekdays" is
            // what a plan is assumed to be; running in order regardless of the
            // calendar is the thing that changes how a week feels.
            chips.append(String(localized: "In order, not on fixed days"))
        }
        return chips
    }

    /// This plan measured against what the lifter actually told us.
    ///
    /// `nil` — and therefore no section at all — whenever there is nothing
    /// honest to say: no profile, or a profile that answers nothing. An
    /// existing user who has never seen onboarding has a `TrainingProfile`
    /// full of `nil`, and evaluating against it would produce a "why this fits
    /// you" heading above an empty result, which claims a comparison that
    /// never happened.
    private var matchResult: ProgramMatchResult? {
        guard let payload, let profile = trainingProfiles.first else { return nil }
        let criteria = profile.matchingCriteria
        guard !criteria.isEmpty else { return nil }
        return ProgramMatchService.evaluate(
            ProgramMatchCandidate(payload: payload),
            criteria: criteria
        )
    }

    /// The mismatches this screen found by comparing an answer against a
    /// declaration — not the ones the author simply wrote down.
    ///
    /// `ProgramMatchService` folds `candidate.authorWarnings` into the same
    /// `warnings` array as its own derived findings, and `requirements` below
    /// already renders those author warnings unconditionally under "Worth
    /// knowing". Showing the array raw here would print every author warning
    /// twice on the same screen. Excluding them is not deduplication for its
    /// own sake: "what doesn't match" is a claim about *the lifter's answers*,
    /// and a warning the author would have written for anybody is not that.
    private var derivedWarnings: [ProgramMatchWarning] {
        guard let result = matchResult else { return [] }
        let authored = Set(payload?.warnings ?? [])
        return result.warnings.filter { !authored.contains($0.text) }
    }

    @ViewBuilder
    private var whyItFits: some View {
        if let result = matchResult, !result.reasons.isEmpty || !derivedWarnings.isEmpty {
            sectionCard(title: "Why this fits you") {
                // Deliberately no score, percentage, or star rating. The
                // service's `score` is an unbounded weight sum with no declared
                // maximum — rendering it as "87% match" would invent a
                // precision the ranking does not have.
                if !result.reasons.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        ForEach(result.reasons) { reason in
                            Label {
                                Text(reason.text)
                                    .foregroundStyle(Color.gymText)
                                    .fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: AppIcon.checkmark)
                                    .foregroundStyle(Color.gymSecondary)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        String(localized: "Why it matches: \(result.reasons.map(\.text).joined(separator: ", "))")
                    )
                }

                if !derivedWarnings.isEmpty {
                    if !result.reasons.isEmpty {
                        Divider().overlay(Color.gymBorder)
                    }
                    Text("What doesn’t match")
                        .font(AppFont.captionBold)
                        .foregroundStyle(Color.gymSubduedText)
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        ForEach(derivedWarnings) { warning in
                            Label {
                                Text(warning.text)
                                    .foregroundStyle(Color.gymText)
                                    .fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: AppIcon.warningCircle)
                                    .foregroundStyle(Color.gymDestructive)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        String(localized: "What doesn’t match: \(derivedWarnings.map(\.text).joined(separator: ", "))")
                    )
                }
            }
            .font(AppFont.subheadline)
            .accessibilityIdentifier("program-catalog-why-it-fits")
        }
    }

    /// Where the plan came from, when it says.
    ///
    /// Omitted entirely when absent, rather than shown as "Unknown". A missing
    /// provenance is a legitimate silence — there is nothing the lifter can do
    /// about it and nothing it changes about the prescription — unlike a
    /// missing *answer*, which they can act on. Provenance is descriptive only:
    /// it never alters what the plan prescribes.
    @ViewBuilder
    private var provenance: some View {
        if let provenance = payload?.provenance {
            sectionCard(title: "Where this plan comes from") {
                Text(provenanceTitle(provenance.kind))
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymText)
                    .fixedSize(horizontal: false, vertical: true)

                if let statement = provenance.statement, !statement.isEmpty {
                    Text(statement)
                        .foregroundStyle(Color.gymSubduedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .font(AppFont.subheadline)
            .accessibilityIdentifier("program-catalog-provenance")
        }
    }

    /// Deliberately phrased so none of these claims endorsement by, or
    /// authorship from, whoever published the underlying method. "Follows a
    /// published format" and "is the official programme" are different
    /// statements, and only the first is one Trame can make.
    private func provenanceTitle(_ kind: ProgramProvenanceKind) -> String {
        switch kind {
        case .sourceBackedExactFormat:
            String(localized: "Follows a published programme format")
        case .sourceBackedOriginalAdaptation:
            String(localized: "Adapted from a published source")
        case .guidelineAnchoredOriginalProgram:
            String(localized: "Built on published training guidelines")
        case .researchAnchoredOriginalProgram:
            String(localized: "Built on published research")
        case .engineConformanceSynthetic:
            // The one kind a lifter genuinely needs to read before starting:
            // this plan exists to exercise the app's engine, not as training
            // advice authored for a person.
            String(localized: "Built to demonstrate app features, not as training advice")
        }
    }

    /// Two blocks, never one.
    ///
    /// A prerequisite and an author warning used to share a card and differ
    /// only by icon — and the prerequisite wore `checkmarkCircle` in
    /// `gymSecondary`, this system's *completion* token, so "around six months
    /// of consistent training" read as a box already ticked. Nothing in the app
    /// verifies a prerequisite: `ProgramMatchService` is explicit that they are
    /// unverifiable author-written conditions, disclosed and never scored. The
    /// iconography here now matches `OnboardingRecommendationCard`, which had
    /// it right — neutral `info` for what the author expects, `warningCircle`
    /// for what the app has actually found.
    @ViewBuilder
    private var requirements: some View {
        if let payload {
            if !payload.prerequisites.isEmpty {
                sectionCard(title: "Before you start") {
                    Text("Written by the plan's author. Trame can't check these for you.")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(payload.prerequisites, id: \.self) { item in
                        Label {
                            Text(item)
                                .foregroundStyle(Color.gymSubduedText)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: AppIcon.info)
                                .foregroundStyle(Color.gymSubduedText)
                        }
                    }
                }
                .font(AppFont.subheadline)
                .accessibilityIdentifier("program-catalog-prerequisites")
            }

            if !payload.warnings.isEmpty {
                sectionCard(title: "Worth knowing") {
                    ForEach(payload.warnings, id: \.self) { warning in
                        Label {
                            Text(warning)
                                .foregroundStyle(Color.gymText)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: AppIcon.warningCircle)
                                .foregroundStyle(Color.gymDestructive)
                        }
                    }
                }
                .font(AppFont.subheadline)
                .accessibilityIdentifier("program-catalog-warnings")
            }
        }
    }

    @ViewBuilder
    private var prescription: some View {
        if let payload,
           let rows = try? ProgramDefinitionPreview.rows(for: payload),
           case let preview = weekOnePreview(from: rows),
           !preview.shown.isEmpty {
            let names = exerciseNamesByID
            let workouts = preview.shown

            sectionCard(title: "Week 1 preview") {
                ForEach(Array(workouts.enumerated()), id: \.offset) { index, workout in
                    if index > 0 {
                        Divider().overlay(Color.gymBorder)
                    }
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Text(workout.name.uppercased())
                            .font(AppFont.captionBold)
                            .tracking(0.8)
                            .foregroundStyle(Color.gymSubduedText)
                        ForEach(Array(workout.rows.enumerated()), id: \.offset) { _, row in
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                HStack {
                                    Text(names[row.exerciseID] ?? row.exposureKey)
                                        .font(AppFont.bodyMedium)
                                        .foregroundStyle(Color.gymText)
                                    Spacer()
                                    Text("\(row.setCount) sets")
                                        .font(AppFont.subheadlineMonospaced)
                                        .foregroundStyle(Color.gymSubduedText)
                                }
                                if let executionBlock = row.executionBlock {
                                    Label(
                                        "\(executionBlock.name ?? executionBlock.kind.title) · component \((row.executionBlockComponentOrder ?? 0) + 1) of \(executionBlock.componentCount)",
                                        systemImage: AppIcon.relationship
                                    )
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.trameAction)
                                }
                            }
                        }
                    }
                }
                if preview.hiddenSessionCount > 0 {
                    Text("Plus \(CountPhrase.sessions(preview.hiddenSessionCount)) more in week 1")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// Whole sessions from week one, and how many were left out.
    ///
    /// The preview used to take a flat `prefix(8)` of prescription rows and
    /// group afterwards, so the cut landed wherever row eight happened to fall
    /// — inside a workout, silently. A four-exercise lower day whose last two
    /// rows were trimmed rendered as a two-exercise lower day, which is not a
    /// shortened preview but a wrong one, on the screen a lifter uses to
    /// compare plans. Truncation now falls on a session boundary, the first
    /// session is always whole however long it is, and the omission is counted
    /// in the same unit as the heading rather than in raw exercise rows.
    private func weekOnePreview(
        from rows: [ProgramDefinitionPreviewRow]
    ) -> (shown: [(name: String, rows: [ProgramDefinitionPreviewRow])], hiddenSessionCount: Int) {
        let sessions = groupedByWorkout(rows.filter { $0.weekIndex == 0 })
        var shown: [(name: String, rows: [ProgramDefinitionPreviewRow])] = []
        var remainingRows = 8
        for session in sessions {
            if !shown.isEmpty && session.rows.count > remainingRows { break }
            shown.append(session)
            remainingRows -= session.rows.count
            if remainingRows <= 0 { break }
        }
        return (shown, sessions.count - shown.count)
    }

    /// Sessions in order, named by the workout alone — the card heading already
    /// establishes the week, so repeating it on every group was noise.
    private func groupedByWorkout(
        _ rows: [ProgramDefinitionPreviewRow]
    ) -> [(name: String, rows: [ProgramDefinitionPreviewRow])] {
        var groups: [(name: String, rows: [ProgramDefinitionPreviewRow])] = []
        for row in rows {
            let name = row.workoutName
            if let lastIndex = groups.indices.last, groups[lastIndex].name == name {
                groups[lastIndex].rows.append(row)
            } else {
                groups.append((name: name, rows: [row]))
            }
        }
        return groups
    }

    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(title)
                .font(AppFont.titleSmall)
                .foregroundStyle(Color.gymText)
                // Lets VoiceOver's rotor jump section to section. This is the
                // longest screen in the discovery flow, and without the trait
                // the only way past the week-one preview was to swipe through
                // every exercise in it.
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: Spacing.m) {
                content()
            }
            .padding(Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Radius.large)
                    .fill(Color.gymCard)
                    .stroke(Color.gymBorder, lineWidth: 1)
            }
        }
    }

    private var activation: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            if let errorMessage {
                Label(errorMessage, systemImage: AppIcon.warningCircle)
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymDestructive)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("program-catalog-error")
            }
            // The app's own dominant command, not the system's: the one
            // committing action in discovery is drawn by the same rules as
            // Finish Workout and every other commit. The play glyph went with
            // it — it decorated a label that already names the action, and
            // promised an immediate start this button does not perform.
            Button {
                isShowingSetup = true
            } label: {
                Text("Use this plan")
            }
            .buttonStyle(.tramePrimaryAction)
            .accessibilityIdentifier("use-program")
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.m)
        .padding(.bottom, Spacing.s)
        // Opaque, so the preview card scrolling underneath reads as passing
        // behind the bar rather than as being clipped by it.
        .background(Color.gymBackground)
    }

    /// Compiles the plan and hands it to the owner to start.
    ///
    /// The compile and the insert stay here — they are this screen's knowledge
    /// of the catalogue. Whether the resulting plan may *become the active one*
    /// is not: that depends on what is already running, which is the navigation
    /// owner's business, and calling `PlanCoordinator.startRun` from here
    /// bypassed the guard every other plan-start surface goes through.
    private func activate(_ payload: ProgramDefinitionPayload, startDate: Date) throws {
        let exercises = try modelContext.fetch(FetchDescriptor<Exercise>())
        let plan = try ProgramDefinitionCompiler.compile(
            payload,
            exercisesByID: Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        )
        modelContext.insert(plan)

        switch onStartPlan(plan, startDate) {
        case .started:
            errorMessage = nil
            onActivated()
        case .handledByOwner:
            // A conflict dialog, or the owner's own error, is now presented
            // above this stack. Leaving is what makes it visible; claiming the
            // plan started would be a lie, so nothing here says so.
            errorMessage = nil
            // The callback is invoked from the setup sheet's confirmation
            // action. Mutating the owning navigation path in that same
            // presentation turn races the sheet dismissal on iOS 26 and can
            // kill the UI test runner before the conflict dialog is rendered.
            // Let the sheet finish its transition, then replace the detail
            // path so the owner-owned dialog remains visible and cancellable.
            DispatchQueue.main.async {
                onActivated()
            }
        case .refused(let message):
            // Nothing started, so nothing should be left behind. This plan was
            // compiled a moment ago for this activation alone; without the
            // delete it would persist as a plan the lifter never created and
            // would then find in "Mine".
            modelContext.delete(plan)
            // Thrown rather than assigned, so the setup sheet stays open with
            // the reason attached to the control the lifter just used, instead
            // of dismissing onto a message they would have to go looking for.
            throw ProgramActivationRefusal(message: message)
        }
    }
}

/// A refusal the lifter can act on, phrased by whoever knows why.
private struct ProgramActivationRefusal: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private struct ProgramActivationSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    let payload: ProgramDefinitionPayload
    let onActivate: (ProgramDefinitionPayload, Date) throws -> Void

    @State private var values: [String: String] = [:]
    @State private var startDate = Date.now
    @State private var validationMessage: String?
    @State private var isSaving = false

    var body: some View {
        Form {
            Section("Schedule") {
                DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                LabeledContent("Training frequency", value: frequencyText)
            }

            if payload.intakeInputs.isEmpty {
                Section {
                    Text("This plan does not require starting values. You can adjust loads during your first workout.")
                        .foregroundStyle(Color.gymSubduedText)
                }
            } else {
                Section {
                    ForEach(Array(payload.intakeInputs.enumerated()), id: \.offset) { _, input in
                        if input.kind == .startingVariation {
                            Picker(inputTitle(input), selection: valueBinding(for: input)) {
                                Text("Select").tag("")
                                ForEach(variations(for: input), id: \.id) { exercise in
                                    Text(exercise.name).tag(exercise.id.uuidString)
                                }
                            }
                            .accessibilityHint(input.exposureKey)
                        } else {
                            HStack {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(inputTitle(input))
                                Text(inputDetail(input))
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.gymSubduedText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            TextField(input.kind == .probeVelocity ? "m/s" : "kg", text: valueBinding(for: input))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(minWidth: 88)
                                .accessibilityLabel(inputTitle(input))
                            }
                        }
                    }
                } header: {
                    Text("Starting values")
                } footer: {
                    // The old footer explained units and stopped there, which
                    // left the impression that one number had to be right for
                    // every lift in the plan before it could start. It does
                    // not: a plan-wide value is a seed for the first
                    // prescription, and every load is editable in the workout
                    // that uses it. Saying so is what makes a single field
                    // across squats and curls credible.
                    Text("Loads use kilograms and bar velocity uses metres per second. Optional values can be left blank. Every load stays editable in the workout that uses it, so a rough starting point is enough.")
                }
            }

            if let validationMessage {
                Section {
                    Label(validationMessage, systemImage: AppIcon.warning)
                        .foregroundStyle(Color.gymDestructive)
                        .accessibilityIdentifier("program-intake-error")
                }
            }

            Section {
                Button {
                    activate()
                } label: {
                    HStack {
                        Spacer()
                        if isSaving { ProgressView() }
                        Text("Start plan")
                        Spacer()
                    }
                }
                .disabled(isSaving)
                .accessibilityIdentifier("start-program")
            }
        }
        .navigationTitle("Set Up Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .interactiveDismissDisabled(isSaving)
        .accessibilityIdentifier("program-intake")
    }

    private var frequencyText: String {
        payload.supportedDaysPerWeek.map(String.init).joined(separator: " or ") + " days per week"
    }

    private func inputTitle(_ input: ProgramIntakeInput) -> String {
        switch input.kind {
        case .oneRepMax: return "One-rep max"
        case .estimatedOneRepMaxReps: return "Estimated one-rep max"
        case .trainingMax: return "Training Max"
        // A `*` exposure key seeds every exercise in the plan, so calling it
        // "Starting load" invited the reasonable objection that no single
        // number is the starting load for both a squat and a curl. It is a
        // default, and the label now says which of the two it is.
        case .startingLoad: return input.appliesToEveryExercise ? "Default starting load" : "Starting load"
        case .startingVariation: return "Starting variation"
        case .probeVelocity: return "Probe velocity"
        }
    }

    /// The caption under an input: which exercise it is for, or — for a
    /// plan-wide default — what actually happens to it afterwards.
    private func inputDetail(_ input: ProgramIntakeInput) -> String {
        guard input.appliesToEveryExercise else { return input.exposureKey }
        return String(localized: "Seeds every exercise · adjust each one in the workout that uses it")
    }

    private func valueBinding(for input: ProgramIntakeInput) -> Binding<String> {
        let key = "\(input.exposureKey)|\(input.kind.rawValue)"
        return Binding(
            get: { values[key, default: ""] },
            set: { values[key] = $0 }
        )
    }

    private func variations(for input: ProgramIntakeInput) -> [Exercise] {
        let ids = Set(payload.blocks.flatMap(\.weeks).flatMap(\.workouts).flatMap(\.plannedExercises)
            .filter { $0.exposureKey == input.exposureKey }
            .flatMap { $0.variationExerciseIDs ?? [] })
        return exercises.filter { ids.contains($0.id) }
    }

    private func activate() {
        do {
            var configured = payload
            for input in payload.intakeInputs {
                let key = "\(input.exposureKey)|\(input.kind.rawValue)"
                let text = values[key, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty {
                    guard !input.isRequired else {
                        throw ProgramIntakeError.missing(inputTitle(input), input.exposureKey)
                    }
                    continue
                }
                if input.kind == .startingVariation {
                    guard let exerciseID = UUID(uuidString: text) else {
                        throw ProgramIntakeError.invalid(inputTitle(input), input.exposureKey)
                    }
                    configured.applyStartingVariation(exerciseID, input: input)
                    continue
                }
                guard let value = Double(text.replacingOccurrences(of: ",", with: ".")), value > 0 else {
                    throw ProgramIntakeError.invalid(inputTitle(input), input.exposureKey)
                }
                configured.applyIntake(value, input: input)
            }
            isSaving = true
            try onActivate(configured, startDate)
            dismiss()
        } catch {
            isSaving = false
            validationMessage = error.localizedDescription
        }
    }
}

private enum ProgramIntakeError: LocalizedError {
    case missing(String, String)
    case invalid(String, String)

    var errorDescription: String? {
        switch self {
        case .missing(let name, let exposure): return "Enter \(name.lowercased()) for \(exposure)."
        case .invalid(let name, let exposure): return "Enter a positive \(name.lowercased()) for \(exposure)."
        }
    }
}

private extension ProgramDefinitionPayload {
    mutating func applyIntake(_ value: Double, input: ProgramIntakeInput) {
        for blockIndex in blocks.indices {
            for weekIndex in blocks[blockIndex].weeks.indices {
                for workoutIndex in blocks[blockIndex].weeks[weekIndex].workouts.indices {
                    for exerciseIndex in blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises.indices {
                        var exercise = blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises[exerciseIndex]
                        guard input.appliesToEveryExercise || exercise.exposureKey == input.exposureKey else { continue }
                        switch input.kind {
                        case .oneRepMax:
                            exercise.initialActualOneRepMax = value
                            exercise.initialTrainingMax = value * (input.defaultPercentOfMax ?? 0.9)
                        case .estimatedOneRepMaxReps:
                            exercise.initialEstimatedOneRepMax = value
                        case .trainingMax:
                            exercise.initialTrainingMax = value
                        case .startingLoad:
                            exercise.initialLoad = value
                        case .probeVelocity:
                            exercise.initialVelocityBaseline = value
                        case .startingVariation:
                            break
                        }
                        blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises[exerciseIndex] = exercise
                    }
                }
            }
        }
    }

    mutating func applyStartingVariation(_ exerciseID: UUID, input: ProgramIntakeInput) {
        for blockIndex in blocks.indices {
            for weekIndex in blocks[blockIndex].weeks.indices {
                for workoutIndex in blocks[blockIndex].weeks[weekIndex].workouts.indices {
                    for exerciseIndex in blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises.indices {
                        var exercise = blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises[exerciseIndex]
                        guard exercise.exposureKey == input.exposureKey,
                              exercise.variationExerciseIDs?.contains(exerciseID) == true else { continue }
                        exercise.initialVariationExerciseID = exerciseID
                        blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises[exerciseIndex] = exercise
                    }
                }
            }
        }
    }
}
