import SwiftData
import SwiftUI

struct ProgramCatalogView: View {
    @Query(sort: \ProgramDefinitionRecord.name) private var records: [ProgramDefinitionRecord]
    @State private var searchText = ""

    private var builtIns: [ProgramDefinitionRecord] {
        records.filter { record in
            record.isBuiltIn && !record.isArchived && (
                searchText.isEmpty || record.name.localizedCaseInsensitiveContains(searchText)
            )
        }
    }

    var body: some View {
        Group {
            if builtIns.isEmpty && searchText.isEmpty {
                ContentUnavailableView(
                    "No programs available",
                    systemImage: AppIcon.plan,
                    description: Text("The built-in program catalog could not be loaded.")
                )
            } else {
                List {
                    Section {
                        ForEach(builtIns) { record in
                            NavigationLink {
                                ProgramCatalogDetailView(record: record)
                            } label: {
                                ProgramCatalogRow(record: record)
                            }
                            .accessibilityIdentifier("program-catalog-\(record.name)")
                        }
                    } header: {
                        Text("\(builtIns.count) programs")
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .searchable(text: $searchText, prompt: "Search programs")
        .navigationTitle("Program Catalog")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("program-catalog")
    }
}

private struct ProgramCatalogRow: View {
    let record: ProgramDefinitionRecord

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(record.name)
                .font(AppFont.headline)
                .foregroundStyle(Color.gymText)
            HStack(spacing: Spacing.m) {
                Label("\(record.durationWeeks) weeks", systemImage: AppIcon.plan)
                Text(record.experienceLevel.rawValue.localizedCapitalized)
            }
            .font(AppFont.caption)
            .foregroundStyle(Color.gymSubduedText)
            if let summary = record.summary, !summary.isEmpty {
                Text(summary)
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymSubduedText)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, Spacing.s)
    }
}

struct ProgramCatalogDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let record: ProgramDefinitionRecord

    @State private var errorMessage: String?
    @State private var didActivate = false
    @State private var isShowingSetup = false

    private var payload: ProgramDefinitionPayload? { try? record.payload() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                overview
                requirements
                prescription
                activation
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.l)
        }
        .folderScreenStyle()
        .navigationTitle(record.name)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("program-catalog-detail")
        .sheet(isPresented: $isShowingSetup) {
            if let payload {
                NavigationStack {
                    ProgramActivationSetupView(payload: payload) { configuredPayload, startDate in
                        try activate(configuredPayload, startDate: startDate)
                    }
                }
            }
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(record.name)
                .font(AppFont.titleMedium)
                .foregroundStyle(Color.gymText)
            if let summary = record.summary {
                Text(summary)
                    .font(AppFont.body)
                    .foregroundStyle(Color.gymSubduedText)
            }
            HStack(spacing: Spacing.m) {
                Label("\(record.durationWeeks) weeks", systemImage: AppIcon.plan)
                Text(record.experienceLevel.rawValue.localizedCapitalized)
                Text(record.supportedDaysPerWeek.map(String.init).joined(separator: ", ") + " days/week")
            }
            .font(AppFont.caption)
            .foregroundStyle(Color.gymSubduedText)
        }
    }

    @ViewBuilder
    private var requirements: some View {
        if let payload, !payload.prerequisites.isEmpty || !payload.warnings.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text("Before you start").font(AppFont.titleSmall)
                ForEach(payload.prerequisites, id: \.self) { item in
                    Label(item, systemImage: AppIcon.checkmarkCircle)
                }
                ForEach(payload.warnings, id: \.self) { warning in
                    Label(warning, systemImage: AppIcon.warning)
                        .foregroundStyle(Color.gymDestructive)
                }
            }
            .font(AppFont.subheadline)
        }
    }

    @ViewBuilder
    private var prescription: some View {
        if let payload, let rows = try? ProgramDefinitionPreview.rows(for: payload) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text("Prescription preview").font(AppFont.titleSmall)
                ForEach(Array(rows.prefix(8))) { row in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(row.exposureKey).font(AppFont.bodyMedium)
                        Text("Week \(row.weekIndex + 1) · \(row.workoutName) · \(row.setCount) sets")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                    }
                }
                if rows.count > 8 {
                    Text("Plus \(rows.count - 8) additional prescribed sets")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                }
            }
        }
    }

    private var activation: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            if let errorMessage {
                Label(errorMessage, systemImage: AppIcon.warning)
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymDestructive)
                    .accessibilityIdentifier("program-catalog-error")
            }
            Button {
                isShowingSetup = true
            } label: {
                Label(didActivate ? "Program added" : "Use this program", systemImage: didActivate ? AppIcon.checkmark : AppIcon.play)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(didActivate)
            .controlSize(.large)
            .accessibilityIdentifier("use-program")
        }
    }

    private func activate(_ payload: ProgramDefinitionPayload, startDate: Date) throws {
        let exercises = try modelContext.fetch(FetchDescriptor<Exercise>())
        let plan = try ProgramDefinitionCompiler.compile(
            payload,
            exercisesByID: Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        )
        modelContext.insert(plan)
        guard PlanCoordinator.startRun(for: plan, startDate: startDate, using: modelContext) != nil else {
            throw ProgramDefinitionStoreError.persistenceFailed
        }
        errorMessage = nil
        didActivate = true
    }
}

