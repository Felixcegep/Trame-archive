import SwiftUI
import SwiftData

#if !GYMTRACKER_EXTENSION

/// The one door into starting an unplanned session.
///
/// Designed as a Trame open canvas: one editorial personalized entry,
/// a subordinate empty workout entry, an integrated search and focus instrument,
/// and quiet, compact template rows with automatic word deduplication in metadata.
struct SavedWorkoutTemplatePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Query(filter: #Predicate<WorkoutTemplate> { !$0.isArchived })
    private var templates: [WorkoutTemplate]
    @Query(filter: #Predicate<Exercise> { !$0.isArchived })
    private var availableExercises: [Exercise]

    let onStartWorkout: (WorkoutTemplate) -> Void
    let onStartEmpty: () -> Void
    let onStartPersonalized: (ValidatedWorkoutDraft) -> Bool

    @State private var builderPresentation: BuilderPresentation?
    @State private var searchText = ""
    @State private var selectedFocus: WorkoutTemplateFocus?
    /// Derived once per library change rather than per render. Each summary
    /// walks a workout's exercises and its past sessions, which is work no
    /// keystroke in the search field should repeat.
    @State private var items: [BrowseItem] = []

    /// The filter strip earns its vertical space only once the list is long
    /// enough to be a scrolling problem. Below that it is chrome over a list
    /// the user can already see all of.
    private static let focusFilterMinimumTemplates = 8
    private static let recentTemplateLimit = 3

    var body: some View {
        let sections = makeBrowseSections()

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                entryArea

                libraryControls
                    .padding(.top, Spacing.xxxl)

                if templates.isEmpty {
                    emptyLibraryState
                        .padding(.top, Spacing.xxxl)
                } else if sections.visibleCount == 0 {
                    noMatchesState
                        .padding(.top, Spacing.xxxl)
                } else {
                    templateSection(
                        "Recent",
                        items: sections.recent
                    )

                    templateSection(
                        "Yours",
                        items: sections.own
                    )

                    templateSection(
                        "Starter",
                        items: sections.starter
                    )
                }
            }
            .padding(.horizontal, Spacing.screenInset)
            .padding(.top, Spacing.s)
            .padding(.bottom, Spacing.xxxl)
        }
        .scrollIndicators(.hidden)
        .background(Color.trameCanvas)
        .foregroundStyle(Color.trameText)
        .navigationTitle("Start workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(
            Color.trameCanvas,
            for: .navigationBar
        )
        .toolbarBackground(
            .visible,
            for: .navigationBar
        )
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .onAppear(perform: rebuildItems)
        .onChange(of: templateRevision) { _, _ in
            rebuildItems()
        }
        .sheet(item: $builderPresentation) { presentation in
            PersonalizedWorkoutBuilderView(
                availableExercises: availableExercises,
                launchRequest: presentation.launchRequest,
                onStart: { draft in
                    guard onStartPersonalized(draft) else {
                        return false
                    }

                    builderPresentation = nil
                    return true
                }
            )
        }
    }
}

// MARK: - Presentation Types

private extension SavedWorkoutTemplatePicker {
    /// Identity for the builder sheet, so a quick-start chip can carry its
    /// prefilled request into a fresh presentation instead of a bare flag.
    struct BuilderPresentation: Identifiable {
        let id = UUID()
        let launchRequest: WorkoutGenerationLaunchRequest?
    }

    /// One tap should be able to mean "upper body, sort it out" — the quick
    /// starts prefill the builder's request rather than generating blind, so
    /// the lifter still confirms duration, equipment, and the draft itself.
    struct QuickStart: Identifiable {
        let focus: WorkoutTemplateFocus
        let request: String

        var id: WorkoutTemplateFocus { focus }
    }

    static let quickStarts: [QuickStart] = [
        QuickStart(focus: .upperBody, request: String(localized: "Upper body workout")),
        QuickStart(focus: .lowerBody, request: String(localized: "Lower body workout")),
        QuickStart(focus: .fullBody, request: String(localized: "Full body workout"))
    ]
}

// MARK: - Entry Area

