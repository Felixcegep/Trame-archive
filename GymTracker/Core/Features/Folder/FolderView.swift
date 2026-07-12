import SwiftData
import SwiftUI

struct FolderView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var workoutCollections: [WorkoutCollection]
    @Query private var workoutTemplates: [WorkoutTemplate]
    @Query(filter: #Predicate<ExerciceTemplate> { !$0.isArchived }) private var exerciceTemplates: [ExerciceTemplate]
    @Query private var workoutPlans: [WorkoutPlan]

    @State private var activeSheet: FolderSheet?
    @State private var searchText = ""

    let onStartWorkout: (WorkoutTemplate) -> Void
    let onStartPlannedWorkout: (PlanRun, PlanWorkoutProgress) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Library")
                    .font(AppFont.displayMedium)
                    .foregroundStyle(FolderPalette.text)

                searchField

                if searchText.isEmpty {
                    browseSection
                    quickAccessSection
                } else {
                    globalResults
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 104)
        }
        .folderScreenStyle()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("New Collection", systemImage: "folder.badge.plus") {
                        activeSheet = .workoutCollection
                    }
                    Button("New Workout Template", systemImage: "square.stack.3d.up.fill") {
                        activeSheet = .workoutTemplate
                    }
                    .accessibilityIdentifier("new-workout-template")
                    Button("New Plan", systemImage: AppIcon.planAdd) {
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
                    WorkoutTemplateFormView(availableExercises: exerciceTemplates) { name, exercises in
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
        HStack(spacing: 9) {
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
        .padding(.horizontal, 13)
        .frame(height: 46)
        .background(FolderPalette.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(FolderPalette.divider, lineWidth: 1)
        }
    }

    private var browseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            LibrarySectionTitle("Browse")

            NavigationLink {
                WorkoutCollectionsBrowserView(onStartWorkout: onStartWorkout)
            } label: {
                LibraryCategoryRow(
                    title: "Collections",
                    subtitle: "Organize reusable workout templates",
                    count: workoutCollections.count,
                    icon: "rectangle.stack",
                    color: FolderPalette.accent,
                    surface: FolderPalette.accentSurface
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                WorkoutTemplatesBrowserView(onStartWorkout: onStartWorkout)
            } label: {
                LibraryCategoryRow(
                    title: "Workout Templates",
                    subtitle: "Reusable individual workouts",
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
                    title: "Plans",
                    subtitle: "Multi-week training schedules",
                    count: workoutPlans.filter { !$0.isArchived }.count,
                    icon: AppIcon.plan,
                    color: FolderPalette.accent,
                    surface: FolderPalette.accentSurface
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("plans-browser")

            NavigationLink {
                ExerciseBrowserView()
            } label: {
                LibraryCategoryRow(
                    title: "Exercises",
                    subtitle: "Your complete exercise catalogue",
                    count: exerciceTemplates.count,
                    icon: "dumbbell.fill",
                    color: FolderPalette.secondary,
                    surface: FolderPalette.secondarySurface
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var quickAccessSection: some View {
        let collection = workoutCollections.first
        let template = workoutTemplates.first
        let exercise = exerciceTemplates.first

        if collection != nil || template != nil || exercise != nil {
            VStack(alignment: .leading, spacing: 10) {
                LibrarySectionTitle("Quick access")

                VStack(spacing: 0) {
                    if let collection {
                        NavigationLink {
                            WorkoutCollectionDetailView(collection: collection, onStartWorkout: onStartWorkout)
                        } label: {
                            RecentLibraryRow(
                                title: collection.name,
                                type: "COLLECTION",
                                icon: "rectangle.stack",
                                color: FolderPalette.accent,
                                surface: FolderPalette.accentSurface
                            )
                        }
                    }
                    if let template {
                        if collection != nil { quickAccessDivider }
                        NavigationLink {
                            WorkoutTemplateDetailView(template: template, onStartWorkout: onStartWorkout)
                        } label: {
                            RecentLibraryRow(
                                title: template.name,
                                type: "TEMPLATE",
                                icon: "list.bullet.rectangle",
                                color: FolderPalette.primary,
                                surface: FolderPalette.primarySurface
                            )
                        }
                    }
                    if let exercise {
                        if collection != nil || template != nil { quickAccessDivider }
                        NavigationLink {
                            ExerciceView(exercice: exercise)
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
                .background(FolderPalette.card, in: RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(FolderPalette.divider, lineWidth: 1)
                }
            }
        }
    }

    private var quickAccessDivider: some View {
        Divider()
            .overlay(FolderPalette.divider)
            .padding(.leading, 60)
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
                searchResultsCard(title: "Collections") {
                    ForEach(matchingCollections) { collection in
                        NavigationLink {
                            WorkoutCollectionDetailView(collection: collection, onStartWorkout: onStartWorkout)
                        } label: {
                            RecentLibraryRow(
                                title: collection.name,
                                type: "COLLECTION",
                                icon: "rectangle.stack",
                                color: FolderPalette.accent,
                                surface: FolderPalette.accentSurface
                            )
                        }
                    }
                }
            }
            if !matchingTemplates.isEmpty {
                searchResultsCard(title: "Templates") {
                    ForEach(matchingTemplates, id: \.self) { template in
                        NavigationLink {
                            WorkoutTemplateDetailView(template: template, onStartWorkout: onStartWorkout)
                        } label: {
                            RecentLibraryRow(
                                title: template.name,
                                type: "TEMPLATE",
                                icon: "list.bullet.rectangle",
                                color: FolderPalette.primary,
                                surface: FolderPalette.primarySurface
                            )
                        }
                    }
                }
            }
            if !matchingPlans.isEmpty {
                searchResultsCard(title: "Plans") {
                    ForEach(matchingPlans) { plan in
                        NavigationLink {
                            PlanDetailView(plan: plan, onStartPlannedWorkout: onStartPlannedWorkout)
                        } label: {
                            RecentLibraryRow(
                                title: plan.name,
                                type: "PLAN",
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
                            ExerciceView(exercice: exercise)
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
        VStack(alignment: .leading, spacing: 8) {
            LibrarySectionTitle(title)
            VStack(spacing: 0) {
                content()
            }
            .background(FolderPalette.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(FolderPalette.divider, lineWidth: 1)
            }
        }
    }

    private var matchingCollections: [WorkoutCollection] {
        workoutCollections.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var matchingTemplates: [WorkoutTemplate] {
        workoutTemplates.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var matchingExercises: [ExerciceTemplate] {
        exerciceTemplates.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var matchingPlans: [WorkoutPlan] {
        workoutPlans.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}

private struct WorkoutCollectionsBrowserView: View {
    @Query private var collections: [WorkoutCollection]
    @State private var searchText = ""

    let onStartWorkout: (WorkoutTemplate) -> Void

    var body: some View {
        LibraryBrowserList(title: "Collections", searchText: $searchText) {
            ForEach(filteredCollections) { collection in
                NavigationLink {
                    WorkoutCollectionDetailView(collection: collection, onStartWorkout: onStartWorkout)
                } label: {
                    LibraryItemRow(
                        title: collection.name,
                        subtitle: "\(collection.workoutTemplates.count) templates",
                        icon: "rectangle.stack",
                        color: FolderPalette.accent,
                        surface: FolderPalette.accentSurface
                    )
                }
            }
        }
    }

    private var filteredCollections: [WorkoutCollection] {
        collections.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}

private struct WorkoutTemplatesBrowserView: View {
    @Query private var templates: [WorkoutTemplate]
    @State private var searchText = ""

    let onStartWorkout: (WorkoutTemplate) -> Void

    var body: some View {
        LibraryBrowserList(title: "Workout Templates", searchText: $searchText) {
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

    private var filteredTemplates: [WorkoutTemplate] {
        templates.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}

private struct ExerciseBrowserView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<ExerciceTemplate> { !$0.isArchived }) private var exercises: [ExerciceTemplate]
    @State private var searchText = ""
    @State private var filter = ExerciseFilterState()
    @State private var sortOrder: ExerciseSortOrder = .nameAscending

    var body: some View {
        LibraryBrowserList(title: "Exercises", searchText: $searchText) {
            ExerciseFilterControls(filter: $filter, resultCount: filteredExercises.count)

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

            ForEach(filteredExercises, id: \.self) { exercise in
                NavigationLink {
                    ExerciceView(exercice: exercise)
                } label: {
                    LibraryItemRow(
                        title: exercise.name,
                        subtitle: exercise.subtitle,
                        icon: "dumbbell.fill",
                        color: FolderPalette.secondary,
                        surface: FolderPalette.secondarySurface
                    )
                }
                .swipeActions(allowsFullSwipe: true) {
                    if exercise.isCustom {
                        Button(role: .destructive) {
                            deleteOrArchiveExercise(exercise)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private var filteredExercises: [ExerciceTemplate] {
        exercises.filter { exercise in
            filter.matches(exercise, searchText: searchText)
        }
        .sorted { first, second in
            switch sortOrder {
            case .nameAscending:
                first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
            case .nameDescending:
                first.name.localizedCaseInsensitiveCompare(second.name) == .orderedDescending
            }
        }
    }

    private func deleteOrArchiveExercise(_ exercise: ExerciceTemplate) {
        do {
            let entries = try modelContext.fetch(FetchDescriptor<ExerciceEntry>())
            let hasEntryReference = entries.contains { $0.exercice.id == exercise.id }

            let templateExercises = try modelContext.fetch(FetchDescriptor<TemplateExercise>())
            let hasTemplateReference = templateExercises.contains { $0.exercise.id == exercise.id }

            let plannedExercises = try modelContext.fetch(FetchDescriptor<PlannedExercise>())
            let hasPlanReference = plannedExercises.contains { $0.exercise.id == exercise.id }

            if hasEntryReference || hasTemplateReference || hasPlanReference {
                exercise.isArchived = true
            } else {
                modelContext.delete(exercise)
            }
            try modelContext.save()
        } catch {
            print("Failed to delete/archive exercise: \(error)")
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
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(FolderPalette.mutedText)
                    TextField(String(localized: "Search \(NSLocalizedString(title.lowercased(), comment: ""))"), text: $searchText)
                }
                .padding(.horizontal, 13)
                .frame(height: 44)
                .background(FolderPalette.card, in: RoundedRectangle(cornerRadius: 14))

                VStack(spacing: 0) {
                    content
                }
                .background(FolderPalette.card, in: RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(FolderPalette.divider, lineWidth: 1)
                }
            }
            .padding(16)
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
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 42, height: 42)
                .background(surface, in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 3) {
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
        .padding(14)
        .background(FolderPalette.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(FolderPalette.divider, lineWidth: 1) }
    }
}

private struct LibraryItemRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let surface: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(surface, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.weight(.medium)).foregroundStyle(FolderPalette.text)
                Text(subtitle).font(.caption).foregroundStyle(FolderPalette.mutedText).lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(FolderPalette.subtleText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
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
