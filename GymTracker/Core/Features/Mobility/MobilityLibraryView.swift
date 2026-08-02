import SwiftData
import SwiftUI

struct MobilityLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let onStart: (MobilityRoutine, MobilitySessionContext, UUID?) -> Void
    /// Assessment presentation is root-owned, so this screen forwards the
    /// request upward rather than presenting the flow itself.
    let onStartAssessment: (MobilityAssessmentSession) -> Void

    @Query(sort: \MobilityRoutine.updatedAt, order: .reverse) private var routines: [MobilityRoutine]
    @Query(sort: \MobilityDefinition.name) private var definitions: [MobilityDefinition]
    @Query(sort: \MobilitySession.startTime, order: .reverse) private var sessions: [MobilitySession]
    @Query private var workouts: [Workout]
    @Query(sort: \MobilityAssessmentSession.startedAt, order: .reverse)
    private var assessmentSessions: [MobilityAssessmentSession]
    @Query private var assessmentDefinitions: [MobilityAssessmentDefinition]
    @State private var selectedRoutine: MobilityRoutine?
    @State private var isShowingDefinitions = false
    @State private var isShowingAssessmentLanding = false
    @State private var sessionContext: MobilitySessionContext = .standalone
    /// View-local. A filter is a momentary way of looking at the library, not
    /// a preference, so it is deliberately not persisted.
    @State private var purposeFilter: MobilityPurposeFilter = .all
    private let featureFlags: FeatureFlagConfiguration = FeatureFlags.current

    var body: some View {
        List {
            // The hub leads with the assessment because it is the only surface
            // here that produces evidence; routines are the work it points at.
            // Gated because the assessment UI is unfinished while its data model
            // is not: with the flag off, this screen is the routine library it
            // was before assessments existed, and no persisted assessment is
            // touched or migrated.
            if featureFlags.isEnabled(.mobilityAssessment) {
                Section {
                    assessmentCard
                        .listRowInsets(EdgeInsets(top: Spacing.s, leading: 0, bottom: Spacing.s, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

            Section {
                if availableRoutines.isEmpty {
                    ContentUnavailableView(
                        "No mobility routines",
                        systemImage: AppIcon.mobility,
                        description: Text("Create a short routine to begin mobility work.")
                    )
                } else {
                    purposeFilterChips
                }

                // The context belongs to starting a routine, not to the screen.
                // At the top it read as a global setting for a hub that also
                // holds assessments, which it never applied to.
                Picker("Session context", selection: $sessionContext) {
                    ForEach(MobilitySessionContext.allCases, id: \.self) { context in
                        Text(context.displayName).tag(context)
                    }
                }
                .disabled(sessionContext != .standalone && activeWorkout == nil)
            } header: {
                Text("Routines")
            } footer: {
                Text("Starting a routine snapshots its movement targets and instructions into a separate mobility session.")
            }

            ForEach(visibleGroups) { group in
                Section {
                    ForEach(group.routines) { routine in
                        routineRow(routine)
                    }
                } header: {
                    Text(groupTitle(for: group))
                        .accessibilityIdentifier("mobility-purpose-section-\(group.id)")
                }
            }

            if availableRoutines.isEmpty == false, visibleGroups.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("No routines with this purpose", systemImage: AppIcon.filters)
                    } description: {
                        Text("Every routine stays available — only this view is filtered.")
                    } actions: {
                        Button("Show all routines") { purposeFilter = .all }
                            .accessibilityIdentifier("clear-mobility-purpose-filter")
                    }
                }
            }

            Section {
                Button {
                    selectedRoutine = createRoutine()
                } label: {
                    Label("New routine", systemImage: AppIcon.plus)
                }
                .accessibilityIdentifier("create-mobility-routine")
            }

            Section {
                Button {
                    isShowingDefinitions = true
                } label: {
                    Label("Manage movements", systemImage: AppIcon.mobility)
                }
                .accessibilityIdentifier("manage-mobility-definitions")

                // Recently performed movements are supporting detail for the
                // movement library, not a destination of their own.
                ForEach(recentMovementNames, id: \.self) { name in
                    Text(name)
                        .font(AppFont.subheadline)
                        .foregroundStyle(Color.gymSubduedText)
                }
            } header: {
                Text("Movements")
            } footer: {
                if recentMovementNames.isEmpty == false {
                    Text("Movements listed here are the ones your recent sessions recorded.")
                }
            }

            Section {
                historyLink(
                    title: String(localized: "Mobility routines"),
                    detail: routineHistoryDetail,
                    icon: AppIcon.mobility,
                    identifier: "open-mobility-routine-history"
                ) {
                    MobilityHistoryView()
                }

                if featureFlags.isEnabled(.mobilityAssessment) {
                    historyLink(
                        title: String(localized: "Mobility assessments"),
                        detail: assessmentHistoryDetail,
                        icon: AppIcon.mobilityAssessment,
                        identifier: "open-mobility-assessment-history-from-hub"
                    ) {
                        MobilityAssessmentHistoryView()
                    }
                }
            } header: {
                Text("History")
            } footer: {
                // Two different kinds of record. Naming both is what keeps a
                // performed routine from being read as an observation. With
                // assessments gated off there is only one kind on screen, so the
                // distinction would describe something the user cannot see.
                if featureFlags.isEnabled(.mobilityAssessment) {
                    Text("Routine history records the work you performed. Assessment history records what you observed.")
                } else {
                    Text("Routine history records the work you performed.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Mobility")
        .navigationDestination(isPresented: $isShowingAssessmentLanding) {
            MobilityAssessmentLandingView(onStart: onStartAssessment)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .sheet(item: $selectedRoutine) { routine in
            NavigationStack {
                MobilityRoutineEditorView(routine: routine)
            }
        }
        .sheet(isPresented: $isShowingDefinitions) {
            NavigationStack {
                MobilityDefinitionsView()
            }
        }
    }

    // MARK: - Assessment card

    /// Three states, one card. An assessment in progress outranks everything
    /// else on the screen because resuming it is the only action here that can
    /// lose work if it is missed.
    ///
    /// Each state carries exactly one action, which is what lets the card sit in
    /// a `List` row without its controls competing for the same tap.
    @ViewBuilder
    private var assessmentCard: some View {
        if let activeAssessment {
            GymCard(variant: .current) {
                GymEyebrow("In progress", tint: .gymPrimary)
                Text("Assessment in progress")
                    .font(AppFont.titleSmall)
                    .foregroundStyle(Color.gymText)
                Text(assessmentProgressDetail(activeAssessment))
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)

                // Resuming goes straight back into the flow. Routing it through
                // the landing screen first would put a menu between the lifter
                // and the work they already started.
                Button("Continue assessment") { onStartAssessment(activeAssessment) }
                    .buttonStyle(.gymPrimary)
                    .accessibilityIdentifier("resume-mobility-assessment-from-hub")
            }
        } else if let lastRecordedAssessment {
            GymCard {
                GymEyebrow("Assessment")
                Text(assessmentDateText(lastRecordedAssessment))
                    .font(AppFont.titleSmall)
                    .foregroundStyle(Color.gymText)
                Text(assessmentObservationCount(lastRecordedAssessment))
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymSubduedText)

                assessmentLink(title: String(localized: "Open assessment"))
            }
        } else {
            GymCard {
                GymEyebrow("Assessment")
                Text("Measure your mobility")
                    .font(AppFont.titleSmall)
                    .foregroundStyle(Color.gymText)
                Text(assessmentInvolvementDetail)
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)

                assessmentLink(title: String(localized: "Get started"))
            }
        }
    }

    /// A plain button plus an explicit destination rather than a
    /// `NavigationLink`. A link nested inside a card inside a `List` row makes
    /// the whole row the link and adds a system disclosure chevron beside the
    /// primary button, which is not what this card should look like.
    private func assessmentLink(title: String) -> some View {
        Button(title) { isShowingAssessmentLanding = true }
            .buttonStyle(.gymPrimary)
            .accessibilityIdentifier("open-mobility-assessment")
    }

    private func historyLink<Destination: View>(
        title: String,
        detail: String,
        icon: String,
        identifier: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            Label {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(AppFont.subheadlineSemibold)
                    Text(detail)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                }
            } icon: {
                GymIconChip(systemImage: icon)
            }
        }
        .accessibilityIdentifier(identifier)
    }

    private var activeAssessment: MobilityAssessmentSession? {
        assessmentSessions.first { $0.status == .active }
    }

    /// A sitting that saved nothing measured nothing, so it never becomes the
    /// card's "last assessment".
    private var lastRecordedAssessment: MobilityAssessmentSession? {
        assessmentSessions.first { $0.status != .active && $0.results.isEmpty == false }
    }

    private func assessmentDateText(_ session: MobilityAssessmentSession) -> String {
        let date = session.startedAt.formatted(.dateTime.month(.abbreviated).day().year())
        guard isStale(session) else { return date }
        // A restatement of the date, not a prompt to act. There is deliberately
        // no colour, icon, threshold styling, or re-measure nag attached to it.
        return String(
            localized: "mobility.assessment.hub.dated",
            defaultValue: "\(date) · \(session.startedAt.formatted(.relative(presentation: .named)))"
        )
    }

    /// Eight weeks, matching the plan's stale threshold. It changes the wording
    /// and nothing else.
    private func isStale(_ session: MobilityAssessmentSession) -> Bool {
        session.startedAt < Date.now.addingTimeInterval(-56 * 24 * 60 * 60)
    }

    private func assessmentObservationCount(_ session: MobilityAssessmentSession) -> String {
        CountPhrase.observations(session.results.count)
    }

    private func assessmentProgressDetail(_ session: MobilityAssessmentSession) -> String {
        String(
            localized: "mobility.assessment.progress.detail",
            defaultValue: "Started \(session.startedAt.formatted(.dateTime.month(.abbreviated).day().year())) · \(assessmentObservationCount(session)) saved so far"
        )
    }

    /// What it involves, counted from the installed catalogue rather than a
    /// hardcoded number, and with no time estimate: how long a hand-entered
    /// assessment takes is not something this screen can honestly claim.
    private var assessmentInvolvementDetail: String {
        String(
            localized: "mobility.assessment.hub.involves",
            defaultValue: "\(CountPhrase.assessments(availableAssessmentCount)), each entered by hand. You need wall and floor space, and you can skip any of them."
        )
    }

    private var availableAssessmentCount: Int {
        assessmentDefinitions.filter { $0.isArchived == false }.count
    }

    private var routineHistoryDetail: String {
        CountPhrase.completedSessions(completedSessionCount)
    }

    private var assessmentHistoryDetail: String {
        CountPhrase.recordedAssessments(recordedAssessmentCount)
    }

    private var completedSessionCount: Int {
        sessions.filter { $0.status == .completed }.count
    }

    private var recordedAssessmentCount: Int {
        assessmentSessions.filter { $0.results.isEmpty == false }.count
    }

    /// The filter chips. `ChipFlowLayout` wraps rather than scrolls, so every
    /// option stays reachable at accessibility Dynamic Type sizes instead of
    /// running off the trailing edge.
    private var purposeFilterChips: some View {
        ChipFlowLayout(spacing: Spacing.s) {
            ForEach(filterOptions, id: \.token) { option in
                MobilityPurposeFilterChip(
                    title: filterTitle(for: option),
                    // Set on the Button inside the chip, not on the chip from
                    // out here: a container identifier can overwrite its
                    // child's, which would hide the button from XCUITest.
                    identifier: "mobility-purpose-filter-\(option.token)",
                    isSelected: purposeFilter == option
                ) {
                    purposeFilter = option
                }
            }
        }
        .padding(.vertical, Spacing.xxs)
    }

    @ViewBuilder
    private func routineRow(_ routine: MobilityRoutine) -> some View {
        Button {
            onStart(routine, sessionContext, sessionContext == .standalone ? nil : activeWorkout?.id)
        } label: {
            // The button combines these into one accessibility element, which
            // reads "<name>, <n> movements, <purpose>" — the purpose clause
            // simply absent when unclassified. No manual label needed, so the
            // count keeps its inflection and both stay localized.
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(routine.name)
                    .font(AppFont.subheadlineSemibold)
                Text(CountPhrase.movements(routine.items.count))
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                if let purpose = routine.purpose {
                    // Icon plus text, never the glyph or a color alone.
                    // Unclassified routines show nothing here: the section
                    // header already says "Not specified", and repeating it on
                    // every card is noise.
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: purposeIcon(purpose))
                            .font(AppFont.caption2)
                            .accessibilityHidden(true)
                        Text(purpose.displayName)
                            .font(AppFont.caption)
                    }
                    .foregroundStyle(Color.gymSubduedText)
                }
            }
        }
        .accessibilityIdentifier("start-mobility-routine-\(routine.id)")
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                selectedRoutine = routine
            } label: {
                Label("Edit", systemImage: AppIcon.edit)
            }
            .tint(Color.gymAccent)
        }
    }

    private var filterOptions: [MobilityPurposeFilter] {
        [.all] + MobilityRoutinePurpose.displayOrder.map(MobilityPurposeFilter.purpose) + [.unspecified]
    }

    private func filterTitle(for filter: MobilityPurposeFilter) -> String {
        switch filter {
        case .all: String(localized: "All")
        case .purpose(let purpose): purpose.displayName
        case .unspecified: String(localized: "Not specified")
        }
    }

    private func groupTitle(for group: MobilityRoutineGroup) -> String {
        group.purpose?.displayName ?? String(localized: "Not specified")
    }

    private func purposeIcon(_ purpose: MobilityRoutinePurpose) -> String {
        switch purpose {
        case .preparation: AppIcon.mobilityPurposePreparation
        case .development: AppIcon.mobilityPurposeDevelopment
        case .cooldown: AppIcon.mobilityPurposeCooldown
        }
    }

    /// Grouping, filtering, and ordering all belong to
    /// `MobilityRoutinePurposeGrouping`. This composes that contract and adds
    /// nothing — archival stays the caller's job, as the contract documents.
    private var visibleGroups: [MobilityRoutineGroup] {
        MobilityRoutinePurposeGrouping.groups(
            for: MobilityRoutinePurposeGrouping.filtered(availableRoutines, by: purposeFilter)
        )
    }

    private var availableRoutines: [MobilityRoutine] {
        routines.filter { $0.isArchived == false }
    }

    private var activeWorkout: Workout? {
        workouts.first { $0.status == .active }
    }

    private var recentMovementNames: [String] {
        var seen = Set<String>()
        return sessions
            .flatMap(\.orderedEntries)
            .compactMap { seen.insert($0.definitionNameSnapshot).inserted ? $0.definitionNameSnapshot : nil }
            .prefix(5)
            .map { $0 }
    }

    private func createRoutine() -> MobilityRoutine? {
        let routine = MobilityRoutine(name: "New mobility routine")
        if let definition = definitions.first(where: { $0.isArchived == false }) {
            routine.items = [MobilityRoutineItem(definition: definition, orderIndex: 0)]
        }
        modelContext.insert(routine)
        guard modelContext.saveOrRollback() else { return nil }
        return routine
    }
}

