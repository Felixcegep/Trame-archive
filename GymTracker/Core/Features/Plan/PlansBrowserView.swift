import SwiftData
import SwiftUI

/// The catalogue's Codable payload is the expensive part of discovery. Keep
/// one decoded candidate alongside its record for the duration of a render so
/// filtering, ranking, and filter-sheet metadata all read the same snapshot.
///
/// This is deliberately derived from the live query rather than stored in
/// `@State`: a profile/catalogue edit must be reflected immediately, and a
/// cached payload would otherwise introduce a second invalidation protocol.
private struct ReadyMadeProgramSnapshot {
    struct Entry {
        let record: ProgramDefinitionRecord
        let candidate: ProgramMatchCandidate
    }

    let entries: [Entry]
    let candidates: [ProgramMatchCandidate]
    let candidatesByRecordID: [UUID: ProgramMatchCandidate]
    let hasActiveBuiltInRecords: Bool

    init(records: [ProgramDefinitionRecord]) {
        let activeBuiltIns = records.filter { $0.isBuiltIn && !$0.isArchived }
        hasActiveBuiltInRecords = !activeBuiltIns.isEmpty
        let decodedEntries: [Entry] = activeBuiltIns.compactMap { record -> Entry? in
            guard let payload = try? record.payload() else { return nil }
            return Entry(
                record: record,
                candidate: ProgramMatchCandidate(payload: payload)
            )
        }
        entries = decodedEntries
        candidates = decodedEntries.map { $0.candidate }
        candidatesByRecordID = Dictionary(
            uniqueKeysWithValues: decodedEntries.map { ($0.record.id, $0.candidate) }
        )
    }
}

/// One destination for every kind of plan.
///
/// Train used to offer "Ready-Made Plans", "My Plans" and "Rotations" as three
/// sibling rows, which made picking the right door a prerequisite for starting
/// to train. They are three filters over one list instead: what you follow,
/// what you made, and what ships with the app.
struct PlansBrowserView: View {
    enum Scope: String, CaseIterable, Identifiable {
        case following
        case mine
        case readyMade

        var id: Self { self }

        var title: LocalizedStringKey {
            switch self {
            case .following: "Following"
            case .mine: "Mine"
            case .readyMade: "Ready-made"
            }
        }
    }

    /// How the ready-made catalogue is ordered.
    ///
    /// A mode the lifter can see and change, never a silent reshuffle. A list
    /// that reorders itself with no visible cause and no way back is the thing
    /// `OnboardingRecommendationsView` already argues against in its own
    /// subtitle, which refuses to claim personalisation it cannot back up.
    enum Ordering: String, CaseIterable, Identifiable {
        case rankedForYou
        case alphabetical

        var id: Self { self }

        var title: LocalizedStringKey {
            switch self {
            case .rankedForYou: "Ranked for you"
            case .alphabetical: "A–Z"
            }
        }

