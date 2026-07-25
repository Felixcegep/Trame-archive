import SwiftData
import SwiftUI

struct MealTemplateLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MealTemplate.updatedAt, order: .reverse) private var templates: [MealTemplate]
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]
    @State private var isCreatingTemplate = false

    var body: some View {
        List {
            if currentTemplates.isEmpty {
                ContentUnavailableView("No recipes", systemImage: AppIcon.routine, description: Text("Create a simple recipe from foods in your library."))
            } else {
                ForEach(currentTemplates) { template in
                    NavigationLink {
                        MealTemplateDetailView(template: template)
                    } label: {
                        HStack(spacing: Spacing.m) {
                            recipeThumbnail(for: template)
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(template.name).font(AppFont.subheadlineSemibold).foregroundStyle(Color.gymText)
                                Text("\(template.items.count) foods · v\(template.version) · \(template.preparationState.displayName)").font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                            }
                        }
                    }
                    .accessibilityIdentifier("recipe-row-\(template.id)")
                    .swipeActions { Button(role: .destructive) { template.isArchived = true; template.updatedAt = .now; _ = modelContext.saveOrRollback() } label: { Label("Archive", systemImage: AppIcon.archive) } }
                }
            }
        }
        .scrollContentBackground(.hidden).background(Color.gymBackground)
        .navigationTitle("Recipes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button { isCreatingTemplate = true } label: { Label("New recipe", systemImage: AppIcon.plus) }.disabled(foods.filter { !$0.isArchived }.isEmpty).accessibilityIdentifier("create-meal-template") }
        }
        .sheet(isPresented: $isCreatingTemplate) { MealTemplateEditorView() }
    }

    @ViewBuilder
    private func recipeThumbnail(for template: MealTemplate) -> some View {
        RecipePhotoImage(identifier: template.photoIdentifier, content: { image in
            image
                .resizable().scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: Radius.small))
                .accessibilityHidden(true)
        }, placeholder: {
            Image(systemName: AppIcon.routine)
                .foregroundStyle(Color.gymSecondary)
                .frame(width: 44, height: 44)
                .background(Color.gymMutedSurface)
        })
    }

    private var currentTemplates: [MealTemplate] { templates.filter { $0.isCurrent && !$0.isArchived } }
}
