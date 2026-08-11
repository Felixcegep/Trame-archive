import SwiftUI
import SwiftData

#if !GYMTRACKER_EXTENSION

/// The one door into starting an unplanned session.
///
/// It used to be a flat list: two undifferentiated entry rows on top of every
/// saved workout in name-agnostic query order, each row reading "5 exercises".
/// With the seeded library installed that is a twenty-row scroll where nothing
/// distinguishes one row from the next, so this screen is built around the two
/// ways a lifter actually resolves it — "build me one" and "find the one I
/// mean" — with search, a focus filter, and recency doing the finding.
struct SavedWorkoutTemplatePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let templates: [WorkoutTemplate]
    let availableExercises: [Exercise]
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
        VStack(spacing: 0) {
            if showsFocusFilter {
                focusFilterStrip
            }

            list
        }
        .background(Color.gymBackground)
        .navigationTitle("Start a workout")
        // Inline, not large: the hero card below is the screen's title in
        // everything but name, and a large title pushed the first saved
        // workout off the bottom of the sheet.
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search workouts or exercises")
        .onAppear(perform: rebuildItems)
        .onChange(of: templateIdentity) { _, _ in rebuildItems() }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .sheet(item: $builderPresentation) { presentation in
            PersonalizedWorkoutBuilderView(
                availableExercises: availableExercises,
                launchRequest: presentation.launchRequest,
                onStart: { draft in
                    guard onStartPersonalized(draft) else { return false }
                    builderPresentation = nil
                    return true
                }
            )
        }
    }
}

// MARK: - Presentation

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

// MARK: - List

