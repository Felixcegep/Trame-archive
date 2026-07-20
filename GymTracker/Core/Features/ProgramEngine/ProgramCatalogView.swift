import SwiftData
import SwiftUI

struct ProgramCatalogView: View {
    @Query(sort: \ProgramDefinitionRecord.name) private var records: [ProgramDefinitionRecord]
    @State private var searchText = ""
    @State private var selectedLevel: PlanExperienceLevel?
    @State private var selectedDays: Int?

    private var availableRecords: [ProgramDefinitionRecord] {
        records.filter { $0.isBuiltIn && !$0.isArchived }
    }

    private var builtIns: [ProgramDefinitionRecord] {
        availableRecords.filter { record in
            (searchText.isEmpty || record.name.localizedCaseInsensitiveContains(searchText))
                && (selectedLevel == nil || record.experienceLevel == selectedLevel)
                && (selectedDays == nil || record.supportedDaysPerWeek.contains(selectedDays ?? 0))
        }
    }

    private var availableDays: [Int] {
        Array(Set(availableRecords.flatMap(\.supportedDaysPerWeek))).sorted()
    }

    var body: some View {
        Group {
            if availableRecords.isEmpty {
                ContentUnavailableView(
                    "No programs available",
                    systemImage: AppIcon.plan,
                    description: Text("The built-in program catalog could not be loaded.")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        filterChips

                        LibraryListSectionHeader(title: "Programs", count: builtIns.count)

                        if builtIns.isEmpty {
                            VStack(alignment: .leading, spacing: Spacing.s) {
                                Text("No programs match your search or filters.")
                                    .font(AppFont.subheadline)
                                    .foregroundStyle(Color.gymSubduedText)
                                Button("Clear filters") {
                                    searchText = ""
                                    selectedLevel = nil
                                    selectedDays = nil
                                }
                                .font(AppFont.subheadlineSemibold)
                            }
                            .padding(.top, Spacing.m)
                        } else {
                            ForEach(builtIns) { record in
                                NavigationLink {
                                    ProgramCatalogDetailView(record: record)
                                } label: {
                                    ProgramCatalogCard(record: record)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("program-catalog-\(record.name)")
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.l)
                }
                .folderScreenStyle()
            }
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search programs"
        )
        .navigationTitle("Program Catalog")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("program-catalog")
    }

    private var filterChips: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            ScrollView(.horizontal) {
                HStack(spacing: Spacing.s) {
                    FilterChip(title: "All levels", isSelected: selectedLevel == nil) {
                        selectedLevel = nil
                    }
                    ForEach(PlanExperienceLevel.allCases, id: \.self) { level in
                        FilterChip(
                            title: level.rawValue.localizedCapitalized,
                            isSelected: selectedLevel == level
                        ) {
                            selectedLevel = selectedLevel == level ? nil : level
                        }
                    }
                }
                .padding(.vertical, Spacing.xs)
            }
            .scrollIndicators(.hidden)

            ScrollView(.horizontal) {
                HStack(spacing: Spacing.s) {
                    FilterChip(title: "Any schedule", isSelected: selectedDays == nil) {
                        selectedDays = nil
                    }
                    ForEach(availableDays, id: \.self) { days in
                        FilterChip(
                            title: "\(days) days/week",
                            isSelected: selectedDays == days
                        ) {
                            selectedDays = selectedDays == days ? nil : days
                        }
                    }
                }
                .padding(.vertical, Spacing.xs)
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct ProgramCatalogCard: View {
    let record: ProgramDefinitionRecord

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text(record.name)
                    .font(AppFont.headline)
                    .foregroundStyle(Color.gymText)
                    .multilineTextAlignment(.leading)

                HStack(spacing: Spacing.s) {
                    ProgramMetaChip(text: "\(record.durationWeeks) weeks")
                    ProgramMetaChip(text: record.experienceLevel.rawValue.localizedCapitalized)
                }

                if let summary = record.summary, !summary.isEmpty {
                    Text(summary)
                        .font(AppFont.subheadline)
                        .foregroundStyle(Color.gymSubduedText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: Spacing.s)

            Image(systemName: "chevron.right")
                .font(AppFont.captionBold)
                .foregroundStyle(Color.gymSubtleText)
        }
        .padding(Spacing.l)
        .background {
            RoundedRectangle(cornerRadius: Radius.large)
                .fill(Color.gymCard)
                .stroke(Color.gymBorder, lineWidth: 1)
        }
        .contentShape(Rectangle())
    }
}

struct ProgramMetaChip: View {
    let text: String

    var body: some View {
        Text(LocalizedStringKey(text))
            .font(AppFont.captionBold)
            .foregroundStyle(Color.gymPrimary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(Color.gymPrimarySurface, in: Capsule())
    }
}

struct ProgramCatalogDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var exercises: [Exercise]
    let record: ProgramDefinitionRecord

    @State private var errorMessage: String?
    @State private var didActivate = false
    @State private var isShowingSetup = false

    private var payload: ProgramDefinitionPayload? { try? record.payload() }

    private var exerciseNamesByID: [UUID: String] {
        Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.name) })
    }

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
        .navigationTitle("")
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
                .font(AppFont.displayMedium)
                .foregroundStyle(Color.gymText)
            if let summary = record.summary {
                Text(summary)
                    .font(AppFont.body)
                    .foregroundStyle(Color.gymSubduedText)
            }
            HStack(spacing: Spacing.s) {
                ProgramMetaChip(text: "\(record.durationWeeks) weeks")
                ProgramMetaChip(text: record.experienceLevel.rawValue.localizedCapitalized)
                ProgramMetaChip(text: record.supportedDaysPerWeek.map(String.init).joined(separator: "/") + " days/week")
            }
        }
    }

    @ViewBuilder
    private var requirements: some View {
        if let payload, !payload.prerequisites.isEmpty || !payload.warnings.isEmpty {
            sectionCard(title: "Before you start") {
                ForEach(payload.prerequisites, id: \.self) { item in
                    Label {
                        Text(item).foregroundStyle(Color.gymText)
                    } icon: {
                        Image(systemName: AppIcon.checkmarkCircle)
                            .foregroundStyle(Color.gymSecondary)
                    }
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
            let names = exerciseNamesByID
            let previewRows = Array(rows.prefix(8))
            let workouts = groupedByWorkout(previewRows)

            sectionCard(title: "Week 1 preview") {
                ForEach(Array(workouts.enumerated()), id: \.offset) { index, workout in
                    if index > 0 {
                        Divider().overlay(Color.gymBorder)
                    }
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Text(workout.name.uppercased())
                            .font(AppFont.captionBold)
                            .tracking(0.8)
                            .foregroundStyle(Color.gymSubduedText)
                        ForEach(Array(workout.rows.enumerated()), id: \.offset) { _, row in
                            HStack {
                                Text(names[row.exerciseID] ?? row.exposureKey)
                                    .font(AppFont.bodyMedium)
                                    .foregroundStyle(Color.gymText)
                                Spacer()
                                Text("\(row.setCount) sets")
                                    .font(AppFont.subheadlineMonospaced)
                                    .foregroundStyle(Color.gymSubduedText)
                            }
                        }
                    }
                }
                if rows.count > previewRows.count {
                    Text("Plus \(rows.count - previewRows.count) more prescribed exercises across the program")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                }
            }
        }
    }

    private func groupedByWorkout(
        _ rows: [ProgramDefinitionPreviewRow]
    ) -> [(name: String, rows: [ProgramDefinitionPreviewRow])] {
        var groups: [(name: String, rows: [ProgramDefinitionPreviewRow])] = []
        for row in rows {
            let name = "Week \(row.weekIndex + 1) · \(row.workoutName)"
            if let lastIndex = groups.indices.last, groups[lastIndex].name == name {
                groups[lastIndex].rows.append(row)
            } else {
                groups.append((name: name, rows: [row]))
            }
        }
        return groups
    }

    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(title)
                .font(AppFont.titleSmall)
                .foregroundStyle(Color.gymText)
            VStack(alignment: .leading, spacing: Spacing.m) {
                content()
            }
            .padding(Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Radius.large)
                    .fill(Color.gymCard)
                    .stroke(Color.gymBorder, lineWidth: 1)
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
