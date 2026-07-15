import SwiftData
import SwiftUI

struct FolderView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var workoutCollections: [WorkoutCollection]
    @Query private var workoutTemplates: [WorkoutTemplate]
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }) private var exerciseTemplates: [Exercise]
    @Query private var workoutPlans: [WorkoutPlan]

    @State private var activeSheet: FolderSheet?
    @State private var searchText = ""

    let onStartWorkout: (WorkoutTemplate) -> Void
    let onStartPlannedWorkout: (PlanRun, PlanWorkoutProgress) -> Void
    let onShowArchivedExercises: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                Text("Library")
                    .font(AppFont.displayMedium)
                    .foregroundStyle(FolderPalette.text)

                searchField

                if searchText.isEmpty {
                    browseSection
                } else {
                    globalResults
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.s)
            .padding(.bottom, 104)
        }
        .folderScreenStyle()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("New Workout Folder", systemImage: "folder.badge.plus") {
                        activeSheet = .workoutCollection
                    }
                    Button("New Workout", systemImage: "square.stack.3d.up.fill") {
                        activeSheet = .workoutTemplate
                    }
                    .accessibilityIdentifier("new-workout-template")
                    Button("New Program", systemImage: AppIcon.planAdd) {
                        activeSheet = .plan
                    }
                    .accessibilityIdentifier("new-plan")
                    Button("New Exercise", systemImage: "dumbbell.fill") {
                        activeSheet = .exercise
                    }
                    .accessibilityIdentifier("new-exercise")
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
                .accessibilityLabel("Create library item")
            }
        }
        .sheet(item: $activeSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .workoutCollection:
                    WorkoutCollectionFormView(availableTemplates: workoutTemplates) { name, templates in
                        modelContext.insert(WorkoutCollection(name: name, workoutTemplates: templates))
                        saveModelContext(modelContext)
                    }
                case .workoutTemplate:
                    WorkoutTemplateFormView(availableExercises: exerciseTemplates) { name, exercises in
                        modelContext.insert(WorkoutTemplate(name: name, exercises: exercises))
                        saveModelContext(modelContext)
                    }
                case .plan:
                    PlanFormView(templates: workoutTemplates) { plan in
                        modelContext.insert(plan)
                        saveModelContext(modelContext)
                    }
                case .exercise:
                    ExerciseFormView { exercise in
                        exercise.isCustom = true
                        modelContext.insert(exercise)
                        saveModelContext(modelContext)
                    }
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(FolderPalette.mutedText)
            TextField("Search your library", text: $searchText)
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("library-search")
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(FolderPalette.subtleText)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, Spacing.m)
        .frame(height: 46)
        .background(FolderPalette.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(FolderPalette.divider, lineWidth: 1)
        }
    }

    private var browseSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            LibrarySectionTitle("Browse")

            NavigationLink {
                WorkoutsBrowserView(onStartWorkout: onStartWorkout)
            } label: {
                LibraryCategoryRow(
                    title: "Workouts",
                    subtitle: "Saved sessions and workout folders",
                    count: workoutTemplates.count,
                    icon: "list.bullet.rectangle",
                    color: FolderPalette.primary,
                    surface: FolderPalette.primarySurface
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                PlansBrowserView(onStartPlannedWorkout: onStartPlannedWorkout)
            } label: {
                LibraryCategoryRow(
                    title: "Programs",
                    subtitle: "Scheduled multi-week training",
                    count: workoutPlans.filter { !$0.isArchived }.count,
                    icon: AppIcon.plan,
                    color: FolderPalette.accent,
                    surface: FolderPalette.accentSurface
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("plans-browser")

            NavigationLink {
                ExerciseBrowserView(onShowArchivedExercises: onShowArchivedExercises)
            } label: {
                LibraryCategoryRow(
                    title: "Exercises",
                    subtitle: "Your complete exercise catalogue",
                    count: exerciseTemplates.count,
                    icon: "dumbbell.fill",
                    color: FolderPalette.secondary,
                    surface: FolderPalette.secondarySurface
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var globalResults: some View {
        if matchingCollections.isEmpty && matchingTemplates.isEmpty && matchingPlans.isEmpty && matchingExercises.isEmpty {
            ContentUnavailableView.search(text: searchText)
                .frame(maxWidth: .infinity)
                .padding(.top, 56)
        } else {
            VStack(alignment: .leading, spacing: 18) {
            if !matchingCollections.isEmpty {
                searchResultsCard(title: "Workout folders") {
                    ForEach(matchingCollections) { collection in
                        NavigationLink {
                            WorkoutCollectionDetailView(collection: collection, onStartWorkout: onStartWorkout)
                        } label: {
                            RecentLibraryRow(
                                title: collection.name,
                                type: "FOLDER",
                                icon: "rectangle.stack",
                                color: FolderPalette.accent,
                                surface: FolderPalette.accentSurface
                            )
                        }
                    }
                }
            }
            if !matchingTemplates.isEmpty {
                searchResultsCard(title: "Workouts") {
                    ForEach(matchingTemplates, id: \.self) { template in
                        NavigationLink {
                            WorkoutTemplateDetailView(template: template, onStartWorkout: onStartWorkout)
                        } label: {
                            RecentLibraryRow(
                                title: template.name,
                                type: "WORKOUT",
                                icon: "list.bullet.rectangle",
                                color: FolderPalette.primary,
                                surface: FolderPalette.primarySurface
                            )
                        }
                    }
                }
            }
            if !matchingPlans.isEmpty {
                searchResultsCard(title: "Programs") {
                    ForEach(matchingPlans) { plan in
                        NavigationLink {
                            PlanDetailView(plan: plan, onStartPlannedWorkout: onStartPlannedWorkout)
                        } label: {
                            RecentLibraryRow(
                                title: plan.name,
                                type: "PROGRAM",
                                icon: AppIcon.plan,
                                color: FolderPalette.accent,
                                surface: FolderPalette.accentSurface
                            )
                        }
                    }
                }
            }
            if !matchingExercises.isEmpty {
                searchResultsCard(title: "Exercises") {
                    ForEach(matchingExercises, id: \.self) { exercise in
                        NavigationLink {
                            ExerciseView(exercise: exercise)
                        } label: {
                            RecentLibraryRow(
                                title: exercise.name,
                                type: "EXERCISE",
                                icon: "dumbbell.fill",
                                color: FolderPalette.secondary,
                                surface: FolderPalette.secondarySurface
                            )
                        }
                    }
                }
            }
            }
        }
    }

    private func searchResultsCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            LibrarySectionTitle(title)
            content()
        }
    }

    private var matchingCollections: [WorkoutCollection] {
        workoutCollections.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var matchingTemplates: [WorkoutTemplate] {
        workoutTemplates.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var matchingExercises: [Exercise] {
        exerciseTemplates.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var matchingPlans: [WorkoutPlan] {
        workoutPlans.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}

private struct WorkoutsBrowserView: View {
    @Query private var collections: [WorkoutCollection]
    @Query private var templates: [WorkoutTemplate]
    @State private var searchText = ""

    let onStartWorkout: (WorkoutTemplate) -> Void

    var body: some View {
        LibraryBrowserList(title: "Workouts", searchText: $searchText) {
            LibraryListSectionHeader(title: "Folders", count: filteredCollections.count)
            ForEach(filteredCollections) { collection in
                NavigationLink {
                    WorkoutCollectionDetailView(collection: collection, onStartWorkout: onStartWorkout)
                } label: {
                    LibraryItemRow(
                        title: collection.name,
                        subtitle: workoutCountText(collection.workoutTemplates.count),
                        icon: "rectangle.stack",
                        color: FolderPalette.accent,
                        surface: FolderPalette.accentSurface
                    )
                }
            }

            LibraryListSectionHeader(title: "All workouts", count: filteredTemplates.count)
            ForEach(filteredTemplates, id: \.self) { template in
                NavigationLink {
                    WorkoutTemplateDetailView(template: template, onStartWorkout: onStartWorkout)
                } label: {
                    LibraryItemRow(
                        title: template.name,
                        subtitle: "\(template.exercises.count) exercises",
                        icon: "list.bullet.rectangle",
                        color: FolderPalette.primary,
                        surface: FolderPalette.primarySurface
                    )
                }
            }
        }
    }

    private var filteredCollections: [WorkoutCollection] {
        collections
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var filteredTemplates: [WorkoutTemplate] {
        templates
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func workoutCountText(_ count: Int) -> String {
        count == 1 ? "1 workout" : "\(count) workouts"
    }
}

enum LibraryRoute: Hashable {
    case archivedExercises
}

private struct ExerciseRowSnapshot: Identifiable, Equatable {
    let id: PersistentIdentifier
    let name: String
    let subtitle: String
    let isCustom: Bool
    let exercise: Exercise

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.subtitle == rhs.subtitle
            && lhs.isCustom == rhs.isCustom
    }
}

private struct ExerciseBrowserView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }) private var exercises: [Exercise]
    let onShowArchivedExercises: () -> Void
    @State private var searchText = ""
    @State private var filter = ExerciseFilterState()
    @State private var sortOrder: ExerciseSortOrder = .nameAscending
    @State private var rows: [ExerciseRowSnapshot] = []

    var body: some View {
        LibraryBrowserList(title: "Exercises", searchText: $searchText) {
            ExerciseFilterControls(filter: $filter, resultCount: rows.count)

            Menu {
                Picker("Sort", selection: $sortOrder) {
                    ForEach(ExerciseSortOrder.allCases) { order in
                        Text(LocalizedStringKey(order.title)).tag(order)
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(FolderPalette.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onShowArchivedExercises()
            } label: {
                LibraryItemRow(
                    title: "Hidden Exercises",
                    subtitle: "Restore anything you've hidden",
                    icon: AppIcon.archive,
                    color: FolderPalette.accent,
                    surface: FolderPalette.accentSurface
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("hidden-exercises")

            ForEach(rows) { row in
                NavigationLink {
                    ExerciseView(exercise: row.exercise)
                } label: {
                    LibraryItemRow(
                        title: row.name,
                        subtitle: row.subtitle,
                        icon: "dumbbell.fill",
                        color: FolderPalette.secondary,
                        surface: FolderPalette.secondarySurface
                    )
                }
                .accessibilityIdentifier("exercise-row-\(row.name)")
                .contextMenu {
                    if row.isCustom {
                        Button(role: .destructive) {
                            deleteExercise(row.exercise)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } else {
                        Button {
                            hideExercise(row.exercise)
                        } label: {
                            Label("Hide", systemImage: AppIcon.archive)
                        }
                    }
                }
            }
        }
        .onAppear {
            recomputeRows()
        }
        .onChange(of: searchText) { _, _ in
            recomputeRows()
        }
        .onChange(of: filter) { _, _ in
            recomputeRows()
        }
        .onChange(of: sortOrder) { _, _ in
            recomputeRows()
        }
        .onChange(of: exercises.count) { _, _ in
            recomputeRows()
        }
    }

    private func recomputeRows() {
        let nextRows = exercises
            .filter { filter.matches($0, searchText: searchText) }
            .sorted { first, second in
                switch sortOrder {
                case .nameAscending:
                    first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
                case .nameDescending:
                    first.name.localizedCaseInsensitiveCompare(second.name) == .orderedDescending
                }
            }
            .map {
                ExerciseRowSnapshot(
                    id: $0.persistentModelID,
                    name: $0.name,
                    subtitle: $0.subtitle,
                    isCustom: $0.isCustom,
                    exercise: $0
                )
            }

        if nextRows != rows {
            rows = nextRows
        }
    }

    private func hideExercise(_ exercise: Exercise) {
        do {
            try ExerciseArchiveService.hideOrDelete(exercise, using: modelContext)
        } catch {
            print("Failed to hide exercise: \(error)")
        }
    }

    private func deleteExercise(_ exercise: Exercise) {
        do {
            try ExerciseArchiveService.hideOrDelete(exercise, using: modelContext)
        } catch {
            print("Failed to delete exercise: \(error)")
        }
    }

}

struct ArchivedExercisesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Exercise> { $0.isArchived }) private var exercises: [Exercise]
    @State private var searchText = ""

    private var filteredExercises: [Exercise] {
        exercises
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        LibraryBrowserList(title: "Hidden Exercises", searchText: $searchText) {
            Text("Hidden exercises stay out of workout and program pickers. History remains unchanged.")
                .font(AppFont.subheadline)
                .foregroundStyle(FolderPalette.mutedText)
                .padding(.horizontal, Spacing.xxs)

            if filteredExercises.isEmpty {
                ContentUnavailableView(
                    "No hidden exercises",
                    systemImage: AppIcon.archive,
                    description: Text(searchText.isEmpty ? "Exercises you hide or archive will appear here." : "Try a different search.")
                )
            } else {
                LibraryListSectionHeader(title: "Hidden Exercises", count: filteredExercises.count)
                ForEach(filteredExercises, id: \.self) { exercise in
                    HStack(spacing: Spacing.m) {
                        LibraryItemRow(
                            title: exercise.name,
                            subtitle: exercise.isCustom ? "Custom exercise" : "Built-in exercise",
                            icon: "dumbbell.fill",
                            color: FolderPalette.secondary,
                            surface: FolderPalette.secondarySurface,
                            showsCard: false,
                            showsChevron: false
                        )
                        Button("Restore") {
                            restore(exercise)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .accessibilityIdentifier("restore-exercise-\(exercise.name)")
                        .padding(.trailing, Spacing.l - 2)
                    }
                    .background {
                        RoundedRectangle(cornerRadius: Radius.large)
                            .fill(FolderPalette.card)
                            .stroke(FolderPalette.divider, lineWidth: 1)
                    }
                }
            }
        }
    }

    private func restore(_ exercise: Exercise) {
        do {
            try ExerciseArchiveService.restore(exercise, using: modelContext)
        } catch {
            print("Failed to restore exercise: \(error)")
        }
    }
}

private enum ExerciseSortOrder: String, CaseIterable, Identifiable {
    case nameAscending
    case nameDescending

    var id: Self { self }

    var title: String {
        switch self {
        case .nameAscending:
            "Name (A-Z)"
        case .nameDescending:
            "Name (Z-A)"
        }
    }
}

private struct LibraryBrowserList<Content: View>: View {
    let title: String
    @Binding var searchText: String
    @ViewBuilder let content: Content

    init(title: String, searchText: Binding<String>, @ViewBuilder content: () -> Content) {
        self.title = title
        _searchText = searchText
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.s) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(FolderPalette.mutedText)
                    TextField(String(localized: "Search \(NSLocalizedString(title.lowercased(), comment: ""))"), text: $searchText)
                }
                .padding(.horizontal, Spacing.m)
                .frame(height: 46)
                .background(FolderPalette.card, in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: Spacing.md) {
                    content
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.l)
            .padding(.bottom, 92)
        }
        .folderScreenStyle()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LibraryCategoryRow: View {
    let title: String
    let subtitle: String
    let count: Int
    let icon: String
    let color: Color
    let surface: Color

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 42, height: 42)
                .background(surface, in: RoundedRectangle(cornerRadius: Radius.medium))
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title).font(.body.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(FolderPalette.mutedText)
            }
            Spacer()
            Text("\(count)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(FolderPalette.mutedText)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(FolderPalette.subtleText)
        }
        .padding(Spacing.l - 2)
        .background(FolderPalette.card, in: RoundedRectangle(cornerRadius: Radius.large))
        .overlay { RoundedRectangle(cornerRadius: Radius.large).stroke(FolderPalette.divider, lineWidth: 1) }
    }
}

private struct LibraryItemRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let surface: Color
    var showsCard = true
    var showsChevron = true

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(surface, in: RoundedRectangle(cornerRadius: Radius.medium))
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(FolderPalette.text)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Text(subtitle).font(.caption).foregroundStyle(FolderPalette.mutedText).lineLimit(1)
            }
            Spacer()
            if showsChevron {
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(FolderPalette.subtleText)
            }
        }
        .padding(.horizontal, Spacing.l - 2)
        .padding(.vertical, showsCard ? Spacing.l - 2 : Spacing.md)
        .background {
            if showsCard {
                RoundedRectangle(cornerRadius: Radius.large)
                    .fill(FolderPalette.card)
                    .stroke(FolderPalette.divider, lineWidth: 1)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct LibraryListSectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(AppFont.captionBold)
                .tracking(0.8)
                .foregroundStyle(FolderPalette.mutedText)
            Spacer()
            Text("\(count)")
                .font(AppFont.caption)
                .monospacedDigit()
                .foregroundStyle(FolderPalette.subtleText)
        }
        .padding(.horizontal, Spacing.xxs)
        .padding(.top, Spacing.m)
    }
}

private struct RecentLibraryRow: View {
    let title: String
    let type: LocalizedStringKey
    let icon: String
    let color: Color
    let surface: Color

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: icon)
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(surface, in: RoundedRectangle(cornerRadius: Radius.medium))

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(FolderPalette.text)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Text(type)
                    .font(AppFont.caption2Bold)
                    .tracking(0.5)
                    .foregroundStyle(color)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(AppFont.captionBold)
                .foregroundStyle(FolderPalette.subtleText)
        }
        .padding(.horizontal, Spacing.l - 2)
        .padding(.vertical, Spacing.m)
        .background {
            RoundedRectangle(cornerRadius: Radius.large)
                .fill(FolderPalette.card)
                .stroke(FolderPalette.divider, lineWidth: 1)
        }
        .contentShape(Rectangle())
    }
}


private struct LibrarySectionTitle: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title.uppercased())
            .font(AppFont.captionBold)
            .tracking(0.8)
            .foregroundStyle(FolderPalette.mutedText)
    }
}

private enum FolderSheet: String, Identifiable {
    case workoutCollection
    case workoutTemplate
    case plan
    case exercise

    var id: String { rawValue }
}