private extension SavedWorkoutTemplatePicker {
    @ViewBuilder
    private var entryArea: some View {
        if isGenerationOffered {
            personalizedEntry

            startEmptyRow
                .padding(.top, Spacing.xl)
        } else {
            startEmptyHero
        }
    }

    private var personalizedEntry: some View {
        VStack(spacing: 0) {
            Button {
                builderPresentation = BuilderPresentation(
                    launchRequest: nil
                )
            } label: {
                HStack(
                    alignment: .center,
                    spacing: Spacing.l
                ) {
                    Rectangle()
                        .fill(Color.trameStrength)
                        .frame(width: 6, height: 52)
                        .accessibilityHidden(true)

                    VStack(
                        alignment: .leading,
                        spacing: Spacing.xs
                    ) {
                        Text("PERSONALISED")
                            .font(AppFont.eyebrow)
                            .tracking(1)
                            .foregroundStyle(Color.trameStrength)

                        Text("Build for today")
                            .font(AppFont.titleMedium)
                            .foregroundStyle(Color.trameText)
                    }

                    Spacer(minLength: Spacing.l)

                    Image(
                        systemName: AppIcon.chevronRight
                    )
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.trameSubdued)
                    .accessibilityHidden(true)
                }
                .padding(.vertical, Spacing.l)
                .frame(
                    maxWidth: .infinity,
                    minHeight: ComponentSize.minimumTouchTarget,
                    alignment: .leading
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.gymPress)
            .accessibilityIdentifier(
                "build-personalized-workout-entry"
            )
            .accessibilityLabel(
                "Build a personalised workout for today"
            )
            .accessibilityHint(
                "Opens the workout builder."
            )

            Divider()
                .overlay(Color.trameSeparator)

            quickBuildRow
        }
    }

    private var quickBuildRow: some View {
        HStack(spacing: 0) {
            ForEach(
                Array(Self.quickStarts.enumerated()),
                id: \.element.id
            ) { index, quickStart in
                if index > 0 {
                    Rectangle()
                        .fill(Color.trameSeparator)
                        .frame(width: 1)
                        .accessibilityHidden(true)
                }

                Button {
                    builderPresentation = BuilderPresentation(
                        launchRequest:
                            WorkoutGenerationLaunchRequest(
                                request: quickStart.request
                            )
                    )
                } label: {
                    Text(
                        quickStart.focus.startPickerTitle
                    )
                    .font(AppFont.metadata)
                    .frame(
                        maxWidth: .infinity,
                        minHeight:
                            ComponentSize.minimumTouchTarget
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.gymPress)
                .accessibilityIdentifier(
                    "quick-build-\(quickStart.focus.rawValue)"
                )
                .accessibilityLabel(
                    "\(quickStart.focus.title) personalised workout"
                )
            }
        }
    }

    private var startEmptyRow: some View {
        Button(action: onStartEmpty) {
            HStack(spacing: Spacing.m) {
                Image(systemName: AppIcon.plus)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.trameStrength)
                    .frame(width: ComponentSize.iconChip)
                    .accessibilityHidden(true)

                Text("Start empty")
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.trameText)

                Spacer(minLength: Spacing.m)
            }
            .padding(.vertical, Spacing.md)
            .frame(
                minHeight: ComponentSize.minimumTouchTarget
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .overlay(alignment: .bottom) {
            Divider()
                .overlay(Color.trameSeparator)
        }
        .accessibilityIdentifier("start-empty-workout")
        .accessibilityLabel("Start an empty workout")
        .accessibilityHint(
            "Starts with no exercises. Add exercises as you go."
        )
    }

    private var startEmptyHero: some View {
        Button(action: onStartEmpty) {
            HStack(spacing: Spacing.l) {
                Rectangle()
                    .fill(Color.trameStrength)
                    .frame(width: 6, height: 52)
                    .accessibilityHidden(true)

                Text("Start empty")
                    .font(AppFont.titleMedium)
                    .foregroundStyle(Color.trameText)

                Spacer()

                Image(systemName: AppIcon.play)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.trameStrength)
            }
            .padding(.vertical, Spacing.l)
            .frame(
                maxWidth: .infinity,
                minHeight: 76
            )
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.trameSeparator)
                    .frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .accessibilityIdentifier("start-empty-workout")
        .accessibilityLabel("Start an empty workout")
    }
}