private struct ProgramActivationSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    let payload: ProgramDefinitionPayload
    let onActivate: (ProgramDefinitionPayload, Date) throws -> Void

    @State private var values: [String: String] = [:]
    @State private var startDate = Date.now
    @State private var validationMessage: String?
    @State private var isSaving = false

    var body: some View {
        Form {
            Section("Schedule") {
                DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                LabeledContent("Training frequency", value: frequencyText)
            }

            if payload.intakeInputs.isEmpty {
                Section {
                    Text("This program does not require starting values. You can adjust loads during your first workout.")
                        .foregroundStyle(Color.gymSubduedText)
                }
            } else {
                Section {
                    ForEach(Array(payload.intakeInputs.enumerated()), id: \.offset) { _, input in
                        if input.kind == .startingVariation {
                            Picker(inputTitle(input), selection: valueBinding(for: input)) {
                                Text("Select").tag("")
                                ForEach(variations(for: input), id: \.id) { exercise in
                                    Text(exercise.name).tag(exercise.id.uuidString)
                                }
                            }
                            .accessibilityHint(input.exposureKey)
                        } else {
                            HStack {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(inputTitle(input))
                                Text(input.exposureKey == "*" ? "Applies to every exercise" : input.exposureKey)
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.gymSubduedText)
                            }
                            Spacer()
                            TextField(input.kind == .probeVelocity ? "m/s" : "kg", text: valueBinding(for: input))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(minWidth: 88)
                                .accessibilityLabel(inputTitle(input))
                            }
                        }
                    }
                } header: {
                    Text("Starting values")
                } footer: {
                    Text("Loads use kilograms and bar velocity uses metres per second. Optional values can be left blank.")
                }
            }

            if let validationMessage {
                Section {
                    Label(validationMessage, systemImage: AppIcon.warning)
                        .foregroundStyle(Color.gymDestructive)
                        .accessibilityIdentifier("program-intake-error")
                }
            }

            Section {
                Button {
                    activate()
                } label: {
                    HStack {
                        Spacer()
                        if isSaving { ProgressView() }
                        Text("Start program")
                        Spacer()
                    }
                }
                .disabled(isSaving)
                .accessibilityIdentifier("start-program")
            }
        }
        .navigationTitle("Configure Program")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .interactiveDismissDisabled(isSaving)
        .accessibilityIdentifier("program-intake")
    }

    private var frequencyText: String {
        payload.supportedDaysPerWeek.map(String.init).joined(separator: " or ") + " days per week"
    }

    private func inputTitle(_ input: ProgramIntakeInput) -> String {
        switch input.kind {
        case .oneRepMax: return "One-rep max"
        case .estimatedOneRepMaxReps: return "Estimated one-rep max"
        case .trainingMax: return "Training Max"
        case .startingLoad: return "Starting load"
        case .startingVariation: return "Starting variation"
        case .probeVelocity: return "Probe velocity"
        }
    }

    private func valueBinding(for input: ProgramIntakeInput) -> Binding<String> {
        let key = "\(input.exposureKey)|\(input.kind.rawValue)"
        return Binding(
            get: { values[key, default: ""] },
            set: { values[key] = $0 }
        )
    }

    private func variations(for input: ProgramIntakeInput) -> [Exercise] {
        let ids = Set(payload.blocks.flatMap(\.weeks).flatMap(\.workouts).flatMap(\.plannedExercises)
            .filter { $0.exposureKey == input.exposureKey }
            .flatMap { $0.variationExerciseIDs ?? [] })
        return exercises.filter { ids.contains($0.id) }
    }

    private func activate() {
        do {
            var configured = payload
            for input in payload.intakeInputs {
                let key = "\(input.exposureKey)|\(input.kind.rawValue)"
                let text = values[key, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty {
                    guard !input.isRequired else {
                        throw ProgramIntakeError.missing(inputTitle(input), input.exposureKey)
                    }
                    continue
                }
                if input.kind == .startingVariation {
                    guard let exerciseID = UUID(uuidString: text) else {
                        throw ProgramIntakeError.invalid(inputTitle(input), input.exposureKey)
                    }
                    configured.applyStartingVariation(exerciseID, input: input)
                    continue
                }
                guard let value = Double(text.replacingOccurrences(of: ",", with: ".")), value > 0 else {
                    throw ProgramIntakeError.invalid(inputTitle(input), input.exposureKey)
                }
                configured.applyIntake(value, input: input)
            }
            isSaving = true
            try onActivate(configured, startDate)
            dismiss()
        } catch {
            isSaving = false
            validationMessage = error.localizedDescription
        }
    }
}

