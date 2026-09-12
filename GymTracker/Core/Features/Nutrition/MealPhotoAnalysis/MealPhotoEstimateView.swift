import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct MealPhotoEstimateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.nutritionSelectedDay) private var day
    @Query(filter: #Predicate<FoodItem> { !$0.isArchived }, sort: \FoodItem.name)
    private var foods: [FoodItem]
    @AppStorage(DefaultsKey.mealPhotoConsent) private var consentRaw: String = MealPhotoConsent.default.rawValue

    var initialSlot: MealSlot = .suggested()
    var estimator: any MealPhotoEstimator = MealPhotoEstimatorFactory.make()

    @State private var pickerItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var jpegData: Data?
    @State private var phase: Phase = .pick
    @State private var items: [MealPhotoEstimateItem] = []
    @State private var unclear = false
    @State private var slot: MealSlot = .suggested()
    @State private var showsSendConfirmation = false
    @State private var showsSaveError = false
    @State private var pendingEstimateAfterConsent = false

    private var consent: MealPhotoConsent {
        MealPhotoConsent(rawValue: consentRaw) ?? .default
    }

    private var isScripted: Bool {
        UITestMealPhotoEstimateResult.launchOverride != nil
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .pick:
                    pickContent
                case .loading:
                    loadingContent
                case .review:
                    reviewContent
                case .failed(let message):
                    failedContent(message)
                }
            }
            .background(Color.trameCanvas)
            .navigationTitle("Estimate from photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if phase.isReview {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") { addEstimates() }
                            .disabled(canAdd == false)
                            .accessibilityIdentifier("confirm-photo-estimate")
                    }
                }
            }
        }
        .accessibilityIdentifier("photo-estimate-screen")
        .tint(Color.trameAction)
        .task {
            slot = initialSlot
            if isScripted {
                await runEstimate(jpeg: Data())
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            Task { await loadPickedItem(newItem) }
        }
        .confirmationDialog(
            "Send this photo to estimate the foods?",
            isPresented: $showsSendConfirmation,
            titleVisibility: .visible
        ) {
            Button("Send photo") {
                pendingEstimateAfterConsent = false
                Task { await estimateFromStoredJPEG() }
            }
            .accessibilityIdentifier("confirm-send-photo-estimate")
            Button("Cancel", role: .cancel) {
                pendingEstimateAfterConsent = false
            }
        } message: {
            Text("Only the compressed photo is sent. Your food library stays on this iPhone. Review the result before anything is logged.")
        }
        .alert("Estimate wasn’t added", isPresented: $showsSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Keep at least one named food, then add.")
        }
    }

    @ViewBuilder
    private var pickContent: some View {
        Form {
            if GeminiAPIKeyStore.shared.hasKey == false && isScripted == false {
                Section {
                    Text("Add your Gemini key in Settings before a photo can be sent.")
                    NavigationLink("Photo estimates") {
                        MealPhotoSettingsView()
                    }
                    .accessibilityIdentifier("open-photo-estimate-settings")
                }
            } else if consent == .never && isScripted == false {
                Section {
                    Text("Photo estimates are set to Never. Change that in Settings to send a photo.")
                    NavigationLink("Photo estimates") {
                        MealPhotoSettingsView()
                    }
                    .accessibilityIdentifier("open-photo-estimate-settings")
                }
            }

            Section {
                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                        .accessibilityLabel("Selected meal photo")
                }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label(previewImage == nil ? "Choose photo" : "Choose another photo", systemImage: AppIcon.photoEstimate)
                }
                .accessibilityIdentifier("meal-photo-picker")
                .disabled(consent == .never && isScripted == false)

                Picker("Meal", selection: $slot) {
                    ForEach(MealSlot.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                if day != .today {
                    Text(day.displayName())
                        .font(AppFont.caption)
                        .foregroundStyle(Color.trameSubdued)
                }
            } footer: {
                Text("Review every estimate before it is logged. Missing nutrients stay unknown, never zero.")
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var loadingContent: some View {
        VStack(spacing: Spacing.l) {
            ProgressView()
            Text("Estimating…")
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.trameText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Estimating foods from the photo")
        .accessibilityIdentifier("photo-estimate-loading")
    }

    private var reviewContent: some View {
        Form {
            if unclear {
                Section {
                    Text("This photo isn’t clear. Check the foods below or choose another photo.")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.trameText)
                        .accessibilityIdentifier("photo-estimate-notice")
                }
            }
            Section("Foods") {
                ForEach($items) { $item in
                    itemEditor($item)
                }
                .onDelete { items.remove(atOffsets: $0) }
            }
            Section {
                Picker("Meal", selection: $slot) {
                    ForEach(MealSlot.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Button("Estimate again") {
                    Task { await estimateFromStoredJPEG() }
                }
                .accessibilityIdentifier("estimate-again")
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Choose another photo", systemImage: AppIcon.photoEstimate)
                }
            } footer: {
                Text("Adds estimated snapshots. Library matches are hints only — this does not create foods.")
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func failedContent(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Estimate failed", systemImage: AppIcon.photoEstimate)
        } description: {
            Text(message)
        } actions: {
            Button("Try again") {
                if jpegData != nil {
                    Task { await estimateFromStoredJPEG() }
                } else {
                    phase = .pick
                }
            }
            .accessibilityIdentifier("photo-estimate-retry")
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Text("Choose another photo")
            }
        }
    }

    private func itemEditor(_ item: Binding<MealPhotoEstimateItem>) -> some View {
        let hint = MealPhotoLibraryHint.matchingFoodName(for: item.wrappedValue.name, in: foods)
        return VStack(alignment: .leading, spacing: Spacing.s) {
            TextField("Name", text: item.name)
                .accessibilityIdentifier("photo-estimate-item-name")
            if let hint {
                Text("Also in library: \(hint)")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.trameSubdued)
            }
            DecimalField("Grams (optional)", value: item.grams, range: 0...5_000)
            DecimalField("Calories (optional)", value: item.calories, range: 0...20_000)
            DecimalField("Protein g (optional)", value: item.proteinGrams, range: 0...1_000)
            DecimalField("Carbs g (optional)", value: item.carbohydrateGrams, range: 0...1_000)
            DecimalField("Fat g (optional)", value: item.fatGrams, range: 0...1_000)
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityIdentifier("photo-estimate-item-\(item.wrappedValue.id.uuidString)")
    }

    private var canAdd: Bool {
        items.contains { $0.sanitized != nil }
    }

    private func addEstimates() {
        let drafts = items.compactMap(\.asLoggingDraft)
        let mealName: String
        if drafts.count == 1 {
            mealName = drafts[0].name
        } else {
            mealName = String(localized: "Meal")
        }
        if NutritionLoggingService.logEstimates(
            name: mealName,
            items: drafts,
            day: day,
            slot: slot,
            using: modelContext
        ) != nil {
            dismiss()
        } else {
            showsSaveError = true
        }
    }

    private func loadPickedItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let jpeg = RecipePhotoStore.compressedData(from: image)
            else {
                phase = .failed(String(localized: "That photo couldn’t be read. Choose another."))
                return
            }
            jpegData = jpeg
            previewImage = UIImage(data: jpeg)
            if isScripted {
                await runEstimate(jpeg: jpeg)
                return
            }
            switch consent {
            case .never:
                phase = .pick
            case .ask:
                pendingEstimateAfterConsent = true
                showsSendConfirmation = true
            case .sendWhenEstimating:
                await runEstimate(jpeg: jpeg)
            }
        } catch {
            phase = .failed(String(localized: "That photo couldn’t be read. Choose another."))
        }
    }

    private func estimateFromStoredJPEG() async {
        await runEstimate(jpeg: jpegData ?? Data())
    }

    private func runEstimate(jpeg: Data) async {
        phase = .loading
        do {
            let draft = try await estimator.estimate(imageJPEG: jpeg)
            unclear = draft.unclear
            items = draft.items
            if draft.unclear && draft.items.isEmpty {
                phase = .failed(String(localized: "This photo isn’t clear enough to estimate. Try another."))
            } else if draft.items.isEmpty {
                phase = .failed(String(localized: "No foods were found. Try another photo or Quick add."))
            } else {
                phase = .review
            }
        } catch MealPhotoEstimatorError.missingAPIKey {
            phase = .failed(String(localized: "Add your Gemini key in Settings, then try again."))
        } catch MealPhotoEstimatorError.invalidKey {
            phase = .failed(String(localized: "That Gemini key was rejected. Check it in Settings."))
        } catch MealPhotoEstimatorError.consentDenied {
            phase = .pick
        } catch {
            phase = .failed(String(localized: "Estimate failed. Check the key and try again."))
        }
    }
}

private extension MealPhotoEstimateView {
    enum Phase: Equatable {
        case pick
        case loading
        case review
        case failed(String)

        var isReview: Bool {
            if case .review = self { return true }
            return false
        }
    }
}