/// Selection is carried by a checkmark plus a heavier tinted border, never by
/// color alone, matching `GymChoiceTile`'s idiom. A plain `Button` is used
/// deliberately: on this screen a `Menu` does not open under a synthesized
/// XCUITest tap, and a pushed-screen toolbar control does not fire on iOS 26.
private struct MobilityPurposeFilterChip: View {
    let title: String
    let identifier: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if isSelected {
                    Image(systemName: AppIcon.checkmark)
                        .font(AppFont.caption2Bold)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(AppFont.captionBold)
            }
            .foregroundStyle(isSelected ? Color.gymAccent : Color.gymSubduedText)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.s)
            .background {
                Capsule().fill(isSelected ? Color.gymAccent.opacity(0.14) : Color.clear)
            }
            .overlay {
                Capsule().stroke(
                    isSelected ? Color.gymAccent : Color.gymBorder,
                    lineWidth: isSelected ? 1.5 : 1
                )
            }
            // Keeps the capsule visually compact while giving it a full-size
            // touch target, and makes the whole target tappable rather than
            // only the glyph and label.
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        // `.borderless`, not `.plain`: several of these share one List row, and
        // borderless is what keeps them independently hit-testable instead of
        // collapsing into a single row-wide tap target.
        .buttonStyle(.borderless)
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct MobilityDefinitionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MobilityDefinition.name) private var definitions: [MobilityDefinition]
    @State private var isShowingNewDefinition = false
    @State private var definitionToEdit: MobilityDefinition?
    @State private var showsArchived = false

    var body: some View {
        List {
            if visibleDefinitions.isEmpty {
                ContentUnavailableView(
                    showsArchived ? "No archived movements" : "No movements",
                    systemImage: AppIcon.mobility,
                    description: Text("Create a movement before adding it to a routine.")
                )
            } else {
                ForEach(visibleDefinitions) { definition in
                    Button {
                        definitionToEdit = definition
                    } label: {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(definition.name)
                                .font(AppFont.subheadlineSemibold)
                            Text(definition.trackingType.displayName)
                                .font(AppFont.caption)
                                .foregroundStyle(Color.gymSubduedText)
                        }
                    }
                    .foregroundStyle(Color.gymText)
                    .accessibilityIdentifier("edit-mobility-definition-\(definition.id)")
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            definition.isFavorite.toggle()
                            definition.updatedAt = .now
                            _ = modelContext.saveOrRollback()
                        } label: {
                            Label(
                                definition.isFavorite ? "Remove favorite" : "Favorite",
                                systemImage: definition.isFavorite ? "star.slash" : "star"
                            )
                        }
                        .tint(Color.gymAccent)

                        Button(role: definition.isArchived ? nil : .destructive) {
                            definition.isArchived.toggle()
                            definition.updatedAt = .now
                            _ = modelContext.saveOrRollback()
                        } label: {
                            Label(
                                definition.isArchived ? "Restore" : "Archive",
                                systemImage: definition.isArchived ? "arrow.uturn.backward" : "archivebox"
                            )
                        }
                        .accessibilityIdentifier("archive-mobility-definition-\(definition.id)")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Movements")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(showsArchived ? "Current" : "Archived") {
                    showsArchived.toggle()
                }
                .accessibilityIdentifier("toggle-archived-mobility-definitions")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingNewDefinition = true
                } label: {
                    Label("New movement", systemImage: AppIcon.plus)
                }
                .accessibilityIdentifier("create-mobility-definition")
            }
        }
        .sheet(isPresented: $isShowingNewDefinition) {
            MobilityDefinitionForm()
        }
        .sheet(item: $definitionToEdit) { definition in
            MobilityDefinitionForm(definition: definition)
        }
    }

    private var visibleDefinitions: [MobilityDefinition] {
        definitions.filter { $0.isArchived == showsArchived }
    }
}