private enum ProgramIntakeError: LocalizedError {
    case missing(String, String)
    case invalid(String, String)

    var errorDescription: String? {
        switch self {
        case .missing(let name, let exposure): return "Enter \(name.lowercased()) for \(exposure)."
        case .invalid(let name, let exposure): return "Enter a positive \(name.lowercased()) for \(exposure)."
        }
    }
}

private extension ProgramDefinitionPayload {
    mutating func applyIntake(_ value: Double, input: ProgramIntakeInput) {
        for blockIndex in blocks.indices {
            for weekIndex in blocks[blockIndex].weeks.indices {
                for workoutIndex in blocks[blockIndex].weeks[weekIndex].workouts.indices {
                    for exerciseIndex in blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises.indices {
                        var exercise = blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises[exerciseIndex]
                        guard input.exposureKey == "*" || exercise.exposureKey == input.exposureKey else { continue }
                        switch input.kind {
                        case .oneRepMax:
                            exercise.initialActualOneRepMax = value
                            exercise.initialTrainingMax = value * (input.defaultPercentOfMax ?? 0.9)
                        case .estimatedOneRepMaxReps:
                            exercise.initialEstimatedOneRepMax = value
                        case .trainingMax:
                            exercise.initialTrainingMax = value
                        case .startingLoad:
                            exercise.initialLoad = value
                        case .probeVelocity:
                            exercise.initialVelocityBaseline = value
                        case .startingVariation:
                            break
                        }
                        blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises[exerciseIndex] = exercise
                    }
                }
            }
        }
    }

    mutating func applyStartingVariation(_ exerciseID: UUID, input: ProgramIntakeInput) {
        for blockIndex in blocks.indices {
            for weekIndex in blocks[blockIndex].weeks.indices {
                for workoutIndex in blocks[blockIndex].weeks[weekIndex].workouts.indices {
                    for exerciseIndex in blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises.indices {
                        var exercise = blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises[exerciseIndex]
                        guard exercise.exposureKey == input.exposureKey,
                              exercise.variationExerciseIDs?.contains(exerciseID) == true else { continue }
                        exercise.initialVariationExerciseID = exerciseID
                        blocks[blockIndex].weeks[weekIndex].workouts[workoutIndex].plannedExercises[exerciseIndex] = exercise
                    }
                }
            }
        }
    }
}
