import SwiftData
import SwiftUI

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

    @Environment(\.modelContext) private var modelContext
    @Query private var plans: [WorkoutPlan]
    @Query private var repeatingPlans: [RepeatingPlan]
    @Query private var programDefinitions: [ProgramDefinitionRecord]
    @Query private var workoutTemplates: [WorkoutTemplate]
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
    private let featureFlags: FeatureFlagConfiguration = FeatureFlags.current

    var body: some View {
        // The scope control sits outside the list rather than in its first row:
        // as a scrolling row it shared the same strip as the searchable drawer
        // and the two drew on top of each other. Pinned, it also stays reachable
        // while the list scrolls.
        VStack(spacing: 0) {
            Picker("Show", selection: $scope) {
                ForEach(visibleScopes) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("plans-scope")
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.s)

            List {
                switch scope {
                case .following: followingSections
                case .mine: mineSections
                case .readyMade: readyMadeSection
                }
            }
            .scrollContentBackground(.hidden)
            .accessibilityIdentifier("plans-browser-list")
        }
        .background(Color.gymBackground)
        .searchable(text: $searchText, prompt: "Search plans")
        .navigationTitle("Plans")
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

    private var visibleScopes: [Scope] {
        featureFlags.isEnabled(.programBuilder)
            ? Scope.allCases
            : Scope.allCases.filter { $0 != .readyMade }
    }

    /// Landing on an empty "Following" tab teaches nothing, so a user with no
    /// open run starts on the list they can actually act from.
    private func selectInitialScope() {
        guard followedFixedPlans.isEmpty, followedRepeatingPlans.isEmpty else { return }
        scope = featureFlags.isEnabled(.programBuilder) ? .readyMade : .mine
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
            Section {
                ContentUnavailableView {
                    Label("Not following a plan", systemImage: AppIcon.plan)
                } description: {
                    Text("Pick a ready-made plan or build your own, and Today will tell you what to train.")
                } actions: {
                    Button("Build a plan", action: createPlan)
                        .buttonStyle(.borderedProminent)
                        .tint(Color.gymPrimary)
                        .accessibilityIdentifier("create-plan-empty-state")
                }
            }
            .listRowBackground(Color.clear)
        } else {
            Section("Following") {
                ForEach(followedFixedPlans) { plan in
                    fixedPlanRow(plan)
                }
                ForEach(followedRepeatingPlans) { plan in
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
            Section {
                ContentUnavailableView {
                    Label("No training plans yet", systemImage: AppIcon.planAdd)
                } description: {
                    Text("A training plan schedules your saved workouts across the week so you always know what to train next.")
                } actions: {
                    Button("Create a plan", action: createPlan)
                        .buttonStyle(.borderedProminent)
                        .tint(Color.gymPrimary)
                        .accessibilityIdentifier("create-program-empty-state")
                }
            }
            .listRowBackground(Color.clear)
        } else {
            if !activePlans.isEmpty || !activeRepeatingPlans.isEmpty {
                Section("Active") {
                    ForEach(activePlans) { plan in
                        fixedPlanRow(plan)
                    }
                    ForEach(activeRepeatingPlans) { plan in
                        repeatingPlanRow(plan)
                    }
                }
            }

            if !archivedPlans.isEmpty || !archivedRepeatingPlans.isEmpty {
                Section("Archived") {
                    ForEach(archivedPlans) { plan in
                        fixedPlanRow(plan)
                    }
                    ForEach(archivedRepeatingPlans) { plan in
                        repeatingPlanRow(plan)
                    }
                }
            }
        }
    }
}

// MARK: - Ready-made

private extension PlansBrowserView {
    var readyMadeRecords: [ProgramDefinitionRecord] {
        programDefinitions
            .filter { $0.isBuiltIn && !$0.isArchived }
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
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

    var hasReadyMadeContent: Bool {
        !readyMadeRecords.isEmpty || !seededPlans.isEmpty || !seededRepeatingPlans.isEmpty
    }

    @ViewBuilder
    var readyMadeSection: some View {
        if !hasReadyMadeContent {
            Section {
                if catalogInstallState.failure != nil {
                    SystemCatalogUnavailableView {
                        AppBootstrap.seedSystemCatalog(using: modelContext)
                    }
                } else {
                    // Reachable without a recorded failure the first frame or
                    // two after launch, before `AppBootstrap.seedSystemCatalog`
                    // has run at all — the launch overlay covers this screen
                    // for that entire window, so nobody actually sees it.
                    ContentUnavailableView(
                        "No plans available",
                        systemImage: AppIcon.plan,
                        description: Text("The built-in plans could not be loaded.")
                    )
                }
            }
            .listRowBackground(Color.clear)
        } else {
            if !readyMadeRecords.isEmpty {
                Section("Ready-made") {
                    ForEach(readyMadeRecords) { record in
                        NavigationLink(value: LibraryRoute.readyMadePlan(record.id)) {
                            planRow(
                                name: record.name,
                                detail: "\(record.durationWeeks) weeks · \(record.supportedDaysPerWeek.map(String.init).joined(separator: "/")) days per week",
                                icon: AppIcon.planCatalog,
                                badge: record.experienceLevel.rawValue.localizedCapitalized
                            )
                        }
                        .accessibilityIdentifier("program-catalog-\(record.name)")
                    }
                }
            }

            if !seededPlans.isEmpty || !seededRepeatingPlans.isEmpty {
                Section("Included with the app") {
                    ForEach(seededPlans) { plan in
                        fixedPlanRow(plan)
                    }
                    ForEach(seededRepeatingPlans) { plan in
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
        .accessibilityIdentifier("repeating-plan-row-\(plan.id)")
    }

    /// Length is stated on every row so a repeating plan and an eight-week plan
    /// are never confused for two different kinds of object.
    func planRow(name: String, detail: String, icon: String, badge: String?) -> some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: icon)
                .foregroundStyle(Color.gymAccent)
                .frame(width: 32, height: 32)
                .background(Color.gymAccentSurface, in: Circle())
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(name)
                    .font(AppFont.subheadlineSemibold)
                Text(detail)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
            Spacer(minLength: Spacing.s)
            if let badge {
                Text(badge)
                    .font(AppFont.caption2Bold)
                    .foregroundStyle(Color.gymSubduedText)
                    .padding(.horizontal, Spacing.s)
                    .padding(.vertical, Spacing.xxs)
                    .background(Color.gymRowSurface, in: Capsule())
            }
        }
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