struct MobilityDefinitionForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var instructions = ""
    @State private var trackingType: MobilityTrackingType = .duration
    @State private var duration = 30
    @State private var repetitions = 8
    @State private var error: ValidationIssue?
    let definition: MobilityDefinition?

    init(definition: MobilityDefinition? = nil) {
        self.definition = definition
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Movement") {
                    TextField("Name", text: $name)
                    TextField("Instructions", text: $instructions, axis: .vertical)
                        .lineLimit(3...6)
                    Picker("Tracks", selection: $trackingType) {
                        ForEach(MobilityTrackingType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    if trackingType == .duration {
                        Stepper("Default duration: \(duration) sec", value: $duration, in: 5...600, step: 5)
                    } else {
                        Stepper("Default repetitions: \(repetitions)", value: $repetitions, in: 1...100)
                    }
                }
            }
            .navigationTitle(definition == nil ? "New movement" : "Edit movement")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: loadDefinition)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("save-mobility-definition")
                }
            }
            .alert("Couldn’t save movement", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) { error = nil }
            } message: {
                Text(error?.message ?? "Please try again.")
            }
        }
    }

    private func loadDefinition() {
        guard let definition else { return }
        name = definition.name
        instructions = definition.instructions ?? ""
        trackingType = definition.trackingType
        duration = definition.defaultDurationSeconds ?? 30
        repetitions = definition.defaultRepetitions ?? 8
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingNames = (try? modelContext.fetch(FetchDescriptor<MobilityDefinition>())) ?? []
        guard existingNames.allSatisfy({
            $0.id == definition?.id || $0.name.localizedCaseInsensitiveCompare(trimmedName) != .orderedSame
        }) else {
            error = ValidationIssue(severity: .error, message: "A movement with that name already exists.")
            return
        }

        let target = definition ?? MobilityDefinition(
            name: trimmedName,
            instructions: nil,
            trackingType: trackingType,
            defaultDurationSeconds: nil,
            defaultRepetitions: nil
        )
        target.name = trimmedName
        let trimmedInstructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        target.instructions = trimmedInstructions.isEmpty ? nil : trimmedInstructions
        target.trackingType = trackingType
        target.defaultDurationSeconds = trackingType == .duration ? duration : nil
        target.defaultRepetitions = trackingType == .repetitions ? repetitions : nil
        target.updatedAt = .now
        if definition == nil { modelContext.insert(target) }

        if modelContext.saveOrRollback() {
            dismiss()
        } else {
            self.error = ValidationIssue(severity: .error, message: "The movement could not be saved. Try again.")
        }
    }
}