// MARK: - Library Controls (Search & Focus)

private extension SavedWorkoutTemplatePicker {
    private var libraryControls: some View {
        HStack(spacing: Spacing.s) {
            searchField

            if showsFocusFilter {
                focusMenu
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: AppIcon.search)
                .font(AppFont.metadata)
                .foregroundStyle(Color.trameSubdued)

            TextField(
                "Search",
                text: $searchText
            )
            .font(AppFont.bodyMedium)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .accessibilityIdentifier(
                "workout-search"
            )

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(
                        systemName: AppIcon.failureCircle
                    )
                    .foregroundStyle(Color.trameSubdued)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, Spacing.xs)
        .frame(minHeight: ComponentSize.minimumTouchTarget)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.trameSeparator)
                .frame(height: 1)
        }
    }

    private var focusMenu: some View {
        Menu {
            Picker(
                "Focus",
                selection: $selectedFocus
            ) {
                Text("All")
                    .tag(
                        Optional<WorkoutTemplateFocus>.none
                    )

                ForEach(availableFocuses) { focus in
                    Text(focus.title)
                        .tag(Optional(focus))
                }
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Text(selectedFocus?.title ?? String(localized: "All"))
                    .font(AppFont.metadata)
                    .foregroundStyle(selectedFocus == nil ? Color.trameSubdued : Color.trameText)

                Image(systemName: AppIcon.chevronDown)
                    .font(AppFont.micro)
                    .foregroundStyle(Color.trameSubdued)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.s)
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(selectedFocus == nil ? Color.trameSeparator : Color.trameStrength)
                    .frame(height: selectedFocus == nil ? 1 : 2)
            }
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Filter by focus")
        .accessibilityValue(
            selectedFocus?.title ?? "All"
        )
    }
}

// MARK: - Sections & Rows

private extension SavedWorkoutTemplatePicker {
    private func pickerSectionHeader(
        _ title: LocalizedStringKey,
        count: Int
    ) -> some View {
        HStack(spacing: Spacing.m) {
            Text(title)
                .font(AppFont.sectionTitle)
                .foregroundStyle(Color.trameText)
                .textCase(.uppercase)

            Rectangle()
                .fill(Color.trameSeparator)
                .frame(height: 1)
                .accessibilityHidden(true)

            Text(count.formatted())
                .font(AppFont.metadata)
                .monospacedDigit()
                .foregroundStyle(Color.trameSubdued)
        }
    }

    @ViewBuilder
    private func templateSection(
        _ title: LocalizedStringKey,
        items sectionItems: [BrowseItem]
    ) -> some View {
        if !sectionItems.isEmpty {
            VStack(
                alignment: .leading,
                spacing: 0
            ) {
                pickerSectionHeader(
                    title,
                    count: sectionItems.count
                )
                .padding(.bottom, Spacing.s)

                ForEach(sectionItems) { item in
                    templateRow(item)

                    Divider()
                        .overlay(Color.trameSeparator)
                }
            }
            .padding(.top, Spacing.xxxl)
        }
    }

