import SwiftData
import SwiftUI

struct MobilityLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    let onStart: (MobilityRoutine, MobilitySessionContext, UUID?) -> Void
    /// Assessment presentation is root-owned, so this screen forwards the
    /// request upward rather than presenting the flow itself.
    let onStartAssessment: (MobilityAssessmentSession) -> Void
    /// Mirrors `onStart`: a mobility program session compiles and starts
    /// through the same `MobilitySessionService` path, then bubbles the
    /// resulting session up to the root's single centralized presentation.
    let onStartProgramSession: (MobilitySession) -> Void

    @Query(
        filter: #Predicate<MobilityRoutine> { !$0.isArchived },
        sort: \MobilityRoutine.updatedAt,
        order: .reverse
    ) private var routines: [MobilityRoutine]
    @Query(sort: \MobilityDefinition.name) private var definitions: [MobilityDefinition]
    @Query(
        filter: #Predicate<MobilitySession> { $0.statusRaw == "completed" },
        sort: \MobilitySession.startTime,
        order: .reverse
    ) private var sessions: [MobilitySession]
    @Query(filter: #Predicate<Workout> { $0.endTime == nil }) private var workouts: [Workout]
    @Query(sort: \MobilityAssessmentSession.startedAt, order: .reverse)
    private var assessmentSessions: [MobilityAssessmentSession]
    @Query(filter: #Predicate<MobilityAssessmentDefinition> { !$0.isArchived })
    private var assessmentDefinitions: [MobilityAssessmentDefinition]
    @State private var selectedRoutine: MobilityRoutine?
    @State private var isShowingDefinitions = false
    @State private var isShowingAssessmentLanding = false
    @State private var sessionContext: MobilitySessionContext = .standalone
    /// View-local. A filter is a momentary way of looking at the library, not
    /// a preference, so it is deliberately not persisted.
    @State private var purposeFilter: MobilityPurposeFilter = .all
    @State private var recentMovementCache: MobilityRecentMovementCache?
    private let featureFlags: FeatureFlagConfiguration = FeatureFlags.current

    var body: some View {
        let availableRoutines = routines
        let visibleGroups = MobilityRoutinePurposeGrouping.groups(
            for: MobilityRoutinePurposeGrouping.filtered(availableRoutines, by: purposeFilter)
        )
        let activeWorkoutID = workouts.first { $0.status == .active }?.id
        let recentMovementInputID = makeRecentMovementInputID()
        let recentMovementNames = recentMovementCache.flatMap {
            $0.inputID == recentMovementInputID ? $0.names : nil
        } ?? makeRecentMovementNames()

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

            if featureFlags.isEnabled(.mobilityProgram) {
                Section {
                    NavigationLink {
                        MobilityProgramCatalogView(onStartProgramSession: onStartProgramSession)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text("Mobility plans")
                                    .font(AppFont.subheadlineSemibold)
                                Text("Multi-week mobility programs with built-in progression")
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.trameSubdued)
                            }
                        } icon: {
                            Image(systemName: AppIcon.mobility)
                                .foregroundStyle(Color.trameText)
                                .frame(width: ComponentSize.minimumTouchTarget)
                        }
                    }
                    .accessibilityIdentifier("open-mobility-programs")
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
                    // On the page background rather than inside a card: a filter
                    // is chrome for the list below it, and boxing it made the
                    // controls read as the section's content.
                    purposeFilterChips
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(
                            top: Spacing.xs,
                            leading: Spacing.l,
                            bottom: Spacing.xs,
                            trailing: Spacing.l
                        ))
                }

                // The context belongs to starting a routine, not to the screen,
                // and it has exactly one possible value with no workout running.
                // Offering a locked control there was a row that could only ever
                // say "Standalone".
                if activeWorkoutID != nil {
                    Picker("Session context", selection: $sessionContext) {
                        // Mid-session insert is owned by Active Workout Add —
                        // Train never invents a duringWorkout context here.
                        ForEach(
                            MobilitySessionContext.allCases.filter { $0 != .duringWorkout },
                            id: \.self
                        ) { context in
                            Text(context.displayName).tag(context)
                        }
                    }
                    .accessibilityIdentifier("mobility-session-context")
                }
            } header: {
                sectionHeader(String(localized: "Routines")) {
                    Button {
                        selectedRoutine = createRoutine()
                    } label: {
                        Label("New routine", systemImage: AppIcon.plus)
                            .font(AppFont.captionBold)
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("create-mobility-routine")
                }
            } footer: {
                Text("Starting a standalone routine snapshots its movement targets and instructions into a performed mobility record.")
            }

            ForEach(visibleGroups) { group in
                Section {
                    ForEach(group.routines) { routine in
                        routineRow(routine, activeWorkoutID: activeWorkoutID)
                    }
                } header: {
                    sectionHeader(groupTitle(for: group)) {
                        Text(CountPhrase.routines(group.routines.count))
                            .font(AppFont.captionSemiboldMonospaced)
                            .foregroundStyle(Color.trameSubdued)
                    }
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
                        .foregroundStyle(Color.trameSubdued)
                }
            } header: {
                sectionHeader(String(localized: "Movements"))
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
                sectionHeader(String(localized: "History"))
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
        .background(Color.trameCanvas)
        .navigationTitle("Mobility")
        .navigationDestination(isPresented: $isShowingAssessmentLanding) {
            MobilityAssessmentLandingView(onStart: onStartAssessment)
        }
        // No Close button: this screen is only ever pushed inside Train, where a
        // dismissal control sat beside the back chevron and offered the same
        // exit twice. The same rule the Nutrition targets screen already follows.
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
        .task(id: recentMovementInputID) {
            recentMovementCache = .init(
                inputID: recentMovementInputID,
                names: recentMovementNames
            )
        }
    }

    private func makeRecentMovementNames() -> [String] {
        var seen = Set<String>()
        var names: [String] = []
        names.reserveCapacity(5)
        sessionLoop: for session in sessions {
            for entry in session.orderedEntries {
                guard seen.insert(entry.definitionNameSnapshot).inserted else { continue }
                names.append(entry.definitionNameSnapshot)
                if names.count == 5 { break sessionLoop }
            }
        }
        return names
    }

    private func makeRecentMovementInputID() -> Int {
        var hasher = Hasher()
        hasher.combine(sessions.count)
        for session in sessions {
            hasher.combine(session.id)
            hasher.combine(session.updatedAt)
        }
        return hasher.finalize()
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
            TrameColorField(
                fill: Color.trameMobility,
                ink: Color.trameSemanticFieldInk,
                border: Color.trameMobility,
                radius: Radius.hero
            ) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                Text("IN PROGRESS")
                    .font(AppFont.eyebrow)
                    .tracking(0.8)
                Text("Assessment in progress")
                    .font(AppFont.titleSmall)
                Text(assessmentProgressDetail(activeAssessment))
                    .font(AppFont.subheadline)
                    .fixedSize(horizontal: false, vertical: true)

                // Resuming goes straight back into the flow. Routing it through
                // the landing screen first would put a menu between the lifter
                // and the work they already started.
                Button("Continue assessment") { onStartAssessment(activeAssessment) }
                    .buttonStyle(.tramePrimaryAction)
                    .accessibilityIdentifier("resume-mobility-assessment-from-hub")
                }
                .padding(Spacing.l)
            }
        } else if let lastRecordedAssessment {
            TrameColorField(
                fill: Color.trameSurface,
                ink: Color.trameText,
                border: Color.trameSeparator,
                radius: Radius.card
            ) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                Text("ASSESSMENT")
                    .font(AppFont.eyebrow)
                    .tracking(0.8)
                    .foregroundStyle(Color.trameSubdued)
                Text(assessmentDateText(lastRecordedAssessment))
                    .font(AppFont.titleSmall)
                Text(assessmentObservationCount(lastRecordedAssessment))
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.trameSubdued)

                assessmentLink(title: String(localized: "Open assessment"))
                }
                .padding(Spacing.l)
            }
        } else {
            TrameColorField(
                fill: Color.trameSurface,
                ink: Color.trameText,
                border: Color.trameSeparator,
                radius: Radius.card
            ) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                Text("ASSESSMENT")
                    .font(AppFont.eyebrow)
                    .tracking(0.8)
                    .foregroundStyle(Color.trameSubdued)
                Text("Measure your mobility")
                    .font(AppFont.titleSmall)
                Text(assessmentInvolvementDetail)
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.trameSubdued)
                    .fixedSize(horizontal: false, vertical: true)

                assessmentLink(title: String(localized: "Get started"))
                }
                .padding(Spacing.l)
            }
        }
    }

    /// A plain button plus an explicit destination rather than a
    /// `NavigationLink`. A link nested inside a card inside a `List` row makes
    /// the whole row the link and adds a system disclosure chevron beside the
    /// primary button, which is not what this card should look like.
    private func assessmentLink(title: String) -> some View {
        Button(title) { isShowingAssessmentLanding = true }
            .buttonStyle(.tramePrimaryAction)
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
                        .foregroundStyle(Color.trameSubdued)
                }
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(Color.trameText)
                    .frame(width: ComponentSize.minimumTouchTarget)
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
        assessmentDefinitions.count
    }

    private var routineHistoryDetail: String {
        CountPhrase.completedSessions(completedSessionCount)
    }

    private var assessmentHistoryDetail: String {
        CountPhrase.recordedAssessments(recordedAssessmentCount)
    }

    private var completedSessionCount: Int {
        sessions.count
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
    private func routineRow(
        _ routine: MobilityRoutine,
        activeWorkoutID: UUID?
    ) -> some View {
        Button {
            onStart(routine, sessionContext, sessionContext == .standalone ? nil : activeWorkoutID)
        } label: {
            // The button combines the two text views into one accessibility
            // element, which reads "<name>, <n> movements · <purpose>" — the
            // purpose clause simply absent when unclassified. No manual label
            // needed, so the count keeps its localization.
            HStack(spacing: Spacing.m) {
                // Icon plus text, never the glyph alone: the purpose is named in
                // the detail line beside it, and an unclassified routine falls
                // back to the generic mobility glyph.
                Image(systemName: routine.purpose.map(purposeIcon) ?? AppIcon.mobility)
                    .font(AppFont.footnoteMedium)
                    .foregroundStyle(Color.trameMobility)
                    .frame(width: 22)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(routine.name)
                        .font(AppFont.subheadlineSemibold)
                        .foregroundStyle(Color.trameText)
                        .lineLimit(2)
                    Text(routineDetail(routine))
                        .font(AppFont.caption)
                        .foregroundStyle(Color.trameSubdued)
                        .lineLimit(2)
                }

                Spacer(minLength: Spacing.s)

                Image(systemName: AppIcon.play)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.trameMobility)
                    .frame(width: ComponentSize.minimumTouchTarget, height: ComponentSize.minimumTouchTarget)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Spacing.s)
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.trameSeparator).frame(height: 1)
            }
        }
        // Plain, not the List default: a button label inside a row is tinted
        // wholesale, which rendered every routine name as blue link text.
        .buttonStyle(.plain)
        .accessibilityIdentifier("start-mobility-routine-\(routine.id)")
        .accessibilityHint("Starts this routine as a mobility session.")
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                selectedRoutine = routine
            } label: {
                Label("Edit", systemImage: AppIcon.edit)
            }
            .tint(Color.trameMobility)
        }
    }

    /// A section header with something on its trailing edge — a count, or the
    /// action that adds to the section — so every header on this screen reads as
    /// one family instead of alternating with the system's own styling.
    ///
    /// Takes an already-localized `String` rather than a `LocalizedStringKey`:
    /// the group titles arriving here are resolved display names, and passing a
    /// resolved string back through a key looks it up a second time.
    private func sectionHeader<Trailing: View>(
        _ title: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack {
            Text(title)
                .font(AppFont.captionBold)
                .tracking(0.8)
                .foregroundStyle(Color.trameSubdued)
            Spacer(minLength: Spacing.s)
            trailing()
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        sectionHeader(title) { EmptyView() }
    }

    /// "4 movements · Preparation", one line rather than three stacked ones.
    /// Unclassified routines simply stop after the count; the section header
    /// already says "Not specified", and repeating it on every row is noise.
    private func routineDetail(_ routine: MobilityRoutine) -> String {
        let movements = CountPhrase.movements(routine.items.count)
        guard let purpose = routine.purpose else { return movements }
        return "\(movements) · \(purpose.displayName)"
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

    private func createRoutine() -> MobilityRoutine? {
        let routine = MobilityRoutine(name: uniqueRoutineName())
        if let definition = definitions.first(where: { $0.isArchived == false }) {
            routine.items = [MobilityRoutineItem(definition: definition, orderIndex: 0)]
        }
        modelContext.insert(routine)
        guard modelContext.saveOrRollback() else { return nil }
        return routine
    }

    /// A freshly created routine has no user-typed name to validate, so the
    /// case-insensitive collision guard `MobilityDefinitionForm.save()` and
    /// `MobilityRoutineEditorView.save()` use to reject a colliding name
    /// cannot apply here — there is nothing to reject yet. Instead the same
    /// case-insensitive comparison disambiguates the default name up front,
    /// exactly as `MobilityProgramDefinitionStore.uniqueCompiledRoutineName`
    /// disambiguates compiled routine names, so repeated taps on "New
    /// routine" never produce indistinguishable duplicates in the library.
    private func uniqueRoutineName() -> String {
        let base = "New mobility routine"
        let existingNames = (try? modelContext.fetch(FetchDescriptor<MobilityRoutine>()))?.map(\.name) ?? []
        guard existingNames.contains(where: { $0.localizedCaseInsensitiveCompare(base) == .orderedSame }) else {
            return base
        }
        var suffix = 2
        while existingNames.contains(where: {
            $0.localizedCaseInsensitiveCompare("\(base) \(suffix)") == .orderedSame
        }) {
            suffix += 1
        }
        return "\(base) \(suffix)"
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
            .foregroundStyle(isSelected ? Color.trameText : Color.trameSubdued)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.s)
            .background {
                Capsule().fill(isSelected ? Color.trameCurrent : Color.clear)
            }
            .overlay {
                Capsule().stroke(
                    isSelected ? Color.trameMobility : Color.trameSeparator,
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
                                .foregroundStyle(Color.trameSubdued)
                        }
                    }
                    .foregroundStyle(Color.trameText)
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
                        .tint(Color.trameMobility)

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
        .background(Color.trameCanvas)
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
    /// Blocks have no SwiftData relationship to `routine` (an ownership key,
    /// like every other mobility sidecar), so they cannot be a `@Query` on a
    /// static predicate here; they are loaded and reloaded explicitly.
    @State private var blocks: [MobilityRoutineBlock] = []
    @State private var error: ValidationIssue?

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
                ForEach(blocks, id: \.blockKey) { block in
                    MobilityRoutineBlockEditorRow(block: block, onChange: reloadBlocks, onDelete: {
                        deleteBlock(block)
                    })
                }
                Button {
                    addBlock()
                } label: {
                    Label("Add block", systemImage: AppIcon.plus)
                }
                .accessibilityIdentifier("add-mobility-block")
            } header: {
                Text("Blocks")
            } footer: {
                Text("A block groups movements below and gives them a shared rest and, for circuits, a round count. A movement without a block runs on its own, exactly as before.")
            }

            Section {
                ForEach(routine.orderedItems) { item in
                    MobilityRoutineItemEditorRow(item: item, blocks: blocks)
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
        .background(Color.trameCanvas)
        .navigationTitle("Edit routine")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            name = routine.name
            notes = routine.notes ?? ""
            // Reads an unrecognized stored raw as "Not specified" for display
            // only. Nothing is written back unless the lifter saves, so a
            // value from a future build survives being viewed here.
            purpose = routine.purpose
            reloadBlocks()
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || routine.items.isEmpty)
                    .accessibilityIdentifier("save-mobility-routine")
            }
        }
        .alert("Couldn’t save routine", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { error = nil }
        } message: {
            Text(error?.message ?? "Please try again.")
        }
    }

    private func reloadBlocks() {
        blocks = MobilityEvidenceService.blocks(forRoutineID: routine.id, using: modelContext)
    }

    private func addBlock() {
        _ = MobilityEvidenceService.upsertBlock(
            routineID: routine.id,
            orderIndex: blocks.count,
            name: nil,
            kind: .straightSequence,
            targetRounds: nil,
            restPrescription: nil,
            using: modelContext
        )
        reloadBlocks()
    }

    private func deleteBlock(_ block: MobilityRoutineBlock) {
        _ = MobilityEvidenceService.deleteBlock(
            blockKey: block.blockKey,
            routineItemIDs: routine.orderedItems.map(\.id),
            using: modelContext
        )
        reloadBlocks()
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
            let item = ordered[index]
            if let evidence = MobilityEvidenceService.prescriptionEvidence(
                for: item.id,
                using: modelContext
            ) {
                modelContext.delete(evidence)
            }
            modelContext.delete(item)
        }
        routine.normalizeItemOrder()
        _ = modelContext.saveOrRollback()
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingRoutines = (try? modelContext.fetch(FetchDescriptor<MobilityRoutine>())) ?? []
        guard existingRoutines.allSatisfy({
            $0.id == routine.id || $0.name.localizedCaseInsensitiveCompare(trimmedName) != .orderedSame
        }) else {
            error = ValidationIssue(severity: .error, message: "A routine with that name already exists.")
            return
        }

        routine.name = trimmedName
        routine.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
        routine.purpose = purpose
        routine.updatedAt = .now
        guard modelContext.saveOrRollback() else {
            error = ValidationIssue(severity: .error, message: "The routine could not be saved. Try again.")
            return
        }
        dismiss()
    }
}