struct MobilityRoutineEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let routine: MobilityRoutine
    @Query(sort: \MobilityDefinition.name) private var definitions: [MobilityDefinition]
    @State private var name = ""
    @State private var notes = ""
    /// Optional, and never required to save. "Not specified" is a legitimate
    /// resting state, not a prompt to complete.
    @State private var purpose: MobilityRoutinePurpose?

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(2...5)
                Picker("Purpose", selection: $purpose) {
                    Text("Not specified").tag(MobilityRoutinePurpose?.none)
                    ForEach(MobilityRoutinePurpose.displayOrder) { option in
                        Text(option.displayName).tag(MobilityRoutinePurpose?.some(option))
                    }
                }
                .accessibilityIdentifier("mobility-routine-purpose-picker")
            } header: {
                Text("Routine")
            } footer: {
                Text("Purpose organizes your library. Any routine can still be started at any time.")
            }

            Section {
                ForEach(routine.orderedItems) { item in
                    MobilityRoutineItemEditorRow(item: item)
                }
                .onDelete(perform: deleteItems)

                Menu {
                    ForEach(availableDefinitions) { definition in
                        Button(definition.name) { add(definition) }
                    }
                } label: {
                    Label("Add movement", systemImage: AppIcon.plus)
                }
                .disabled(definitions.filter { $0.isArchived == false }.isEmpty)
            } header: {
                Text("Movements")
            } footer: {
                Text("Each row is an independent prescription, so the same movement can appear more than once.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Edit routine")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            name = routine.name
            notes = routine.notes ?? ""
            // Reads an unrecognized stored raw as "Not specified" for display
            // only. Nothing is written back unless the lifter saves, so a
            // value from a future build survives being viewed here.
            purpose = routine.purpose
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || routine.items.isEmpty)
                    .accessibilityIdentifier("save-mobility-routine")
            }
        }
    }

    private func add(_ definition: MobilityDefinition) {
        routine.items.append(MobilityRoutineItem(definition: definition, orderIndex: routine.items.count))
        routine.normalizeItemOrder()
        _ = modelContext.saveOrRollback()
    }

    private var availableDefinitions: [MobilityDefinition] {
        definitions
            .filter { $0.isArchived == false }
            .sorted {
                if $0.isFavorite != $1.isFavorite { return $0.isFavorite && !$1.isFavorite }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    private func deleteItems(at offsets: IndexSet) {
        let ordered = routine.orderedItems
        for index in offsets {
            modelContext.delete(ordered[index])
        }
        routine.normalizeItemOrder()
        _ = modelContext.saveOrRollback()
    }

    private func save() {
        routine.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        routine.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
        routine.purpose = purpose
        routine.updatedAt = .now
        guard modelContext.saveOrRollback() else { return }
        dismiss()
    }
}

private struct MobilityRoutineItemEditorRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: MobilityRoutineItem

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(item.definition.name)
                .font(AppFont.subheadlineSemibold)
            Picker("Side", selection: $item.sideRaw) {
                ForEach(MobilitySide.allCases, id: \.self) { side in
                    Text(side.displayName).tag(side.rawValue)
                }
            }
            if item.definition.trackingType == .duration {
                Stepper("Target: \(item.targetDurationSeconds ?? item.definition.defaultDurationSeconds ?? 30) sec", value: durationBinding, in: 5...600, step: 5)
            } else {
                Stepper("Target: \(item.targetRepetitions ?? item.definition.defaultRepetitions ?? 8) reps", value: repetitionsBinding, in: 1...100)
            }
        }
        .onChange(of: item.sideRaw) { _, _ in save() }
    }

    private var durationBinding: Binding<Int> {
        Binding(get: { item.targetDurationSeconds ?? item.definition.defaultDurationSeconds ?? 30 }, set: { item.targetDurationSeconds = $0; save() })
    }

    private var repetitionsBinding: Binding<Int> {
        Binding(get: { item.targetRepetitions ?? item.definition.defaultRepetitions ?? 8 }, set: { item.targetRepetitions = $0; save() })
    }

    private func save() { _ = modelContext.saveOrRollback() }
}