private extension SavedWorkoutTemplatePicker {
    var list: some View {
        List {
            Section {
                if isGenerationOffered {
                    generateCard
                        .modifier(FullBleedRow())
                }

                // Promoted to the hero slot when generation is off, so a build
                // without Apple Intelligence still opens on an invitation
                // rather than on a quiet row above a wall of saved workouts.
                startEmptyCard(isHero: !isGenerationOffered)
                    .modifier(FullBleedRow())
            }

            if templates.isEmpty {
                emptyLibrarySection
            } else if visibleItems.isEmpty {
                noMatchesSection
            } else {
                templateSection("RECENTLY USED", items: recentItems, showsBuiltInBadge: true)
                templateSection("YOUR WORKOUTS", items: ownItems, showsBuiltInBadge: false)
                templateSection("STARTER WORKOUTS", items: starterItems, showsBuiltInBadge: false)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        // iOS 26 floats the search field over the bottom of the sheet. Without
        // this the last saved workout can never be scrolled out from under it.
        .contentMargins(.bottom, Spacing.xxxl + Spacing.l, for: .scrollContent)
        .accessibilityIdentifier("start-workout-list")
    }

    @ViewBuilder
    func templateSection(
        _ title: LocalizedStringKey,
        items sectionItems: [BrowseItem],
        showsBuiltInBadge: Bool
    ) -> some View {
        if !sectionItems.isEmpty {
            Section {
                ForEach(sectionItems) { item in
                    templateRow(item, showsBuiltInBadge: showsBuiltInBadge)
                        .listRowBackground(Color.gymCard)
                }
            } header: {
                HStack {
                    Text(title)
                        .font(AppFont.captionBold)
                        .tracking(0.8)
                    Spacer()
                    // The count is what tells a lifter whether the section
                    // below is a shortlist or the whole seeded library.
                    Text(sectionItems.count.formatted())
                        .font(AppFont.captionSemiboldMonospaced)
                }
                .foregroundStyle(Color.gymSubduedText)
            }
        }
    }

    var emptyLibrarySection: some View {
        Section {
            ContentUnavailableView(
                "No saved workouts",
                systemImage: "rectangle.stack.badge.plus",
                description: Text("Build a personalized one above, or create a workout in Library.")
            )
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    var noMatchesSection: some View {
        Section {
            ContentUnavailableView {
                Label("No matching workouts", systemImage: AppIcon.search)
            } description: {
                Text("Try another search term, or clear the focus filter.")
            } actions: {
                Button("Clear filters") {
                    searchText = ""
                    selectedFocus = nil
                }
                .accessibilityIdentifier("clear-workout-filters")
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }
}

// MARK: - Entry cards

/// Lets a card own its own inset and corner radius inside a grouped list,
/// instead of inheriting the list's row chrome on top of the card's.
private struct FullBleedRow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowInsets(EdgeInsets(
                top: Spacing.s,
                leading: Spacing.l,
                bottom: Spacing.s,
                trailing: Spacing.l
            ))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

private extension SavedWorkoutTemplatePicker {
    /// The screen's hero. Filled `gymPrimaryDeep` rather than a gradient, for
    /// the same reason as the Today card: white body text clears 4.5:1 at every
    /// point of a flat fill and at only one end of any gradient across this hue.
    var generateCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                builderPresentation = BuilderPresentation(launchRequest: nil)
            } label: {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Label("PERSONALIZED", systemImage: AppIcon.recipeGenerate)
                        .font(AppFont.captionBold)
                        .tracking(0.8)

                    Text("Build today's workout")
                        .font(AppFont.titleMedium)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Tell it your goal, gear, and time. You review the workout before it starts.")
                        .font(AppFont.subheadline)
                        .fixedSize(horizontal: false, vertical: true)

                    // White on the blue card, not a second blue on blue: the
                    // filled-primary pill sat two shades from its own
                    // background and read as disabled chrome rather than as
                    // the screen's main action.
                    HStack(spacing: Spacing.s) {
                        Text("Build workout")
                            .font(AppFont.subheadlineBold)
                        Image(systemName: AppIcon.chevronRight)
                            .font(AppFont.captionBold)
                    }
                    .foregroundStyle(Color.gymPrimaryDeep)
                    .padding(.vertical, Spacing.md)
                    .padding(.horizontal, Spacing.xl)
                    .background(Color.white, in: Capsule())
                    .padding(.top, Spacing.xs)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.l)
            }
            .buttonStyle(.gymPress)
            .accessibilityIdentifier("build-personalized-workout-entry")
            .accessibilityHint("Builds an editable workout draft before you start.")

            quickStartRow
        }
        .background(Color.gymPrimaryDeep)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .shadow(color: Color.gymText.opacity(0.03), radius: 6, x: 0, y: 3)
    }

    /// Three equal pills, not a scroller. Horizontally scrolling three short
    /// labels clipped the third one against the card edge, which reads as a
    /// layout bug rather than as an invitation to swipe.
    var quickStartRow: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(Color.white.opacity(0.25))

            HStack(spacing: Spacing.s) {
                ForEach(Self.quickStarts) { quickStart in
                    Button {
                        builderPresentation = BuilderPresentation(
                            launchRequest: WorkoutGenerationLaunchRequest(request: quickStart.request)
                        )
                    } label: {
                        Text(quickStart.focus.title)
                            .font(AppFont.footnoteMedium)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: ComponentSize.iconChip)
                            .background(Color.white.opacity(0.18), in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("quick-build-\(quickStart.focus.rawValue)")
                    .accessibilityHint("Starts the builder with this focus filled in.")
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.m)
        }
    }

    /// Quiet under the generation hero, and the hero itself without it. Free
    /// training stays one tap away either way.
    @ViewBuilder
    func startEmptyCard(isHero: Bool) -> some View {
        if isHero {
            startEmptyHeroCard
        } else {
            startEmptyRowCard
        }
    }

    var startEmptyHeroCard: some View {
        Button(action: onStartEmpty) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Label("FREE WORKOUT", systemImage: AppIcon.play)
                    .font(AppFont.captionBold)
                    .tracking(0.8)
                    .foregroundStyle(Color.gymPrimary)

                Text("Start an empty workout")
                    .font(AppFont.titleMedium)
                    .foregroundStyle(Color.gymText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Add exercises as you go, or start from a saved workout below.")
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Spacing.s) {
                    Text("Start workout")
                        .font(AppFont.subheadlineBold)
                    Image(systemName: AppIcon.chevronRight)
                        .font(AppFont.captionBold)
                }
                .foregroundStyle(.white)
                .padding(.vertical, Spacing.md)
                .padding(.horizontal, Spacing.xl)
                .background(Color.gymPrimaryDeep, in: Capsule())
                .padding(.top, Spacing.xs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.l)
            .background {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .fill(Color.gymCard)
                    .stroke(Color.gymPrimary.opacity(0.16), lineWidth: 1.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .buttonStyle(.gymPress)
        .accessibilityIdentifier("start-empty-workout")
        .accessibilityHint("Starts a new session with no exercises.")
    }

    var startEmptyRowCard: some View {
        Button(action: onStartEmpty) {
            HStack(spacing: Spacing.m) {
                Image(systemName: AppIcon.plus)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymSecondary)
                    .frame(width: ComponentSize.iconChip, height: ComponentSize.iconChip)
                    .background(Color.gymSecondarySurface, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Start empty workout")
                        .font(AppFont.subheadlineBold)
                        .foregroundStyle(Color.gymText)
                    Text("Add exercises as you go")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                }

                Spacer(minLength: Spacing.s)

                Image(systemName: AppIcon.chevronRight)
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.gymSubduedText)
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.m)
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .background {
                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                    .fill(Color.gymCard)
                    .stroke(Color.gymBorder, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        }
        .buttonStyle(.gymPress)
        .accessibilityIdentifier("start-empty-workout")
        .accessibilityHint("Starts a new session with no exercises.")
    }
}

// MARK: - Focus filter

private extension SavedWorkoutTemplatePicker {
    /// A filter bar attached to the navigation bar, the way Mail and Files
    /// attach theirs: a hairline underneath so it reads as chrome belonging to
    /// the screen rather than as a row of pills floating over the content.
    var focusFilterStrip: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal) {
                HStack(spacing: Spacing.s) {
                    focusChip(title: Text("All"), icon: nil, isSelected: selectedFocus == nil, identifier: "all") {
                        selectedFocus = nil
                    }

                    ForEach(availableFocuses) { focus in
                        focusChip(
                            title: Text(focus.title),
                            icon: focus.icon,
                            isSelected: selectedFocus == focus,
                            identifier: focus.rawValue
                        ) {
                            // Tapping the active chip clears it: the strip is
                            // the only affordance on screen for undoing a
                            // filter that hid the workout the user wanted.
                            selectedFocus = selectedFocus == focus ? nil : focus
                        }
                    }
                }
                .padding(.vertical, Spacing.s)
            }
            .scrollIndicators(.hidden)
            // Margins rather than padding, so a chip scrolled to the edge stops
            // clear of it instead of being sliced by it.
            .contentMargins(.horizontal, Spacing.l, for: .scrollContent)

            Divider()
                .overlay(Color.gymBorder)
        }
        .background(Color.gymBackground)
    }

    func focusChip(
        title: Text,
        icon: String?,
        isSelected: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(AppFont.caption)
                }
                title
                    .font(AppFont.footnoteMedium)
            }
            .foregroundStyle(isSelected ? .white : Color.gymText)
            .padding(.horizontal, Spacing.m)
            .frame(minHeight: ComponentSize.iconChip)
            .background {
                Capsule()
                    .fill(isSelected ? Color.gymPrimaryDeep : Color.gymCard)
                    .stroke(isSelected ? Color.clear : Color.gymBorder, lineWidth: 1)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("workout-focus-\(identifier)")
        // Selection is carried by the trait, not only by the fill, so VoiceOver
        // and Increase Contrast users can tell which filter is active.
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Rows

private extension SavedWorkoutTemplatePicker {
    func templateRow(_ item: BrowseItem, showsBuiltInBadge: Bool) -> some View {
        let isStartable = item.summary.exerciseCount > 0
        // Assembled from two already-localized parts, so it is passed as a
        // plain string rather than as a "%@. %@" catalog key.
        let rowLabel = "\(item.template.name). \(item.summary.detailText)"

        return Button {
            onStartWorkout(item.template)
            dismiss()
        } label: {
            HStack(spacing: Spacing.m) {
                Image(systemName: item.summary.focus?.icon ?? AppIcon.workout)
                    .font(AppFont.footnoteMedium)
                    .foregroundStyle(Color.gymPrimary)
                    .frame(width: ComponentSize.iconChip, height: ComponentSize.iconChip)
                    .background(Color.gymPrimarySurface, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    // The name owns the full width. Pairing it inline with the
                    // "Starter" badge wrapped almost every seeded name onto a
                    // second line and left a ragged column of two-line titles.
                    Text(item.template.name)
                        .font(AppFont.subheadlineBold)
                        .foregroundStyle(Color.gymText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: Spacing.xs) {
                        if showsBuiltInBadge && item.template.isBuiltIn {
                            BuiltInBadge()
                        }

                        Text(item.summary.detailText)
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: Spacing.s)

                // Dropped at accessibility sizes: the whole row already starts
                // the workout, so the glyph is reinforcement, and the width it
                // costs is width the wrapped name and metadata need.
                if !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: AppIcon.play)
                        .font(AppFont.caption)
                        .foregroundStyle(isStartable ? Color.gymPrimary : Color.gymSubduedText)
                        .frame(width: 32, height: 32)
                        .background(isStartable ? Color.gymPrimarySurface : Color.gymRowSurface, in: Circle())
                }
            }
            .padding(.vertical, Spacing.xxs)
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isStartable)
        .accessibilityIdentifier("workout-template-\(item.template.name)")
        // Stated rather than left to the four child views, which read the name,
        // the badge, and the metadata line as separate stops.
        .accessibilityLabel(rowLabel)
        .accessibilityHint(isStartable
            ? "Starts a new session from this saved workout."
            : "Add an exercise before starting this workout.")
    }
}

// MARK: - Data

private extension SavedWorkoutTemplatePicker {
    struct BrowseItem: Identifiable {
        let template: WorkoutTemplate
        let summary: WorkoutTemplateSummary