private struct MobilityRecentMovementCache {
    let inputID: Int
    let names: [String]
}

private struct MobilityRoutineBlockEditorRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var block: MobilityRoutineBlock
    let onChange: () -> Void
    let onDelete: () -> Void
    @State private var name = ""
    @State private var kind: MobilityBlockKind = .straightSequence
    @State private var targetRounds: Int?
    @State private var hasCustomRest = false
    @State private var restScope: MobilityRestScope = .betweenRounds
    @State private var restDirectiveKind: MobilityRestDirectiveKind = .none
    @State private var restSeconds = 30
    @State private var restMinimumSeconds = 20
    @State private var restMaximumSeconds = 40
    @State private var isLoading = true
    @State private var saveGeneration = 0
    @State private var hasPendingSave = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            TextField("Block name", text: $name)
            Picker("Kind", selection: $kind) {
                ForEach(MobilityBlockKind.allCases, id: \.self) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            if kind.isRoundBased {
                Stepper(
                    "Rounds: \(targetRounds ?? 1)",
                    value: Binding(get: { targetRounds ?? 1 }, set: { targetRounds = $0 }),
                    in: 1...20
                )
            }
            RestPrescriptionEditor(
                title: kind.isRoundBased ? "Rest between rounds" : "Rest between movements in this block",
                hasCustomRest: $hasCustomRest,
                scope: $restScope,
                directiveKind: $restDirectiveKind,
                seconds: $restSeconds,
                minimumSeconds: $restMinimumSeconds,
                maximumSeconds: $restMaximumSeconds
            )
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete block", systemImage: AppIcon.trash)
            }
        }
        .onAppear {
            name = block.name ?? ""
            kind = block.kind
            targetRounds = block.targetRounds
            if let rest = block.restPrescription {
                hasCustomRest = true
                restScope = rest.scope
                // Unpacked through a named local: assigning a four-element
                // tuple straight into four separate @State properties is the
                // shape that pushes this view body past the type-checker's
                // time budget.
                let editorValues = rest.directive.editorValues
                restDirectiveKind = editorValues.kind
                restSeconds = editorValues.seconds
                restMinimumSeconds = editorValues.minimum
                restMaximumSeconds = editorValues.maximum
            }
            Task { @MainActor in
                await Task.yield()
                isLoading = false
            }
        }
        .onChange(of: name) { _, _ in scheduleSave() }
        .onChange(of: kind) { _, _ in scheduleSave() }
        .onChange(of: targetRounds) { _, _ in scheduleSave() }
        .onChange(of: hasCustomRest) { _, _ in scheduleSave() }
        .onChange(of: restScope) { _, _ in scheduleSave() }
        .onChange(of: restDirectiveKind) { _, _ in scheduleSave() }
        .onChange(of: restSeconds) { _, _ in scheduleSave() }
        .onChange(of: restMinimumSeconds) { _, _ in scheduleSave() }
        .onChange(of: restMaximumSeconds) { _, _ in scheduleSave() }
        // Text entry can produce one state change per character. Keep the
        // draft responsive and coalesce those changes into one persistence
        // transaction; disappearance still flushes the latest value.
        .task(id: saveGeneration) {
            guard saveGeneration > 0 else { return }
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }
            guard Task.isCancelled == false else { return }
            flushPendingSave()
        }
        .onDisappear { flushPendingSave() }
    }

    private func scheduleSave() {
        guard isLoading == false else { return }
        hasPendingSave = true
        saveGeneration &+= 1
    }

    private func flushPendingSave() {
        guard hasPendingSave else { return }
        hasPendingSave = false
        save()
    }

    private func save() {
        guard isLoading == false else { return }
        _ = MobilityEvidenceService.upsertBlock(
            blockKey: block.blockKey,
            routineID: block.routineID,
            orderIndex: block.orderIndex,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            kind: kind,
            targetRounds: kind.isRoundBased ? (targetRounds ?? 1) : nil,
            restPrescription: hasCustomRest
                ? MobilityRestPrescription(
                    scope: restScope,
                    directive: restDirectiveKind.directive(
                        seconds: restSeconds,
                        minimum: restMinimumSeconds,
                        maximum: restMaximumSeconds
                    )
                  )
                : nil,
            using: modelContext
        )
        onChange()
    }
}

private struct MobilityRoutineItemEditorRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: MobilityRoutineItem
    let blocks: [MobilityRoutineBlock]
    @State private var method: MobilityMethod?
    @State private var trainingPurpose: MobilityTrainingPurpose?
    @State private var breathingTarget: Int?
    @State private var inhaleSeconds: Int?
    @State private var exhaleSeconds: Int?
    @State private var tempoIntoSeconds: Int?
    @State private var tempoHoldSeconds: Int?
    @State private var tempoReturnSeconds: Int?
    @State private var tempoPauseSeconds: Int?
    @State private var assistanceType: MobilityAssistanceType?
    @State private var assistanceLevel: Int?
    @State private var assistanceEquipment = ""
    @State private var supportLevel: MobilitySupportLevel?
    @State private var completionRuleSelection = "legacy"
    @State private var blockKey: String?
    @State private var sideStrategy: MobilitySideStrategy?
    @State private var hasCustomRest = false
    @State private var restScope: MobilityRestScope = .betweenMovements
    @State private var restDirectiveKind: MobilityRestDirectiveKind = .none
    @State private var restSeconds = 30
    @State private var restMinimumSeconds = 20
    @State private var restMaximumSeconds = 40
    @State private var isLoadingEvidence = true
    @State private var pendingSaveKinds: Set<PendingSaveKind> = []
    @State private var saveGeneration = 0

    private enum PendingSaveKind: Hashable {
        case model
        case evidence
        case metric
        case structure
    }

    init(item: MobilityRoutineItem, blocks: [MobilityRoutineBlock]) {
        self.item = item
        self.blocks = blocks
    }

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

            DisclosureGroup("Advanced prescription") {
                Picker("Method", selection: $method) {
                    Text("Not specified").tag(MobilityMethod?.none)
                    ForEach(MobilityMethod.allCases) { method in
                        Text(method.displayName).tag(MobilityMethod?.some(method))
                    }
                }
                Picker("Training purpose", selection: $trainingPurpose) {
                    Text("Not specified").tag(MobilityTrainingPurpose?.none)
                    ForEach(MobilityTrainingPurpose.allCases) { purpose in
                        Text(purpose.displayName).tag(MobilityTrainingPurpose?.some(purpose))
                    }
                }

                if item.orderedPhases.isEmpty {
                    Picker("Completion requires", selection: $completionRuleSelection) {
                        Text("Movement measure").tag("legacy")
                        Text("All prescribed measures").tag("prescribed")
                        if breathingTarget != nil {
                            Text("Breathing cycles").tag("breathing")
                        }
                    }
                }

                Toggle("External load", isOn: Binding(
                    get: { item.targetLoadValue != nil },
                    set: { enabled in
                        item.targetLoadValue = enabled ? 5 : nil
                        item.targetLoadUnit = enabled ? (item.targetLoadUnit ?? .kilograms) : nil
                        scheduleSave(.model)
                        scheduleSave(.metric)
                    }
                ))
                if item.targetLoadValue != nil {
                    Stepper(
                        "Target load: \((item.targetLoadValue ?? 0).formatted(.number.precision(.fractionLength(0...2))))",
                        value: Binding(
                            get: { item.targetLoadValue ?? 0 },
                            set: {
                                item.targetLoadValue = $0
                                scheduleSave(.model)
                                scheduleSave(.metric)
                            }
                        ),
                        in: 0.5...1000,
                        step: 0.5
                    )
                    Picker("Load unit", selection: Binding(
                        get: { item.targetLoadUnit ?? .kilograms },
                        set: {
                            item.targetLoadUnit = $0
                            scheduleSave(.model)
                        }
                    )) {
                        ForEach(MobilityLoadUnit.allCases, id: \.self) { unit in
                            Text(unit.abbreviation).tag(unit)
                        }
                    }
                }

                optionalStepper("Target breaths", value: $breathingTarget, range: 1...30)
                optionalStepper("Inhale seconds", value: $inhaleSeconds, range: 1...20)
                optionalStepper("Exhale seconds", value: $exhaleSeconds, range: 1...30)

                optionalStepper("Move into range", value: $tempoIntoSeconds, range: 1...60)
                optionalStepper("Tempo hold", value: $tempoHoldSeconds, range: 1...600)
                optionalStepper("Return", value: $tempoReturnSeconds, range: 1...60)
                optionalStepper("Pause", value: $tempoPauseSeconds, range: 1...60)

                Picker("Assistance", selection: $assistanceType) {
                    Text("Not specified").tag(MobilityAssistanceType?.none)
                    ForEach(MobilityAssistanceType.allCases) { type in
                        Text(type.displayName).tag(MobilityAssistanceType?.some(type))
                    }
                }
                if assistanceType != nil {
                    optionalStepper("Assistance level", value: $assistanceLevel, range: 0...10)
                    TextField("Equipment detail", text: $assistanceEquipment)
                }

                Picker("Support", selection: $supportLevel) {
                    Text("Not specified").tag(MobilitySupportLevel?.none)
                    ForEach(MobilitySupportLevel.allCases) { support in
                        Text(support.displayName).tag(MobilitySupportLevel?.some(support))
                    }
                }
                Text("Support describes the setup used for comparison. It is not a score or diagnosis.")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.trameSubdued)

                Picker("Block", selection: $blockKey) {
                    Text("No block").tag(String?.none)
                    ForEach(blocks, id: \.blockKey) { block in
                        Text(block.name?.nilIfEmpty ?? block.kind.displayName).tag(String?.some(block.blockKey))
                    }
                }
                .accessibilityIdentifier("mobility-item-block-picker")

                if item.side == .bilateral || item.side == .alternating {
                    Picker("Side strategy", selection: $sideStrategy) {
                        Text("Default").tag(MobilitySideStrategy?.none)
                        ForEach(MobilitySideStrategy.allCases, id: \.self) { strategy in
                            Text(strategy.displayName).tag(MobilitySideStrategy?.some(strategy))
                        }
                    }
                }

                RestPrescriptionEditor(
                    title: "Rest after this movement",
                    hasCustomRest: $hasCustomRest,
                    scope: $restScope,
                    directiveKind: $restDirectiveKind,
                    seconds: $restSeconds,
                    minimumSeconds: $restMinimumSeconds,
                    maximumSeconds: $restMaximumSeconds
                )
            }
        }
        // Each `.onChange` wraps the view in another generic layer, and this
        // editor tracks enough fields that chaining one per field pushed the
        // body past the type-checker's time budget. Watching one combined
        // signature per save target keeps the behaviour identical with a flat
        // modifier chain.
        .onChange(of: item.sideRaw) { _, _ in scheduleSave(.model) }
        .onChange(of: evidenceSignature) { _, _ in scheduleSave(.evidence) }
        .onChange(of: completionRuleSelection) { _, _ in scheduleSave(.metric) }
        .onChange(of: structureSignature) { _, _ in scheduleSave(.structure) }
        // Text entry can produce one state change per character. Coalesce the
        // affected persistence targets, then flush when the row leaves the
        // editor so dismissal cannot lose the latest draft.
        .task(id: saveGeneration) {
            guard saveGeneration > 0 else { return }
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }
            guard Task.isCancelled == false else { return }
            flushPendingSaves()
        }
        .onDisappear { flushPendingSaves() }
        .onAppear {
            let evidence = MobilityEvidenceService.prescriptionEvidence(
                for: item.id,
                using: modelContext
            )
            method = evidence?.method
            trainingPurpose = evidence?.purpose
            breathingTarget = evidence?.breathingPrescription?.targetBreaths
            inhaleSeconds = evidence?.breathingPrescription?.inhaleSeconds
            exhaleSeconds = evidence?.breathingPrescription?.exhaleSeconds
            tempoIntoSeconds = evidence?.tempoPrescription?.moveIntoRangeSeconds
            tempoHoldSeconds = evidence?.tempoPrescription?.holdSeconds
            tempoReturnSeconds = evidence?.tempoPrescription?.returnSeconds
            tempoPauseSeconds = evidence?.tempoPrescription?.pauseSeconds
            assistanceType = evidence?.assistancePrescription?.assistanceType
            assistanceLevel = evidence?.assistancePrescription?.level
            assistanceEquipment = evidence?.assistancePrescription?.equipmentRaw ?? ""
            supportLevel = evidence?.supportLevel
            completionRuleSelection = completionSelection(for: evidence?.metricProfile)
            blockKey = evidence?.blockKey
            sideStrategy = evidence?.sideStrategy
            if let rest = evidence?.restPrescription {
                hasCustomRest = true
                restScope = rest.scope
                // Unpacked through a named local: assigning a four-element
                // tuple straight into four separate @State properties is the
                // shape that pushes this view body past the type-checker's
                // time budget.
                let editorValues = rest.directive.editorValues
                restDirectiveKind = editorValues.kind
                restSeconds = editorValues.seconds
                restMinimumSeconds = editorValues.minimum
                restMaximumSeconds = editorValues.maximum
            }
            Task { @MainActor in
                await Task.yield()
                isLoadingEvidence = false
            }
        }
    }

    /// Every authored prescription field that `saveEvidence()` persists,
    /// collapsed into one comparable value so the body needs a single
    /// `.onChange` rather than one per field.
    private var evidenceSignature: String {
        var parts: [String] = []
        parts.append(method?.rawValue ?? "-")
        parts.append(trainingPurpose?.rawValue ?? "-")
        parts.append(breathingTarget.map(String.init) ?? "-")
        parts.append(inhaleSeconds.map(String.init) ?? "-")
        parts.append(exhaleSeconds.map(String.init) ?? "-")
        parts.append(tempoIntoSeconds.map(String.init) ?? "-")
        parts.append(tempoHoldSeconds.map(String.init) ?? "-")
        parts.append(tempoReturnSeconds.map(String.init) ?? "-")
        parts.append(tempoPauseSeconds.map(String.init) ?? "-")
        parts.append(assistanceType?.rawValue ?? "-")
        parts.append(assistanceLevel.map(String.init) ?? "-")
        parts.append(assistanceEquipment)
        parts.append(supportLevel?.rawValue ?? "-")
        return parts.joined(separator: "|")
    }

    /// The same collapse for everything `saveStructure()` persists.
    private var structureSignature: String {
        var parts: [String] = []
        parts.append(blockKey ?? "-")
        parts.append(sideStrategy?.rawValue ?? "-")
        parts.append(String(hasCustomRest))
        parts.append(restScope.rawValue)
        parts.append(restDirectiveKind.rawValue)
        parts.append(String(restSeconds))
        parts.append(String(restMinimumSeconds))
        parts.append(String(restMaximumSeconds))
        return parts.joined(separator: "|")
    }

    private func saveStructure() {
        guard isLoadingEvidence == false else { return }
        _ = MobilityEvidenceService.upsertStructurePrescription(
            for: item.id,
            blockKey: blockKey,
            sideStrategy: sideStrategy,
            restPrescription: hasCustomRest
                ? MobilityRestPrescription(
                    scope: restScope,
                    directive: restDirectiveKind.directive(
                        seconds: restSeconds,
                        minimum: restMinimumSeconds,
                        maximum: restMaximumSeconds
                    )
                  )
                : nil,
            using: modelContext
        )
    }

    private var durationBinding: Binding<Int> {
        Binding(
            get: { item.targetDurationSeconds ?? item.definition.defaultDurationSeconds ?? 30 },
            set: {
                item.targetDurationSeconds = $0
                scheduleSave(.model)
                scheduleSave(.metric)
            }
        )
    }

    private var repetitionsBinding: Binding<Int> {
        Binding(
            get: { item.targetRepetitions ?? item.definition.defaultRepetitions ?? 8 },
            set: {
                item.targetRepetitions = $0
                scheduleSave(.model)
                scheduleSave(.metric)
            }
        )
    }

    private func scheduleSave(_ kind: PendingSaveKind) {
        guard isLoadingEvidence == false else { return }
        pendingSaveKinds.insert(kind)
        saveGeneration &+= 1
    }

    private func flushPendingSaves() {
        guard isLoadingEvidence == false, pendingSaveKinds.isEmpty == false else { return }
        let pending = pendingSaveKinds
        pendingSaveKinds.removeAll()

        if pending.contains(.model) {
            _ = modelContext.saveOrRollback()
        }
        if pending.contains(.evidence) {
            saveEvidence()
        } else if pending.contains(.metric) {
            saveMetricEvidence()
        }
        if pending.contains(.structure) {
            saveStructure()
        }
    }

    private func save() { scheduleSave(.model) }

    private func optionalStepper(
        _ title: LocalizedStringKey,
        value: Binding<Int?>,
        range: ClosedRange<Int>
    ) -> some View {
        HStack {
            Toggle(title, isOn: Binding(
                get: { value.wrappedValue != nil },
                set: { enabled in value.wrappedValue = enabled ? range.lowerBound : nil }
            ))
            if value.wrappedValue != nil {
                Stepper(
                    "\(value.wrappedValue ?? range.lowerBound)",
                    value: Binding(
                        get: { value.wrappedValue ?? range.lowerBound },
                        set: { value.wrappedValue = $0 }
                    ),
                    in: range
                )
                .labelsHidden()
            }
        }
    }

    private func saveEvidence() {
        guard isLoadingEvidence == false else { return }
        _ = MobilityEvidenceService.upsertPrescription(
            for: item.id,
            method: method,
            purpose: trainingPurpose,
            breathingPrescription: MobilityBreathingPrescription(
                targetBreaths: breathingTarget,
                inhaleSeconds: inhaleSeconds,
                exhaleSeconds: exhaleSeconds,
                instructionKey: nil
            ),
            tempoPrescription: MobilityTempoPrescription(
                moveIntoRangeSeconds: tempoIntoSeconds,
                holdSeconds: tempoHoldSeconds,
                returnSeconds: tempoReturnSeconds,
                pauseSeconds: tempoPauseSeconds
            ),
            assistancePrescription: assistanceType.map {
                MobilityAssistancePrescription(
                    assistanceTypeRaw: $0.rawValue,
                    level: assistanceLevel,
                    equipmentRaw: assistanceEquipment.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                )
            },
            supportLevel: supportLevel,
            using: modelContext
        )
        saveMetricEvidence()
    }

    private func completionSelection(for profile: MobilityMetricProfile?) -> String {
        guard let profile else { return "legacy" }
        switch profile.defaultCompletionRule {
        case .prescribedTargets:
            return "prescribed"
        case .all(let metrics) where metrics == [.breathingCycles]:
            return "breathing"
        default:
            return "legacy"
        }
    }

    private func saveMetricEvidence() {
        guard isLoadingEvidence == false else { return }
        let baseMetric: MobilityMetric = item.definition.trackingType == .duration
            ? .duration : .repetitions
        var supported: Set<MobilityMetric> = [baseMetric]
        if item.targetLoadValue != nil { supported.insert(.load) }
        if breathingTarget != nil { supported.insert(.breathingCycles) }

        let profile: MobilityMetricProfile?
        switch completionRuleSelection {
        case "prescribed":
            profile = MobilityMetricProfile(
                supportedMetrics: supported,
                defaultCompletionRule: .prescribedTargets,
                primaryProgressMetric: baseMetric
            )
        case "breathing" where breathingTarget != nil:
            profile = MobilityMetricProfile(
                supportedMetrics: supported,
                defaultCompletionRule: .all([.breathingCycles]),
                primaryProgressMetric: .breathingCycles
            )
        default:
            profile = nil
        }
        let targets = MobilityMetricTargets(
            durationSeconds: item.definition.trackingType == .duration
                ? (item.targetDurationSeconds ?? item.definition.defaultDurationSeconds)
                    .map(MobilityIntTarget.exact)
                : nil,
            repetitions: item.definition.trackingType == .repetitions
                ? (item.targetRepetitions ?? item.definition.defaultRepetitions)
                    .map(MobilityIntTarget.exact)
                : nil,
            load: item.targetLoadValue.map(MobilityDoubleTarget.exact),
            breathingCycles: breathingTarget.map(MobilityIntTarget.exact)
        )
        _ = MobilityEvidenceService.upsertMetricPrescription(
            for: item.id,
            profile: profile,
            targets: profile == nil ? nil : targets,
            using: modelContext
        )
    }
}