    private func templateRow(
        _ item: BrowseItem
    ) -> some View {
        let isStartable =
            item.summary.exerciseCount > 0

        let visibleDetail =
            compactMetadata(for: item)

        let accessibilityLabel =
            "\(item.template.name). \(item.summary.detailText)"

        return Button {
            onStartWorkout(item.template)
            dismiss()
        } label: {
            HStack(spacing: Spacing.m) {
                Rectangle()
                    .fill(
                        isStartable
                            ? Color.trameStrength
                            : Color.trameSeparator
                    )
                    .frame(
                        width: 4,
                        height: 40
                    )
                    .accessibilityHidden(true)

                VStack(
                    alignment: .leading,
                    spacing: Spacing.xs
                ) {
                    Text(item.template.name)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(
                            isStartable
                                ? Color.trameText
                                : Color.trameSubdued
                        )
                        .lineLimit(2)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )

                    if !visibleDetail.isEmpty {
                        Text(visibleDetail)
                            .font(AppFont.metadata)
                            .foregroundStyle(
                                Color.trameSubdued
                            )
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: Spacing.m)

                if isStartable &&
                    !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: AppIcon.play)
                        .font(AppFont.micro)
                        .foregroundStyle(
                            Color.trameStrength
                        )
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, Spacing.m)
            .frame(
                maxWidth: .infinity,
                minHeight: 64,
                alignment: .leading
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .disabled(!isStartable)
        .accessibilityIdentifier(
            "workout-template-\(item.template.name)"
        )
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(
            isStartable
                ? "Starts this workout."
                : "Add an exercise before starting."
        )
    }

    private func compactMetadata(
        for item: BrowseItem
    ) -> String {
        let summary = item.summary

        guard summary.exerciseCount > 0 else {
            return String(localized: "Empty")
        }

        var parts: [String] = []

        if let minutes = summary.estimatedMinutes {
            parts.append(
                String(localized: "~\(minutes) min")
            )
        }

        if let focus = summary.focus,
           !titleAlreadyContains(
                focus,
                title: item.template.name
           ) {
            parts.append(focus.title)
        }

        // Only use exercise count as a fallback.
        // It is intentionally not repeated on every row.
        if parts.isEmpty {
            if summary.exerciseCount == 1 {
                parts.append(
                    String(localized: "1 exercise")
                )
            } else {
                parts.append(
                    String(
                        localized:
                            "\(summary.exerciseCount) exercises"
                    )
                )
            }
        }

        return parts.joined(separator: " · ")
    }

    private func titleAlreadyContains(
        _ focus: WorkoutTemplateFocus,
        title: String
    ) -> Bool {
        let normalized = title
            .lowercased()
            .replacingOccurrences(
                of: "—",
                with: " "
            )
            .replacingOccurrences(
                of: "-",
                with: " "
            )

        switch focus {
        case .fullBody:
            return normalized.contains("full body")

        case .upperBody:
            return normalized.contains("upper body")

        case .lowerBody:
            return normalized.contains("lower body")

        case .core:
            return normalized.contains("core")
        }
    }
}

// MARK: - Empty States

private extension SavedWorkoutTemplatePicker {
    private var emptyLibraryState: some View {
        ContentUnavailableView(
            "No saved workouts",
            systemImage:
                "rectangle.stack.badge.plus",
            description: Text(
                "Build one above or create one in Train."
            )
        )
    }

    private var noMatchesState: some View {
        ContentUnavailableView {
            Label(
                "No matches",
                systemImage: AppIcon.search
            )
        } actions: {
            Button("Clear") {
                searchText = ""
                selectedFocus = nil
            }
            .accessibilityIdentifier(
                "clear-workout-filters"
            )
        }
    }
}

// MARK: - Data Layer

private extension SavedWorkoutTemplatePicker {
    struct BrowseItem: Identifiable {
        let template: WorkoutTemplate
        let summary: WorkoutTemplateSummary

        var id: PersistentIdentifier { template.persistentModelID }
    }

    struct BrowseSections {
        let visibleCount: Int
        let recent: [BrowseItem]
        let own: [BrowseItem]
        let starter: [BrowseItem]
    }

    var isGenerationOffered: Bool {
        FeatureFlags.current.isEnabled(.workoutGeneration)
    }

    /// Covers every source consumed by `WorkoutTemplateSummary`. Persistent
    /// identifiers alone miss edits to a template, its prescription, an
    /// exercise name/muscle assignment, and newly started source workouts;
    /// any of those would otherwise leave the cached rows and recency section
    /// stale until the picker was reopened.
    var templateRevision: Int {
        var revision = Hasher()
        for template in templates {
            revision.combine(template.persistentModelID)
            revision.combine(template.name)
            revision.combine(template.isBuiltIn)
            for templateExercise in template.templateExercises {
                revision.combine(templateExercise.persistentModelID)
                revision.combine(templateExercise.orderIndex)
                revision.combine(templateExercise.targetSets)
                revision.combine(templateExercise.restSeconds)
                revision.combine(templateExercise.exercise.id)
                revision.combine(templateExercise.exercise.name)
                for muscle in templateExercise.exercise.primaryMuscles {
                    revision.combine(muscle.rawValue)
                }
            }
            for workout in template.sourceWorkouts {
                revision.combine(workout.id)
                revision.combine(workout.startTime)
            }
        }
        return revision.finalize()
    }

