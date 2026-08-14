import SwiftData
import SwiftUI

struct BodyWeightHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BodyWeightEntry.measuredAt, order: .reverse) private var entries: [BodyWeightEntry]
    @State private var editor: BodyWeightEditorDestination?
    @State private var saveError: String?

    var body: some View {
        List {
            if let latest = entries.first {
                Section("Current") {
                    LabeledContent("Body weight") {
                        Text(formatted(latest))
                            .font(AppFont.titleMedium)
                    }
                    LabeledContent("Recorded", value: latest.measuredAt.formatted(date: .abbreviated, time: .omitted))
                    if entries.count > 1 {
                        LabeledContent("Since previous", value: change(from: entries[1], to: latest))
                    }
                }
            }

            Section("History") {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No weight history",
                        systemImage: AppIcon.history,
                        description: Text("Add an optional measurement to start your private history."))
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(entries) { entry in
                        Button {
                            editor = BodyWeightEditorDestination(entryID: entry.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text(formatted(entry)).font(AppFont.subheadlineSemibold)
                                    Text(entry.measuredAt.formatted(date: .abbreviated, time: .omitted))
                                        .font(AppFont.caption)
                                        .foregroundStyle(Color.gymSubduedText)
                                }
                                Spacer()
                                Image(systemName: AppIcon.chevronRight)
                                    .foregroundStyle(Color.gymSubduedText)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("body-weight-entry-\(entry.dayKey)")
                        .swipeActions {
                            Button("Delete", role: .destructive) { delete(entry) }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Body Weight")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editor = BodyWeightEditorDestination(entryID: nil) } label: {
                    Label("Add weight", systemImage: AppIcon.plus)
                }
                .accessibilityIdentifier("add-body-weight")
            }
        }
        .sheet(item: $editor) { destination in
            BodyWeightEditorSheet(entry: entries.first { $0.id == destination.entryID }, source: .settings)
        }
        .alert("Couldn’t update weight", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(saveError ?? "Please try again.") }
        .accessibilityIdentifier("body-weight-history")
    }

    private func formatted(_ entry: BodyWeightEntry) -> String {
        "\(Formatters.formatFloat(entry.value)) \(entry.unit.rawValue)"
    }

    private func change(from previous: BodyWeightEntry, to latest: BodyWeightEntry) -> String {
        let delta = latest.kilograms - previous.kilograms
        let displayUnit: WeightType = UserDefaults.standard.unitSystem == .metric ? .kg : .lbs
        let displayDelta = UnitConversion.weight(delta, from: .kg, to: displayUnit)
        let prefix = displayDelta > 0 ? "+" : ""
        return "\(prefix)\(Formatters.formatFloat(displayDelta)) \(displayUnit.rawValue)"
    }

    private func delete(_ entry: BodyWeightEntry) {
        modelContext.delete(entry)
        if modelContext.saveOrRollback() == false {
            saveError = "Your measurement could not be deleted."
        }
    }
}

struct BodyWeightEditorDestination: Identifiable {
    let id = UUID()
    let entryID: UUID?
}

struct BodyWeightEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let entry: BodyWeightEntry?
    let source: BodyWeightSource
    @State private var value = ""
    @State private var unit: WeightType = UserDefaults.standard.unitSystem == .metric ? .kg : .lbs
    @State private var measuredAt = Date.now
    @State private var errorMessage: String?
    @FocusState private var isWeightFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Body weight", text: $value)
                        .keyboardType(.decimalPad)
                        .focused($isWeightFocused)
                        .accessibilityIdentifier("body-weight-value")
                    Picker("Unit", selection: $unit) {
                        Text("kg").tag(WeightType.kg)
                        Text("lb").tag(WeightType.lbs)
                    }
                    .pickerStyle(.segmented)
                    DatePicker("Date", selection: $measuredAt, in: ...Date.now, displayedComponents: .date)
                } header: {
                    Text("Measurement")
                } footer: {
                    Text("One measurement is kept per day. Saving another value for the same day updates that day’s entry.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.gymBackground)
            .navigationTitle(entry == nil ? "Add Weight" : "Edit Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(parsedValue == nil)
                        .accessibilityIdentifier("save-body-weight")
                }
            }
        }
        .onAppear {
            if let entry {
                value = Formatters.formatFloat(entry.value)
                unit = entry.unit
                measuredAt = entry.measuredAt
            } else {
                isWeightFocused = true
            }
        }
        .alert("Couldn’t save weight", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "Please try again.") }
    }

    private var parsedValue: Float? {
        guard let number = Float(value.replacingOccurrences(of: ",", with: ".")), number > 0, number <= 1_500 else { return nil }
        return number
    }

    private func save() {
        guard let parsedValue else { return }
        let day = LocalDay(date: measuredAt)
        let dayKey = day.rawValue
        var descriptor = FetchDescriptor<BodyWeightEntry>(
            predicate: #Predicate { $0.dayKey == dayKey }
        )
        // Two rows cover the edit case where the first match is the entry
        // itself while still keeping this collision check bounded.
        descriptor.fetchLimit = entry == nil ? 1 : 2
        let sameDay = (try? modelContext.fetch(descriptor))?
            .first { $0.id != entry?.id }
        let target = entry ?? sameDay ?? BodyWeightEntry(day: day, value: parsedValue, unit: unit, source: source, measuredAt: measuredAt)
        if entry != nil, let sameDay { modelContext.delete(sameDay) }
        target.dayKey = day.rawValue
        target.update(value: parsedValue, unit: unit, source: source, measuredAt: measuredAt)
        if entry == nil && sameDay == nil { modelContext.insert(target) }
        if modelContext.saveOrRollback() {
            dismiss()
        } else {
            errorMessage = "Your value is still here. Please try saving again."
        }
    }
}