/// Shared authoring control for a `MobilityRestPrescription`: a toggle for
/// "use the default rest" versus an explicit scope + directive. Used by both
/// the block row and the item row so scoped rest is authored identically in
/// either place.
private struct RestPrescriptionEditor: View {
    let title: LocalizedStringKey
    @Binding var hasCustomRest: Bool
    @Binding var scope: MobilityRestScope
    @Binding var directiveKind: MobilityRestDirectiveKind
    @Binding var seconds: Int
    @Binding var minimumSeconds: Int
    @Binding var maximumSeconds: Int

    var body: some View {
        Toggle(title, isOn: $hasCustomRest)
        if hasCustomRest {
            Picker("Rest applies", selection: $scope) {
                ForEach(MobilityRestScope.allCases, id: \.self) { scope in
                    Text(scope.displayName).tag(scope)
                }
            }
            Picker("Rest type", selection: $directiveKind) {
                ForEach(MobilityRestDirectiveKind.allCases, id: \.self) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            switch directiveKind {
            case .none, .userControlled, .breatheUntilReady:
                EmptyView()
            case .exact:
                Stepper("Rest: \(seconds) sec", value: $seconds, in: 1...600, step: 5)
            case .range:
                Stepper("Minimum: \(minimumSeconds) sec", value: $minimumSeconds, in: 1...600, step: 5)
                Stepper("Maximum: \(maximumSeconds) sec", value: $maximumSeconds, in: max(minimumSeconds, 1)...600, step: 5)
            }
        }
    }
}

/// A UI-only mirror of `MobilityRestDirective`'s cases without its
/// associated values, so a `Picker` can select a kind before the seconds
/// steppers for that kind exist.
private enum MobilityRestDirectiveKind: String, CaseIterable, Hashable {
    case none
    case exact
    case range
    case userControlled
    case breatheUntilReady