        /// Spoken as what the ordering *does*, not as its four-word label —
        /// "A–Z" alone tells a VoiceOver user nothing about what changes.
        var accessibilityLabel: String {
            switch self {
            case .rankedForYou:
                String(localized: "Ranked for you, ordered by how well each plan matches your training profile")
            case .alphabetical:
                String(localized: "A to Z, ordered alphabetically by name")
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Query private var plans: [WorkoutPlan]
    @Query private var repeatingPlans: [RepeatingPlan]
    @Query private var programDefinitions: [ProgramDefinitionRecord]
    @Query private var workoutTemplates: [WorkoutTemplate]
    /// The persisted answers, read live. Ranking is recomputed from this on
    /// every appearance rather than cached, so editing the profile in Settings
    /// and returning here re-ranks with nothing to invalidate.
    @Query private var trainingProfiles: [TrainingProfile]
    /// `WorkoutPlan` has no `isBuiltIn` flag, so the seed registry is what
    /// distinguishes a plan the app shipped from one the user built. Reading it
    /// here also covers installs that already seeded before this distinction
    /// existed, which a new model property would not.
    @Query private var seedRecords: [SystemSeedRecord]

    @State private var scope: Scope = .following
    @State private var searchText = ""
    /// The empty states here offer creation, so this screen owns the form rather
    /// than asking the tab root to present it on its behalf.
    @State private var isShowingPlanForm = false
    /// Every ready-made record and seeded plan comes from the bundled
    /// catalogue, so an empty "Ready-made" scope is not automatically "the
    /// app ships nothing" — see `SystemCatalogInstallState`.
    @State private var catalogInstallState = SystemCatalogInstallState.shared
    @State private var discoveryFilters = ProgramDiscoveryFilters()
    @State private var isShowingDiscoveryFilters = false
    /// The mode the lifter last chose, remembered across launches. Defaults to
    /// ranked, which only takes effect when there is actually a profile to rank
    /// against — see `effectiveOrdering`.
    @AppStorage(DefaultsKey.catalogueOrdering) private var storedOrdering: Ordering = .rankedForYou

    init() {
        var descriptor = FetchDescriptor<TrainingProfile>()
        descriptor.fetchLimit = 1
        _trainingProfiles = Query(descriptor)
    }

    var body: some View {
        // Do not decode the catalogue while the user is browsing Following or
        // Mine. The snapshot is created only for the scope that needs it and
        // is captured by the filter sheet when that sheet is presented.
        let readyMadeSnapshot: ReadyMadeProgramSnapshot? = scope == .readyMade
            ? ReadyMadeProgramSnapshot(records: programDefinitions)
            : nil

        // The scope control sits outside the scroll rather than in its first
        // row: as a scrolling row it shared the same strip as the searchable
        // drawer and the two drew on top of each other. Pinned, it also stays
        // reachable while the list scrolls.
        VStack(spacing: 0) {
            HStack(spacing: Spacing.l) {
                ForEach(visibleScopes) { candidate in
                    Button {
                        scope = candidate
                    } label: {
                        Text(candidate.title)
                            .font(AppFont.metadata)
                            .foregroundStyle(candidate == scope ? Color.trameText : Color.trameSubdued)
                            .frame(minHeight: ComponentSize.minimumTouchTarget)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(candidate == scope ? Color.trameText : Color.clear)
                                    .frame(height: 2)
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(candidate == scope ? .isSelected : [])
                    .accessibilityIdentifier("plans-scope-\(candidate.rawValue)")
                }
                Spacer(minLength: 0)
            }
            .accessibilityIdentifier("plans-scope")
            .padding(.horizontal, Spacing.screenInset)
            .padding(.vertical, Spacing.s)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.trameSeparator).frame(height: 1)
            }

            // A `ScrollView` of cards rather than a `List`.
            //
            // This screen is the last one in discovery still wearing system
            // chrome: default row insets, default separators, and a grouped
            // background that no other Trame surface uses. Every list the app
            // owns — Today's "Log today" rows, the exercise card's set table,
            // the program detail sections — is one card with hairline-separated
            // rows, and the catalogue is the screen where that consistency
            // matters most, since it is what a lifter compares plans in.
            //
            // Nothing is lost in the conversion: these rows have no swipe
            // actions, no `onDelete`, and no `onMove`, so `List` was providing
            // styling and nothing else.
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.xl) {
                    strengthPathsHeader

                    switch scope {
                    case .following: followingSections
                    case .mine: mineSections
                    case .readyMade:
                        if let readyMadeSnapshot {
                            readyMadeSection(snapshot: readyMadeSnapshot)
                        }
                    }
                }
                .padding(.horizontal, Spacing.screenInset)
                .padding(.bottom, Spacing.xxxl)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("plans-browser-list")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search plans"
            )
        }
        .background(Color.trameCanvas)
        .navigationTitle("Plans")
        .toolbar {
            if scope == .readyMade {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingDiscoveryFilters = true
                    } label: {
                        Label(filterButtonTitle, systemImage: AppIcon.filters)
                    }
                    .accessibilityIdentifier("program-discovery-filter-button")
                }
            }
        }
        .onAppear(perform: selectInitialScope)
        .sheet(isPresented: $isShowingPlanForm) {
            NavigationStack {
                PlanFormView(
                    templates: workoutTemplates,
                    onSave: { LibraryService.createPlan($0, using: modelContext) },
                    onSaveRepeating: { LibraryService.createRepeatingPlan($0, using: modelContext) }
                )
            }
        }
        .sheet(isPresented: $isShowingDiscoveryFilters) {
            let snapshot = readyMadeSnapshot
                ?? ReadyMadeProgramSnapshot(records: programDefinitions)
            ProgramDiscoveryFilterSheet(
                filters: $discoveryFilters,
                disciplines: availableDisciplines(in: snapshot),
                goals: availableGoals(in: snapshot),
                experienceLevels: availableExperienceLevels(in: snapshot),
                daysPerWeek: availableDaysPerWeek(in: snapshot),
                durationWeeks: availableDurations(in: snapshot),
                scheduleModes: availableScheduleModes(in: snapshot),
                equipment: availableEquipment(in: snapshot),
                capabilityIDs: availableCapabilityIDs(in: snapshot)
            )
        }
    }

    private func createPlan() {
        isShowingPlanForm = true
    }

    private func matchesSearch(_ plan: WorkoutPlan) -> Bool {
        searchText.isEmpty || plan.name.localizedCaseInsensitiveContains(searchText)
    }

    private func matchesSearch(_ plan: RepeatingPlan) -> Bool {
        searchText.isEmpty || plan.name.localizedCaseInsensitiveContains(searchText)
    }

    /// "Mine" means plans the user built. Everything the app shipped belongs in
    /// "Ready-made", whether it arrived as a program definition or as a seeded
    /// plan, so the two lists never claim the same plan.
    func isAppProvided(_ plan: WorkoutPlan) -> Bool {
        PlanOwnership.isAppProvided(plan, seedRecords: seedRecords)
    }

    func isAppProvided(_ plan: RepeatingPlan) -> Bool {
        PlanOwnership.isAppProvided(plan, seedRecords: seedRecords)
    }

    /// All three, always.
    ///
    /// "Ready-made" used to be hidden unless `.programBuilder` was enabled,
    /// which tied discovery of shipped content to an *authoring* capability:
    /// withholding the program builder from a wave would also have removed
    /// every bundled plan from browse, and with it the destination onboarding's
    /// recommendations push people toward. Reading a plan the app ships is not
    /// the same permission as building one.
    private var visibleScopes: [Scope] { Scope.allCases }

    /// Whether the list is currently narrowed by a query, which is the
    /// difference between "nothing matched" and "you have nothing".
    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var filterButtonTitle: String {
        discoveryFilters.isEmpty
            ? String(localized: "Refine")
            : String(localized: "Refine, \(discoveryFilters.activeFacetCount) active")
    }

    /// What the lifter told us, or `nil` when they have never answered anything.
    private var matchingCriteria: ProgramMatchCriteria? {
        guard let profile = trainingProfiles.first else { return nil }
        let criteria = profile.matchingCriteria
        // An existing user who has never seen onboarding has a profile full of
        // `nil`. Ranking against nothing produces the catalogue's own order
        // wearing a label that claims it was personalised, which is the one
        // claim this control must never make falsely.
        return criteria.isEmpty ? nil : criteria
    }

    /// Whether ranking is a mode this screen may honestly offer at all.
    private var canRank: Bool { matchingCriteria != nil }

    /// The ordering actually applied. Falls back to alphabetical whenever there
    /// is nothing to rank against, regardless of the remembered preference — so
    /// a lifter who ranked, then cleared their profile, sees A–Z rather than a
    /// "Ranked for you" list ordered by nothing.
    private var effectiveOrdering: Ordering {
        canRank ? storedOrdering : .alphabetical
    }

    /// Shown only in the catalogue, and only when both options mean something.
    ///
    /// `Following` and `Mine` are not ranked catalogues — they are lists of
    /// what the lifter already has, where "which fits me best" is not the
    /// question being asked.
    @ViewBuilder
    private func orderingControl(hasUnfilteredReadyMadeDefinitions: Bool) -> some View {
        if scope == .readyMade, canRank, hasUnfilteredReadyMadeDefinitions {
            Picker("Order", selection: $storedOrdering) {
                ForEach(Ordering.allCases) { ordering in
                    Text(ordering.title)
                        .tag(ordering)
                        .accessibilityLabel(ordering.accessibilityLabel)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("plans-ordering")
        }
    }

    /// Teaches the two scheduled paths, where the distinction is actually needed.
    ///
    /// This used to render above all three scopes, permanently, and took roughly
    /// the top third of the first screen — so the answer to "which plan should I
    /// pick" opened with a vocabulary lesson and pushed the plans themselves
    /// below the fold. It also taught "Free Workout", which is not a thing this
    /// screen lists.
    ///
    /// It survives only where the vocabulary is load-bearing: someone following
    /// nothing, deciding between a program and a rotation for the first time.
    /// Once either exists, the list demonstrates the difference better than the
    /// card explained it.
    @ViewBuilder
    private var strengthPathsHeader: some View {
        if shouldExplainStrengthPaths {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Two ways to follow a plan")
                    .font(AppFont.captionBold)
                    .tracking(0.8)
                    .foregroundStyle(Color.trameSubdued)
                    .textCase(.uppercase)

                VStack(alignment: .leading, spacing: Spacing.s) {
                    pathExplanationRow(
                        title: "Program",
                        description: "My sessions are scheduled across weeks."
                    )
                    pathExplanationRow(
                        title: "Rotation",
                        description: "I always do the next workout, regardless of weekday."
                    )
                }
            }
            .padding(.vertical, Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) { Rectangle().fill(Color.trameSeparator).frame(height: 1) }
            .accessibilityElement(children: .contain)
        }
    }

    private var shouldExplainStrengthPaths: Bool {
        !isSearching && followedFixedPlans.isEmpty && followedRepeatingPlans.isEmpty
    }

    /// Stacked, not columned. The title and its quoted description were an
    /// `HStack` that ran out of width as soon as Dynamic Type grew, wrapping the
    /// quote into a ragged column beside a one-word label.
    private func pathExplanationRow(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title)
                .font(AppFont.captionBold)
                .foregroundStyle(Color.trameText)
            Text("“\(description)”")
                .font(AppFont.caption)
                .foregroundStyle(Color.trameSubdued)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(description)")
    }

    /// Landing on an empty "Following" tab teaches nothing, so a user with no
    /// open run starts on the list they can actually act from.
    private func selectInitialScope() {
        guard followedFixedPlans.isEmpty, followedRepeatingPlans.isEmpty else { return }
        scope = .readyMade
    }
}