        var id: PersistentIdentifier { template.persistentModelID }
    }

    var isGenerationOffered: Bool {
        FeatureFlags.current.isEnabled(.workoutGeneration)
    }

    var templateIdentity: [PersistentIdentifier] {
        templates.map(\.persistentModelID)
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

    var visibleItems: [BrowseItem] {
        browseItems.filter { item in
            guard selectedFocus == nil || item.summary.focus == selectedFocus else { return false }
            return SearchNormalization.matches(
                query: searchText,
                primaryName: item.template.name,
                aliases: item.summary.searchAliases
            )
        }
    }

    /// Only offered on the unfiltered list. While searching or filtering, the
    /// user has already said what they are looking for, and a recency section
    /// would answer a question they stopped asking.
    var recentItems: [BrowseItem] {
        guard searchText.isEmpty, selectedFocus == nil else { return [] }
        return visibleItems
            .compactMap { item in item.summary.lastPerformed.map { (item, $0) } }
            .sorted { $0.1 > $1.1 }
            .prefix(Self.recentTemplateLimit)
            .map(\.0)
    }

    /// Recents are removed from the sections below rather than repeated. A
    /// duplicated row is a second answer to the same question, and it also
    /// makes the row's accessibility identifier ambiguous.
    var remainingItems: [BrowseItem] {
        let recentIDs = Set(recentItems.map(\.id))
        return visibleItems.filter { !recentIDs.contains($0.id) }
    }

    var ownItems: [BrowseItem] {
        remainingItems.filter { !$0.template.isBuiltIn }
    }

    var starterItems: [BrowseItem] {
        remainingItems.filter { $0.template.isBuiltIn }
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

// MARK: - Focus presentation

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