    var displayName: String {
        switch self {
        case .none: String(localized: "No rest")
        case .exact: String(localized: "Exact")
        case .range: String(localized: "Rest range")
        case .userControlled: String(localized: "User controlled")
        case .breatheUntilReady: String(localized: "Breathe until ready")
        }
    }

    func directive(seconds: Int, minimum: Int, maximum: Int) -> MobilityRestDirective {
        switch self {
        case .none: .none
        case .exact: .exact(seconds: max(1, seconds))
        case .range: .range(minimum: max(1, minimum), maximum: max(max(1, minimum), maximum))
        case .userControlled: .userControlled
        case .breatheUntilReady: .breatheUntilReady
        }
    }
}

private extension MobilityRestDirective {
    /// `(kind, exactSeconds, rangeMinimum, rangeMaximum)`. Unused seconds
    /// fields keep the editor's last-shown value rather than resetting to a
    /// default, matching the other optional-stepper controls in this file.
    var editorValues: (kind: MobilityRestDirectiveKind, seconds: Int, minimum: Int, maximum: Int) {
        switch self {
        case .none: (.none, 30, 20, 40)
        case .exact(let seconds): (.exact, seconds, 20, 40)
        case .range(let minimum, let maximum): (.range, 30, minimum, maximum)
        case .userControlled: (.userControlled, 30, 20, 40)
        case .breatheUntilReady: (.breatheUntilReady, 30, 20, 40)
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
