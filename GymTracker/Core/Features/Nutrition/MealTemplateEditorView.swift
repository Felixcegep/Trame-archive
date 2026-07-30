import PhotosUI
import SwiftData
import SwiftUI
import UIKit

private enum RecipeGenerationNotice: Equatable {
    case draftGenerated
    case noMatches
    case partialMatch
    case generationFailed
    case unclearImage
    case unsafeImage
}

private enum RecipeField: Hashable {
    case name
    case yield
}

/// Identifies which ingredient row the ingredient editor sheet is editing.
private struct IngredientEditContext: Identifiable {
    let id: Int
}

struct MealTemplateEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]
    let template: MealTemplate?
    let generator: RecipeDraftGenerator

    @State private var name = ""
    @State private var preparation: FoodPreparationState = .cooked
    @State private var recipeYield: Double?
    @State private var yieldEditingText: String?
    @State private var selected: [(FoodItem, UUID?, Double)] = []
    @State private var errorMessage: String?
    @FocusState private var focusedField: RecipeField?

    // Persisted recipe photo (recognition thumbnail), distinct from the
    // transient generation photo below.
    @State private var recipePhotoIdentifier: String?
    @State private var pendingRecipePhotoData: Data?
    @State private var recipePhotoPreview: UIImage?
    @State private var recipePhotoPickerItem: PhotosPickerItem?
    @State private var isShowingFoodPicker = false
    @State private var editingIngredient: IngredientEditContext?

    @State private var availability: RecipeGenerationAvailabilityStatus = .unsupportedDevice
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var selectedImagePreview: UIImage?
    @State private var isGenerating = false
    @State private var isSaving = false
    @State private var generationTask: Task<Void, Never>?
    @State private var hasGeneratedDraft = false
    @State private var lastAppliedDraftSnapshot: [UUID: Double]?
    @State private var pendingReplaceConfirmation = false
    @State private var generationNotice: RecipeGenerationNotice?
    @State private var draftGeneratedFeedbackTrigger = false

    init(template: MealTemplate? = nil, generator: RecipeDraftGenerator = MealTemplateEditorView.defaultGenerator()) {
        self.template = template
        self.generator = generator
    }

    private static func defaultGenerator() -> RecipeDraftGenerator {
        if let scripted = UITestRecipeDraftGenerationResult.launchOverride {
            return ScriptedRecipeDraftGenerator(result: scripted)
        }
        return FoundationRecipeDraftGenerator()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe") {
                    TextField("Name", text: $name).focused($focusedField, equals: .name)
                    generationControls
                    Picker("Preparation", selection: $preparation) { ForEach(FoodPreparationState.allCases, id: \.self) { Text($0.displayName).tag($0) } }
                    TextField("Recipe yield g (optional)", text: yieldTextBinding, prompt: Text("—"))
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .yield)
                        .accessibilityIdentifier("recipe-yield-field")
                    Text("Total weight after cooking. This lets you log part of the recipe in grams.")
                        .font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                }
                recipePhotoSection
                Section("Foods") {
                    if let generationNotice {
                        noticeText(generationNotice)
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                            .accessibilityIdentifier("recipe-generation-notice")
                    }
                    if selected.isEmpty {
                        Text("Add foods from your library to build this recipe.")
                            .font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                    }
                    ForEach(Array(selected.enumerated()), id: \.element.0.id) { index, item in
                        Button {
                            editingIngredient = IngredientEditContext(id: index)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text(item.0.name).foregroundStyle(Color.gymText)
                                    Text(ingredientAmountText(item)).font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                                }
                                Spacer()
                                Text(ingredientCaloriesText(item)).font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                            }
                        }
                        .accessibilityLabel("\(item.0.name), \(ingredientAmountText(item))")
                        .accessibilityHint("Edit amount or remove")
                        .accessibilityIdentifier("recipe-ingredient-\(item.0.id)")
                    }
                    .onDelete { selected.remove(atOffsets: $0) }
                    Button { isShowingFoodPicker = true } label: { Label("Add foods", systemImage: AppIcon.plus) }
                        .accessibilityIdentifier("recipe-add-foods")
                }
            }
            .scrollContentBackground(.hidden).background(Color.gymBackground)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(template == nil ? "New recipe" : "Revise recipe")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                load()
                availability = RecipeGenerationAvailability.status()
            }
            .onDisappear { generationTask?.cancel() }
            .task(id: recipePhotoIdentifier) {
                guard pendingRecipePhotoData == nil else { return }
                recipePhotoPreview = await RecipePhotoStore.loadImageAsync(recipePhotoIdentifier)
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                guard let newValue else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self) {
                        guard !Task.isCancelled else { return }
                        selectedImageData = data
                        selectedImagePreview = await RecipePhotoStore.decodeImageAsync(data)
                    }
                }
            }
            .onChange(of: recipePhotoPickerItem) { _, newValue in
                guard let newValue else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self) {
                        guard !Task.isCancelled else { return }
                        pendingRecipePhotoData = data
                        recipePhotoPreview = await RecipePhotoStore.decodeImageAsync(data)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        generationTask?.cancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(isGenerating || isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selected.isEmpty)
                        .accessibilityIdentifier("save-meal-template")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Button { focusedField = .name } label: { Label("Previous field", systemImage: "chevron.left") }
                        .disabled(focusedField == .name)
                    Button { focusedField = .yield } label: { Label("Next field", systemImage: "chevron.right") }
                        .disabled(focusedField == .yield)
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .sheet(isPresented: $isShowingFoodPicker) {
                FoodPickerSheet(existingSelection: Set(selected.map { $0.0.id })) { additions in
                    for food in additions {
                        selected.append((food, FoodLibraryService.defaultPortion(for: food).id, 1))
                    }
                }
            }
            .sheet(item: $editingIngredient) { context in
                if selected.indices.contains(context.id) {
                    IngredientEditorSheet(
                        food: selected[context.id].0,
                        servingID: Binding(get: { selected[context.id].1 }, set: { selected[context.id].1 = $0 }),
                        quantity: Binding(get: { selected[context.id].2 }, set: { selected[context.id].2 = $0 }),
                        onRemove: { selected.remove(at: context.id) }
                    )
                }
            }
            .alert("Couldn’t save recipe", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK", role: .cancel) { errorMessage = nil } } message: { Text(errorMessage ?? "Try again.") }
            .alert("Replace the current draft?", isPresented: $pendingReplaceConfirmation) {
                Button("Replace", role: .destructive) { runGeneration() }
                Button("Keep editing", role: .cancel) {}
            }
            .sensoryFeedback(.success, trigger: draftGeneratedFeedbackTrigger) { _, newValue in newValue }
        }
    }

    // MARK: - Recipe photo

    @ViewBuilder
    private var recipePhotoSection: some View {
        Section("Photo") {
            if let image = recipePhotoPreview {
                HStack(spacing: Spacing.m) {
                    Image(uiImage: image)
                        .resizable().scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.small))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        PhotosPicker(selection: $recipePhotoPickerItem, matching: .images) { Text("Replace photo") }
                            .accessibilityIdentifier("recipe-replace-photo")
                        Button("Remove photo", role: .destructive) {
                            pendingRecipePhotoData = nil
                            recipePhotoIdentifier = nil
                            recipePhotoPreview = nil
                            recipePhotoPickerItem = nil
                        }
                        .accessibilityIdentifier("recipe-remove-photo")
                    }
                }
            } else {
                PhotosPicker(selection: $recipePhotoPickerItem, matching: .images) {
                    Label("Add recipe photo", systemImage: AppIcon.recipePhoto)
                }
                .accessibilityIdentifier("recipe-add-photo")
                if let selectedImageData, selectedImagePreview != nil {
                    Button {
                        pendingRecipePhotoData = selectedImageData
                        recipePhotoPreview = selectedImagePreview
                    } label: {
                        Label("Keep generation photo with recipe", systemImage: "photo.on.rectangle")
                    }
                    .accessibilityIdentifier("recipe-keep-generation-photo")
                }
                Text("Optional recognition photo. It is never used as nutrition evidence.")
                    .font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
            }
        }
    }

    /// Locale-aware decimal binding for the recipe-yield field, preserving
    /// partial input like "." while editing.
    private var yieldTextBinding: Binding<String> {
        Binding(
            get: { yieldEditingText ?? DecimalParser.displayText(for: recipeYield) },
            set: { candidate in
                guard let sanitized = DecimalParser.sanitizedEditingText(candidate) else { return }
                yieldEditingText = sanitized
                if sanitized.isEmpty {
                    recipeYield = nil
                } else if let parsed = DecimalParser.value(from: sanitized) {
                    recipeYield = parsed
                }
            }
        )
    }

    private func ingredientAmountText(_ item: (FoodItem, UUID?, Double)) -> String {
        let portions = FoodLibraryService.portions(for: item.0)
        let portion = portions.first { $0.id == item.1 } ?? portions[0]
        return FoodLibraryService.amountDescription(portion: portion, quantity: item.2)
    }

    private func ingredientCaloriesText(_ item: (FoodItem, UUID?, Double)) -> String {
        let portions = FoodLibraryService.portions(for: item.0)
        let portion = portions.first { $0.id == item.1 } ?? portions[0]
        let multiplier = item.2 * portion.equivalentReferenceAmount / item.0.referenceAmount
        return item.0.calories.map { "\(FoodLibraryService.format($0 * multiplier)) kcal" } ?? String(localized: "kcal unknown")
    }

    // MARK: - Generation controls

    @ViewBuilder
    private var generationControls: some View {
        // The `recipeGeneration` flag existed but nothing ever asked it, so the
        // prototype was reachable in every build. It is gated here rather than at
        // the editor, because the editor itself is finished work — it is the
        // generation controls, the transient photo, and the availability notice
        // that are not.
        if FeatureFlags.current.isEnabled(.recipeGeneration) {
            availableGenerationControls
        }
    }

    @ViewBuilder
    private var availableGenerationControls: some View {
        switch availability {
        case .fullyAvailable, .textOnly:
            photoControl
            Text("Prototype — generated results may be inaccurate. Review all foods and quantities before saving.")
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
                .accessibilityLabel("Prototype. Generated results may be inaccurate. Review all foods and quantities before saving.")
            generateButton
        case .modelDownloading:
            Text("Recipe generation will be available when setup finishes.")
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
        case .unsupportedDevice, .unsupportedLocale:
            EmptyView()
        }
    }

    @ViewBuilder
    private var photoControl: some View {
        if selectedImageData != nil, let uiImage = selectedImagePreview {
            HStack(spacing: Spacing.m) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.small))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Selected recipe photo").font(AppFont.footnote).foregroundStyle(Color.gymSubduedText)
                    HStack(spacing: Spacing.l) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) { Text("Replace") }
                            .disabled(isGenerating)
                            .accessibilityLabel("Replace photo")
                            .accessibilityHint("Choose a different recipe photo")
                            .accessibilityIdentifier("replace-recipe-photo")
                        Button(role: .destructive) {
                            selectedImageData = nil
                            selectedImagePreview = nil
                            selectedPhotoItem = nil
                        } label: { Text("Remove") }
                        .disabled(isGenerating)
                        .accessibilityLabel("Remove photo")
                        .accessibilityHint("Removes the selected recipe photo")
                        .accessibilityIdentifier("remove-recipe-photo")
                    }
                }
                Spacer()
            }
        } else if availability.allowsImageInput {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label("Add one photo", systemImage: AppIcon.recipePhoto)
            }
            .disabled(isGenerating)
            .accessibilityHint("Optional. Helps identify the recipe and ingredients.")
            .accessibilityIdentifier("add-recipe-photo")
            Text("Optional — helps identify the recipe and ingredients.")
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
        } else {
            Label("Add one photo", systemImage: AppIcon.recipePhoto)
                .foregroundStyle(Color.gymSubduedText)
            Text("Recipe generation from photos isn’t available on this device.")
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
        }
    }

    private var generateButton: some View {
        Button {
            requestGeneration()
        } label: {
            if isGenerating {
                HStack(spacing: Spacing.s) {
                    ProgressView()
                    Text("Generating recipe…")
                }
            } else {
                Text(hasGeneratedDraft ? "Generate again" : "Generate recipe")
            }
        }
        .disabled(isGenerating || (name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImageData == nil))
        .accessibilityLabel(isGenerating ? "Generating recipe" : (hasGeneratedDraft ? "Generate again" : "Generate recipe"))
        .accessibilityIdentifier("generate-recipe")
    }

    @ViewBuilder
    private func noticeText(_ notice: RecipeGenerationNotice) -> some View {
        switch notice {
        case .draftGenerated:
            Text("Generated draft. Check the ingredients and quantities.")
        case .noMatches:
            Text("No matching foods were found in your library. Add foods manually.")
        case .partialMatch:
            Text("Some ingredients could not be matched. Review the draft and add missing foods.")
        case .generationFailed:
            Text("The recipe couldn’t be generated. Try again or add foods manually.")
        case .unclearImage:
            Text("The photo didn’t contain enough detail. Try another photo or enter a recipe name.")
        case .unsafeImage:
            Text("The photo couldn’t be used to generate a recipe. Try a different photo.")
        }
    }

    private func requestGeneration() {
        if hasGeneratedDraft, let snapshot = lastAppliedDraftSnapshot, snapshot != currentSelectionSnapshot() {
            pendingReplaceConfirmation = true
            return
        }
        runGeneration()
    }

    private func runGeneration() {
        guard isGenerating == false else { return }
        focusedField = nil
        isGenerating = true
        generationNotice = nil
        draftGeneratedFeedbackTrigger = false
        announce(String(localized: "Generating recipe."))
        let input = RecipeGenerationInput(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            imageData: selectedImageData,
            availableFoods: RecipeGenerationCatalogue.build(from: foods)
        )
        generationTask = Task {
            do {
                let validated = try await RecipeGenerationCoordinator.generateAndValidate(input: input, currentFoods: foods, using: generator)
                apply(validated)
            } catch is CancellationError {
                // Preserve current input; no notice for a user-initiated cancel.
            } catch let error as RecipeDraftGeneratorError {
                handle(error)
            } catch {
                generationNotice = .generationFailed
            }
            isGenerating = false
        }
    }

    private func apply(_ validated: ValidatedRecipeDraft) {
        if let newName = validated.name { name = newName }
        if let preparationState = validated.preparationState { preparation = preparationState }
        if let cookedWeightGrams = validated.finalCookedWeightGrams { recipeYield = cookedWeightGrams; yieldEditingText = nil }
        selected = validated.items
        hasGeneratedDraft = true
        lastAppliedDraftSnapshot = currentSelectionSnapshot()

        let imageOnly = selectedImageData != nil && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if validated.isEmpty {
            generationNotice = imageOnly ? .unclearImage : .noMatches
        } else if validated.hasUnmatchedIngredients {
            generationNotice = .partialMatch
        } else {
            generationNotice = .draftGenerated
            draftGeneratedFeedbackTrigger = true
            announce(String(localized: "Recipe draft generated. Review ingredients and quantities."))
        }
    }

    private func handle(_ error: RecipeDraftGeneratorError) {
        switch error {
        case .modelUnavailable, .generationFailed:
            generationNotice = .generationFailed
        case .imageUnsupported:
            generationNotice = .generationFailed
        case .unclearImage:
            generationNotice = .unclearImage
        case .unsafeImage:
            generationNotice = .unsafeImage
        case .cancelled:
            break
        }
    }

    private func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    private func currentSelectionSnapshot() -> [UUID: Double] {
        Dictionary(uniqueKeysWithValues: selected.map { ($0.0.id, $0.2) })
    }

    private func load() {
        guard let template else { return }
        name = template.name; preparation = template.preparationState; recipeYield = template.finalCookedWeightGrams
        recipePhotoIdentifier = template.photoIdentifier
        selected = template.orderedItems.map { ($0.food, $0.servingID, $0.quantity) }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (recipeYield ?? 1) > 0 else { errorMessage = "Recipe yield must be positive or blank."; return }
        guard isSaving == false else { return }
        isSaving = true
        let pendingPhotoData = pendingRecipePhotoData

        Task {
            let photoIdentifier: String?
            if let pendingPhotoData {
                guard let stored = await RecipePhotoStore.storeImageDataAsync(pendingPhotoData) else {
                    guard !Task.isCancelled else { return }
                    errorMessage = "The recipe photo could not be saved. Try another image."
                    isSaving = false
                    return
                }
                photoIdentifier = stored
            } else {
                photoIdentifier = recipePhotoIdentifier
            }

            guard !Task.isCancelled else {
                isSaving = false
                return
            }
            persistRecipe(named: trimmed, photoIdentifier: photoIdentifier)
            isSaving = false
        }
    }

    private func persistRecipe(named trimmed: String, photoIdentifier: String?) {
        if let template {
            guard MealTemplateService.revise(template, name: trimmed, preparationState: preparation, finalCookedWeightGrams: recipeYield, photoIdentifier: photoIdentifier, items: selected, using: modelContext) != nil else { errorMessage = "The recipe could not be saved."; return }
        } else {
            let newTemplate = MealTemplate(name: trimmed, preparationState: preparation, finalCookedWeightGrams: recipeYield, photoIdentifier: photoIdentifier)
            newTemplate.items = selected.enumerated().map { MealTemplateItem(food: $0.element.0, orderIndex: $0.offset, servingID: $0.element.1, quantity: $0.element.2) }
            modelContext.insert(newTemplate)
            guard modelContext.saveOrRollback() else { errorMessage = "The recipe could not be saved."; return }
        }
        dismiss()
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