// MARK: - Following

private extension PlansBrowserView {
    var followedFixedPlans: [WorkoutPlan] {
        plans.filter { plan in
            plan.runs.contains { $0.status == .active || $0.status == .paused || $0.status == .testDayAvailable }
        }
        .filter(matchesSearch)
    }

    var followedRepeatingPlans: [RepeatingPlan] {
        repeatingPlans.filter { plan in
            plan.runs.contains { $0.status == .active || $0.status == .paused }
        }
        .filter(matchesSearch)
    }

    @ViewBuilder
    var followingSections: some View {
        if followedFixedPlans.isEmpty && followedRepeatingPlans.isEmpty {
            // A query that matched nothing is not a report about the library.
            // Telling someone who follows three plans that they are "not
            // following a plan" — and offering to build one — because they
            // mistyped a name is the screen answering a question nobody asked.
            if isSearching {
                ContentUnavailableView.search(text: searchText)
            } else {
                ContentUnavailableView {
                    Label("Not following a plan", systemImage: AppIcon.plan)
                } description: {
                    Text("Pick a ready-made plan or build your own, and Today will tell you what to train.")
                } actions: {
                    Button("Build a plan", action: createPlan)
                        .buttonStyle(.tramePrimaryAction)
                        .accessibilityIdentifier("create-plan-empty-state")
                }
            }
        } else {
            planSection("Following") {
                ForEach(Array(followedFixedPlans.enumerated()), id: \.element.id) { index, plan in
                    if index > 0 { rowDivider }
                    fixedPlanRow(plan)
                }
                ForEach(Array(followedRepeatingPlans.enumerated()), id: \.element.id) { index, plan in
                    if index > 0 || !followedFixedPlans.isEmpty { rowDivider }
                    repeatingPlanRow(plan)
                }
            }
        }
    }
}

