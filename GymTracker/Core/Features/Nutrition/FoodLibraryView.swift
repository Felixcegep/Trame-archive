import SwiftData
import SwiftUI

struct FoodLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]
    @State private var searchText = ""
    @State private var showsArchived = false
    @State private var editingFood: FoodItem?
    @State private var selectedFood: FoodItem?
    @State private var isCreatingFood = false

    var body: some View {
        // Search changes invalidate the body; keep the filtered catalogue for
        // the empty-state check and rows in one render projection instead of
        // scanning every food twice per keystroke.
        let visibleFoods = self.visibleFoods

        List {
            if visibleFoods.isEmpty {
                ContentUnavailableView(showsArchived ? "No archived foods" : "No foods found", systemImage: AppIcon.nutrition, description: Text(showsArchived ? "Archived foods stay available to historical meals." : "Create a custom food to log it offline."))
            } else {
                ForEach(visibleFoods) { food in
                    Button {
                        if food.isArchived {
                            editingFood = food
                        } else {
                            selectedFood = food
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            HStack {
                                Text(food.name).font(AppFont.subheadlineSemibold).foregroundStyle(Color.gymText)
                                if food.isFavorite { Image(systemName: AppIcon.favoriteFilled).foregroundStyle(Color.gymAccent) }
                            }
                            Text("\(foodMacroDescription(food)) · \(food.confidence.displayName)")
                                .font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                        }
                    }
                    .accessibilityHint(food.isArchived ? "Edit or restore this archived food" : "Log this food")
                    .accessibilityIdentifier("food-row-\(food.id)")
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            food.isFavorite.toggle()
                            food.updatedAt = .now
                            _ = modelContext.saveOrRollback()
                        } label: {
                            Label(food.isFavorite ? "Remove favorite" : "Favorite", systemImage: food.isFavorite ? AppIcon.favoriteRemove : AppIcon.favorite)
                        }
                        .tint(Color.trameAttention)
                        Button { editingFood = food } label: { Label("Edit", systemImage: AppIcon.edit) }
                            .tint(Color.gymAccent)
                        Button(role: food.isArchived ? nil : .destructive) {
                            food.isArchived.toggle()
                            food.updatedAt = .now
                            _ = modelContext.saveOrRollback()
                        } label: { Label(food.isArchived ? "Restore" : "Archive", systemImage: food.isArchived ? AppIcon.restore : AppIcon.archive) }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .listStyle(.plain)
        .navigationTitle("Food library")
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search foods"
        )
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(showsArchived ? "Current" : "Archived") { showsArchived.toggle() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { isCreatingFood = true } label: { Label("New food", systemImage: AppIcon.plus) }
                    .accessibilityIdentifier("create-food")
            }
        }
        .sheet(isPresented: $isCreatingFood) { FoodEditorView() }
        .sheet(item: $editingFood) { FoodEditorView(food: $0) }
        .sheet(item: $selectedFood) { FoodQuickLogView(food: $0) }
    }

    private var visibleFoods: [FoodItem] {
        foods.filter { food in
            guard food.isArchived == showsArchived else { return false }
            guard !searchText.isEmpty else { return true }
            var extraTerms: [String] = []
            if let cat = food.categoryName { extraTerms.append(cat) }
            extraTerms.append(contentsOf: food.searchAliases)
            return SearchNormalization.matches(
                query: searchText,
                primaryName: food.name,
                alternateName: food.frenchName,
                aliases: extraTerms
            )
        }
    }

    private func foodMacroDescription(_ food: FoodItem) -> String {
        let energy = food.calories.map { "\(FoodLibraryService.format($0)) kcal" } ?? "Calories unknown"
        let protein = food.proteinGrams.map { "\(FoodLibraryService.format($0))g protein" } ?? "protein unknown"
        return "\(energy) · \(protein)"
    }
}
