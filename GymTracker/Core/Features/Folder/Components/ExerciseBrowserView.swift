import SwiftData
import SwiftUI

struct ExerciseRowSnapshot: Identifiable, Equatable {
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

enum ExerciseSortOrder: String, CaseIterable, Identifiable {
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

struct ExerciseBrowserView: View {
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
                    .foregroundStyle(Color.gymPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onShowArchivedExercises()
            } label: {
                LibraryItemRow(
                    title: "Hidden Exercises",
                    subtitle: "Restore anything you've hidden",
                    icon: AppIcon.archive,
                    color: Color.gymAccent,
                    surface: Color.gymAccentSurface
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
                        color: Color.gymSecondary,
                        surface: Color.gymSecondarySurface
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