// MARK: - Mine

private extension PlansBrowserView {
    var activePlans: [WorkoutPlan] {
        plans
            .filter { !$0.isArchived && !isAppProvided($0) }
            .filter(matchesSearch)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var archivedPlans: [WorkoutPlan] {
        plans
            .filter { $0.isArchived && !isAppProvided($0) }
            .filter(matchesSearch)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var activeRepeatingPlans: [RepeatingPlan] {
        repeatingPlans
            .filter { !$0.isArchived && !isAppProvided($0) }
            .filter(matchesSearch)
            .sorted { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    var archivedRepeatingPlans: [RepeatingPlan] {
        repeatingPlans
            .filter { $0.isArchived && !isAppProvided($0) }
            .filter(matchesSearch)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    @ViewBuilder
    var mineSections: some View {
        if activePlans.isEmpty && activeRepeatingPlans.isEmpty && archivedPlans.isEmpty && archivedRepeatingPlans.isEmpty {
            if isSearching {
                ContentUnavailableView.search(text: searchText)
            } else {
                ContentUnavailableView {
                    Label("No training plans yet", systemImage: AppIcon.planAdd)
                } description: {
                    Text("A training plan schedules your saved workouts across the week so you always know what to train next.")
                } actions: {
                    Button("Create a plan", action: createPlan)
                        .buttonStyle(.tramePrimaryAction)
                        .accessibilityIdentifier("create-program-empty-state")
                }
            }
        } else {
            if !activePlans.isEmpty || !activeRepeatingPlans.isEmpty {
                planSection("Active") {
                    ForEach(Array(activePlans.enumerated()), id: \.element.id) { index, plan in
                        if index > 0 { rowDivider }
                        fixedPlanRow(plan)
                    }
                    ForEach(Array(activeRepeatingPlans.enumerated()), id: \.element.id) { index, plan in
                        if index > 0 || !activePlans.isEmpty { rowDivider }
                        repeatingPlanRow(plan)
                    }
                }
            }

            if !archivedPlans.isEmpty || !archivedRepeatingPlans.isEmpty {
                planSection("Archived") {
                    ForEach(Array(archivedPlans.enumerated()), id: \.element.id) { index, plan in
                        if index > 0 { rowDivider }
                        fixedPlanRow(plan)
                    }
                    ForEach(Array(archivedRepeatingPlans.enumerated()), id: \.element.id) { index, plan in
                        if index > 0 || !archivedPlans.isEmpty { rowDivider }
                        repeatingPlanRow(plan)
                    }
                }
            }
        }
    }
}

// MARK: - Ready-made

private extension PlansBrowserView {
    /// Filters narrow, then search narrows, then the chosen ordering sorts what
    /// is left. The decoded candidates come from the render's shared snapshot;
    /// this path must not decode the same payload a second time for ranking.
    ///
    /// The order of those three stages is not cosmetic. Ranking may only
    /// *reorder*; an explicit filter is the only thing allowed to remove a plan
    /// from view. Running the rank before the filters would leave a low-scoring
    /// plan excluded at the end anyway, and would invite counts that describe a
    /// universe the lifter is not actually looking at.
    func readyMadeRecords(in snapshot: ReadyMadeProgramSnapshot) -> [ProgramDefinitionRecord] {
        let narrowed = snapshot.entries
            .filter { entry in
                searchText.isEmpty || entry.record.name.localizedCaseInsensitiveContains(searchText)
            }
            .filter { discoveryFilters.matches($0.candidate) }
            .map(\.record)

        switch effectiveOrdering {
        case .alphabetical:
            return narrowed.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .rankedForYou:
            return rankedOrder(of: narrowed, candidatesByRecordID: snapshot.candidatesByRecordID)
        }
    }

    /// The narrowed set, ordered by `ProgramMatchService`.
    ///
    /// Ranks only what survived filtering and search, so the ordering describes
    /// the list actually on screen. Every record here already has a decoded
    /// candidate in the render snapshot; the missing-position cases remain
    /// defensive so ranking can never silently hide a record if the snapshot
    /// and narrowed records diverge.
    func rankedOrder(
        of records: [ProgramDefinitionRecord],
        candidatesByRecordID: [UUID: ProgramMatchCandidate]
    ) -> [ProgramDefinitionRecord] {
        guard let criteria = matchingCriteria else {
            return records.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }

        let ranked = ProgramMatchService.rank(
            programs: records.compactMap { candidatesByRecordID[$0.id] },
            criteria: criteria
        )
        let position = Dictionary(
            uniqueKeysWithValues: ranked.enumerated().map { ($0.element.programID, $0.offset) }
        )

        return records.sorted { lhs, rhs in
            switch (position[lhs.id], position[rhs.id]) {
            case let (left?, right?):
                return left < right
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            case (nil, nil):
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        }
    }

    func availableDisciplines(in snapshot: ReadyMadeProgramSnapshot) -> [TrainingDisciplinePreference] {
        let ids = Set(snapshot.candidates.flatMap(\.supportedDisciplineIDs))
        return TrainingDisciplinePreference.allCases.filter { ids.contains($0.rawValue) }
    }

    func availableGoals(in snapshot: ReadyMadeProgramSnapshot) -> [PlanGoal] {
        let values = Set(snapshot.candidates.map(\.goal))
        return PlanGoal.allCases.filter(values.contains)
    }

    func availableExperienceLevels(in snapshot: ReadyMadeProgramSnapshot) -> [PlanExperienceLevel] {
        let values = Set(snapshot.candidates.map(\.experienceLevel))
        return PlanExperienceLevel.allCases.filter(values.contains)
    }

    func availableDaysPerWeek(in snapshot: ReadyMadeProgramSnapshot) -> [Int] {
        Set(snapshot.candidates.flatMap(\.supportedDaysPerWeek)).sorted()
    }

    func availableDurations(in snapshot: ReadyMadeProgramSnapshot) -> [Int] {
        Set(snapshot.candidates.map(\.durationWeeks)).sorted()
    }

    func availableScheduleModes(in snapshot: ReadyMadeProgramSnapshot) -> [PlanScheduleMode] {
        let values = Set(snapshot.candidates.map(\.scheduleMode))
        return PlanScheduleMode.allCases.filter(values.contains)
    }

    func availableEquipment(in snapshot: ReadyMadeProgramSnapshot) -> [EquipmentType] {
        let candidates = snapshot.candidates.map(\.equipmentRequirement)
        let values = Set(candidates.flatMap { $0.allOf + $0.anyOf.flatMap { $0 } })
        return EquipmentType.onboardingOrder.filter(values.contains)
    }

    func availableCapabilityIDs(in snapshot: ReadyMadeProgramSnapshot) -> [String] {
        Set(snapshot.candidates.flatMap(\.equipmentRequirement.requiredCapabilityIDs))
            .sorted { SpecializedEquipmentCapability.title(for: $0) < SpecializedEquipmentCapability.title(for: $1) }
    }

    /// Plans the app seeded directly, as opposed to as a program definition.
    /// They are excluded from "Mine", so this is the only place they appear.
    var seededPlans: [WorkoutPlan] {
        plans
            .filter { !$0.isArchived && isAppProvided($0) }
            .filter(matchesSearch)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var seededRepeatingPlans: [RepeatingPlan] {
        repeatingPlans
            .filter { !$0.isArchived && isAppProvided($0) }
            .filter(matchesSearch)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Names the ordering actually in effect, so the list never claims to be
    /// personalised when it is alphabetical — the same honesty
    /// `OnboardingRecommendationsView.headerSubtitle` already enforces when it
    /// refuses to say "ranked from your answers" to someone who skipped every
    /// question.
    var readyMadeSectionTitle: LocalizedStringKey {
        effectiveOrdering == .rankedForYou ? "Ranked for you" : "Ready-made"
    }

    @ViewBuilder
    func readyMadeSection(snapshot: ReadyMadeProgramSnapshot) -> some View {
        let readyMadeRecords = readyMadeRecords(in: snapshot)
        let seededPlans = self.seededPlans
        let seededRepeatingPlans = self.seededRepeatingPlans
        let hasReadyMadeContent = snapshot.hasActiveBuiltInRecords
            || !seededPlans.isEmpty
            || !seededRepeatingPlans.isEmpty

        if !hasReadyMadeContent {
            // Order matters. A search that matched nothing was previously
            // indistinguishable from a catalogue that failed to install, so
            // mistyping a plan name reported "The built-in plans could not be
            // loaded" — an infrastructure failure, raised for a typo, right
            // next to the genuine failure view that means it.
            if isSearching {
                ContentUnavailableView.search(text: searchText)
            } else if catalogInstallState.failure != nil {
                SystemCatalogUnavailableView {
                    AppBootstrap.seedSystemCatalog(using: modelContext)
                }
            } else {
                // Reachable without a recorded failure the first frame or two
                // after launch, before `AppBootstrap.seedSystemCatalog` has run
                // at all — the launch overlay covers this screen for that
                // entire window, so nobody actually sees it.
                ContentUnavailableView(
                    "No plans available",
                    systemImage: AppIcon.plan,
                    description: Text("The built-in plans could not be loaded.")
                )
            }
        } else {
            if readyMadeRecords.isEmpty,
               snapshot.hasActiveBuiltInRecords,
               (!discoveryFilters.isEmpty || isSearching) {
                if discoveryFilters.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ContentUnavailableView {
                        Label("No plans match", systemImage: AppIcon.filters)
                    } description: {
                        Text("Change your search or refinements to see more plans.")
                    } actions: {
                        Button("Clear refinements") { discoveryFilters.clear() }
                            .font(AppFont.subheadlineSemibold)
                            .foregroundStyle(Color.trameStrength)
                            .buttonStyle(.gymPress)
                            .accessibilityIdentifier("program-discovery-clear-filters")
                    }
                }
            }
            // Sits with the list it orders rather than in the pinned strip
            // above. Search and scope are already stacked up there; a third
            // permanent control would push the first plan further down the
            // screen the catalogue exists to show, and this one applies to a
            // single scope, so pinning it would also make that strip change
            // height as the lifter switches tabs.
            orderingControl(hasUnfilteredReadyMadeDefinitions: snapshot.hasActiveBuiltInRecords)

            if !readyMadeRecords.isEmpty {
                planSection(readyMadeSectionTitle) {
                    ForEach(Array(readyMadeRecords.enumerated()), id: \.element.id) { index, record in
                        if index > 0 { rowDivider }
                        NavigationLink(value: LibraryRoute.readyMadePlan(record.id)) {
                            planRow(
                                name: record.name,
                                // Goal leads. Every bundled plan declares one,
                                // and without it the catalogue is a list of
                                // names distinguished only by week and day
                                // counts — "Conjugate Rotation Wave, 6 weeks,
                                // 4 days" says nothing about what it is for.
                                detail: "\(record.goal.onboardingTitle) · \(record.durationWeeks) weeks · \(record.supportedDaysPerWeek.map(String.init).joined(separator: "/")) days per week",
                                icon: AppIcon.planCatalog,
                                badge: record.experienceLevel.onboardingTitle
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("program-catalog-\(record.name)")
                    }
                }
            }

            if !seededPlans.isEmpty || !seededRepeatingPlans.isEmpty {
                planSection("Included with the app") {
                    ForEach(Array(seededPlans.enumerated()), id: \.element.id) { index, plan in
                        if index > 0 { rowDivider }
                        fixedPlanRow(plan)
                    }
                    ForEach(Array(seededRepeatingPlans.enumerated()), id: \.element.id) { index, plan in
                        if index > 0 || !seededPlans.isEmpty { rowDivider }
                        repeatingPlanRow(plan)
                    }
                }
            }
        }
    }
}

// MARK: - Rows

private extension PlansBrowserView {
    func fixedPlanRow(_ plan: WorkoutPlan) -> some View {
        NavigationLink(value: LibraryRoute.plan(plan.id)) {
            planRow(
                name: plan.name,
                detail: "\(plan.durationWeeks) weeks · \(plan.daysPerWeek) days per week",
                icon: AppIcon.plan,
                badge: runBadge(for: plan)
            )
        }
        // Outside a `List`, a `NavigationLink` renders its label as a tinted
        // button — every row title would have gone blue.
        .buttonStyle(.plain)
        .accessibilityIdentifier("plan-row-\(plan.name)")
    }

    func repeatingPlanRow(_ plan: RepeatingPlan) -> some View {
        NavigationLink(value: LibraryRoute.repeatingPlan(plan.id)) {
            planRow(
                name: plan.name,
                detail: RepeatingPlanPresentation.rotationSummary(slotCount: plan.orderedSlots.count),
                icon: AppIcon.routine,
                badge: repeatingRunBadge(for: plan) ?? String(localized: "Repeats")
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("repeating-plan-row-\(plan.id)")
    }

    /// Length is stated on every row so a repeating plan and an eight-week plan
    /// are never confused for two different kinds of object.
    ///
    /// The chevron and the row's own tint are drawn here rather than inherited.
    /// Inside a `List` the system supplied both; this screen is a `ScrollView`
    /// of cards now, where a bare `NavigationLink` renders as an untinted button
    /// with no disclosure indicator at all — so a row would have stopped looking
    /// tappable.
    func planRow(name: String, detail: String, icon: String, badge: String?) -> some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: icon)
                .foregroundStyle(Color.trameStrength)
                .frame(width: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(name)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.trameText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.trameSubdued)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Spacing.s)
            if let badge {
                Text(badge)
                    .font(AppFont.caption2Bold)
                    .foregroundStyle(Color.trameSubdued)
                    .padding(.horizontal, Spacing.s)
                    .padding(.vertical, Spacing.xxs)
                    .background(Color.trameRow, in: Capsule())
                    .fixedSize()
            }
            Image(systemName: AppIcon.chevronRight)
                .font(AppFont.caption2Bold)
                .foregroundStyle(Color.trameSubdued)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, Spacing.m)
        .frame(minHeight: ComponentSize.minimumTouchTarget)
        .contentShape(Rectangle())
        // One stop per row rather than three. Twenty-one plans meant sixty-odd
        // swipes to cross the catalogue, and the badge — read on its own as a
        // bare "Advanced" — did not say what it described.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel(name: name, detail: detail, badge: badge))
    }

    /// One card holding a group of rows, hairline-separated.
    ///
    /// The same container Today's "Log today" list and the program detail
    /// screen's sections use, so the catalogue stops being the one discovery
    /// surface wearing system list chrome.
    func planSection<Content: View>(
        _ title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title)
                .font(AppFont.captionBold)
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(Color.trameSubdued)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                content()
            }
            .overlay(alignment: .top) { Rectangle().fill(Color.trameSeparator).frame(height: 1) }
        }
    }

    /// The separator between rows inside a `planSection`. Inset past the icon
    /// chip so it reads as dividing a list rather than cutting the card in two.
    var rowDivider: some View {
        Divider()
            .overlay(Color.trameSeparator)
            .padding(.leading, Spacing.l + ComponentSize.iconChip + Spacing.m)
    }

    /// The badge is not one kind of thing — it carries an experience level on a
    /// ready-made row and a run status ("Following", "Paused") everywhere else —
    /// so it is read as its own clause rather than wrapped in a sentence that
    /// would be true for only one of them.
    func rowAccessibilityLabel(name: String, detail: String, badge: String?) -> String {
        guard let badge else { return "\(name), \(detail)" }
        return "\(name), \(detail), \(badge)"
    }

    func runBadge(for plan: WorkoutPlan) -> String? {
        if plan.runs.contains(where: { $0.status == .active }) { return String(localized: "Following") }
        if plan.runs.contains(where: { $0.status == .paused }) { return String(localized: "Paused") }
        return nil
    }

    func repeatingRunBadge(for plan: RepeatingPlan) -> String? {
        if plan.runs.contains(where: { $0.status == .active }) { return String(localized: "Following") }
        if plan.runs.contains(where: { $0.status == .paused }) { return String(localized: "Paused") }
        return nil
    }
}
