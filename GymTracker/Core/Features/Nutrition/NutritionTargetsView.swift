import SwiftData
import SwiftUI

struct NutritionTargetsView: View {
    @Query(
        filter: #Predicate<NutritionTarget> { !$0.isArchived },
        sort: \NutritionTarget.effectiveStartDayKey,
        order: .reverse
    ) private var targets: [NutritionTarget]
    @State private var editingTarget: NutritionTarget?
    @State private var isCreatingTarget = false

    var body: some View {
        List {
            if targets.isEmpty {
                ContentUnavailableView {
                    Label("No targets", systemImage: AppIcon.chart)
                } description: {
                    Text("Add a training and rest-day target when you are ready.")
                } actions: {
                    Button("Add target") {
                        isCreatingTarget = true
                    }
                    .buttonStyle(.gymPrimary)
                    .accessibilityIdentifier("create-nutrition-target-empty")
                }
            } else {
                ForEach(targets) { target in
                    Button { editingTarget = target } label: {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(target.phase.displayName).font(AppFont.subheadlineSemibold).foregroundStyle(Color.gymText)
                            Text("From \(target.effectiveStartDayKey) · Training \(target.trainingCalories.map { FoodLibraryService.format($0) + " kcal" } ?? "not set")").font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden).background(Color.gymBackground)
        .navigationTitle("Nutrition targets")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button { isCreatingTarget = true } label: { Label("New target", systemImage: AppIcon.plus) } }
        }
        .sheet(isPresented: $isCreatingTarget) { NutritionTargetEditorView() }
        .sheet(item: $editingTarget) { NutritionTargetEditorView(target: $0) }
    }
}

struct NutritionTargetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let target: NutritionTarget?
    @State private var phase: NutritionGoalPhase = .maintenance
    @State private var startDate = Date.now
    @State private var endEnabled = false
    @State private var endDate = Date.now
    @State private var training: [Double?] = [nil, nil, nil, nil]
    @State private var rest: [Double?] = [nil, nil, nil, nil]
    @State private var errorMessage: String?

    init(target: NutritionTarget? = nil) { self.target = target }

    var body: some View {
        NavigationStack {
            Form {
                Section("Phase") {
                    Picker("Goal", selection: $phase) { ForEach(NutritionGoalPhase.allCases, id: \.self) { Text($0.displayName).tag($0) } }
                    DatePicker("Starts", selection: $startDate, displayedComponents: .date)
                    Toggle("Set an end date", isOn: $endEnabled)
                    if endEnabled { DatePicker("Ends", selection: $endDate, displayedComponents: .date) }
                }
                if target != nil {
                    Section {
                        Text("Saving creates a future target revision. Previous days keep their original target phase.")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                    }
                }
                macroFields(title: "Training day", values: $training)
                macroFields(title: "Rest day", values: $rest)
            }
            .scrollContentBackground(.hidden).background(Color.gymBackground)
            .navigationTitle(target == nil ? "New target" : "Edit target")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: load)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).accessibilityIdentifier("save-nutrition-target") }
            }
            .alert("Couldn’t save target", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK", role: .cancel) { errorMessage = nil } } message: { Text(errorMessage ?? "Try again.") }
        }
    }

    @ViewBuilder private func macroFields(title: String, values: Binding<[Double?]>) -> some View {
        Section(title) {
            DecimalField("Calories (optional)", value: values[0], range: 0...100000)
            DecimalField("Protein g (optional)", value: values[1], range: 0...100000)
            DecimalField("Carbohydrates g (optional)", value: values[2], range: 0...100000)
            DecimalField("Fat g (optional)", value: values[3], range: 0...100000)
        }
    }

    private func load() {
        guard let target else { return }
        phase = target.phase; startDate = dayDate(target.effectiveStartDayKey) ?? .now
        if let end = target.effectiveEndDayKey { endEnabled = true; endDate = dayDate(end) ?? .now }
        training = [target.trainingCalories, target.trainingProteinGrams, target.trainingCarbohydrateGrams, target.trainingFatGrams]
        rest = [target.restCalories, target.restProteinGrams, target.restCarbohydrateGrams, target.restFatGrams]
    }

    private func save() {
        guard training.allSatisfy({ ($0 ?? 0) >= 0 }), rest.allSatisfy({ ($0 ?? 0) >= 0 }) else { errorMessage = "Targets must be positive numbers or left blank."; return }
        let start = LocalDay(date: startDate), end = endEnabled ? LocalDay(date: endDate) : nil
        guard end.map({ $0 >= start }) ?? true else { errorMessage = "The end date must be on or after the start date."; return }
        let trainingValues = NutritionTargetValues(calories: training[0], protein: training[1], carbohydrates: training[2], fat: training[3])
        let restValues = NutritionTargetValues(calories: rest[0], protein: rest[1], carbohydrates: rest[2], fat: rest[3])
        if let target {
            guard NutritionTargetService.revise(target, phase: phase, requestedStartDay: start, requestedEndDay: end, training: trainingValues, rest: restValues, using: modelContext) != nil else {
                errorMessage = "The target revision could not be saved."
                return
            }
        } else {
            modelContext.insert(NutritionTarget(phase: phase, effectiveStartDay: start, effectiveEndDay: end, training: trainingValues, rest: restValues))
            guard modelContext.saveOrRollback() else { errorMessage = "The target could not be saved."; return }
        }
        dismiss()
    }
}

private func dayDate(_ key: String) -> Date? {
    let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: key)
}
