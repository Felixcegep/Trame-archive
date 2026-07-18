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
                activate()
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

    private func activate() {
        do {
            let plan = try ProgramDefinitionRepository.compile(record, using: modelContext)
            modelContext.insert(plan)
            guard PlanCoordinator.startRun(for: plan, using: modelContext) != nil else {
                throw ProgramDefinitionStoreError.persistenceFailed
            }
            errorMessage = nil
            didActivate = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