    /// The cache, or a fresh derivation on the one frame that precedes
    /// `onAppear`. Reading the cache alone would flash an empty list there.
    var browseItems: [BrowseItem] {
        items.isEmpty && !templates.isEmpty ? makeItems() : items
    }

    func makeItems() -> [BrowseItem] {
        templates
            .map { BrowseItem(template: $0, summary: WorkoutTemplateSummary.make(for: $0)) }
            // Name order, not query order. The old list arrived in whatever
            // order SwiftData returned, so the same workout sat somewhere
            // different every time the sheet opened.
            .sorted { $0.template.name.localizedStandardCompare($1.template.name) == .orderedAscending }
    }

    func rebuildItems() {
        items = makeItems()
    }

    /// Builds the render's three mutually exclusive sections in one pass over
    /// the filtered catalogue. Recency keeps only the three candidates the UI
    /// can display instead of sorting every previously performed template.
    func makeBrowseSections() -> BrowseSections {
        let visible = browseItems.filter { item in
            guard selectedFocus == nil || item.summary.focus == selectedFocus else { return false }
            return SearchNormalization.matches(
                query: searchText,
                primaryName: item.template.name,
                aliases: item.summary.searchAliases
            )
        }

        var recentCandidates: [(item: BrowseItem, date: Date)] = []
        if searchText.isEmpty, selectedFocus == nil {
            for item in visible {
                guard let date = item.summary.lastPerformed else { continue }
                let insertionIndex = recentCandidates.firstIndex { date > $0.date }
                    ?? recentCandidates.endIndex
                guard insertionIndex < Self.recentTemplateLimit else { continue }
                recentCandidates.insert((item, date), at: insertionIndex)
                if recentCandidates.count > Self.recentTemplateLimit {
                    recentCandidates.removeLast()
                }
            }
        }

        let recent = recentCandidates.map(\.item)
        let recentIDs = Set(recent.map(\.id))
        var own: [BrowseItem] = []
        var starter: [BrowseItem] = []
        own.reserveCapacity(visible.count)
        starter.reserveCapacity(visible.count)

        // Recents are removed from the sections below rather than repeated.
        for item in visible where !recentIDs.contains(item.id) {
            if item.template.isBuiltIn {
                starter.append(item)
            } else {
                own.append(item)
            }
        }

        return BrowseSections(
            visibleCount: visible.count,
            recent: recent,
            own: own,
            starter: starter
        )
    }

    var showsFocusFilter: Bool {
        templates.count >= Self.focusFilterMinimumTemplates && availableFocuses.count > 1
    }

    /// Only focuses the library actually contains, in a fixed order. A chip
    /// that can only ever return nothing is worse than no chip.
    var availableFocuses: [WorkoutTemplateFocus] {
        let present = Set(browseItems.compactMap(\.summary.focus))
        return WorkoutTemplateFocus.allCases.filter { present.contains($0) }
    }
}

// MARK: - Focus Helpers

private extension WorkoutTemplateFocus {
    var startPickerTitle: LocalizedStringKey {
        switch self {
        case .fullBody:
            "Full"
        case .upperBody:
            "Upper"
        case .lowerBody:
            "Lower"
        case .core:
            "Core"
        }
    }
}

extension WorkoutTemplateFocus {
    var icon: String {
        switch self {
        case .fullBody: AppIcon.focusFullBody
        case .upperBody: AppIcon.focusUpperBody
        case .lowerBody: AppIcon.focusLowerBody
        case .core: AppIcon.focusCore
        }
    }
}

#endif
