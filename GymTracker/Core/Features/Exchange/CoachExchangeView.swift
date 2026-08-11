import SwiftData
import SwiftUI
import UniformTypeIdentifiers

#if !GYMTRACKER_EXTENSION

/// Local-only coach exchange surface. Package application is definition-only;
/// active runs and completed history are never import targets.
struct CoachExchangeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProgramDefinitionRecord.updatedAt, order: .reverse) private var planDefinitions: [ProgramDefinitionRecord]
    @Query(sort: \WorkoutTemplate.name) private var workoutTemplates: [WorkoutTemplate]
    @Query(sort: \RepeatingPlan.updatedAt, order: .reverse) private var repeatingPlans: [RepeatingPlan]
    @Query(sort: \MobilityProgramDefinitionRecord.updatedAt, order: .reverse) private var mobilityProgramDefinitions: [MobilityProgramDefinitionRecord]
    @Query(sort: \Workout.startTime, order: .reverse) private var workouts: [Workout]
    @Query(sort: \MobilitySession.startTime, order: .reverse) private var mobilitySessions: [MobilitySession]
    @Query(sort: \PlanProgressionRecommendationRecord.createdAt, order: .reverse) private var progressionReceipts: [PlanProgressionRecommendationRecord]

    @State private var selectedWorkoutIDs: Set<UUID> = []
    @State private var hasInitializedWorkoutSelection = false
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -3, to: .now) ?? .now
    @State private var endDate = Date.now
    @State private var includeSportSpecificPerformance = true
    @State private var includeMobility = false
    @State private var includeProgressionReceipts = true
    @State private var includeNotesAndEvidence = false
    @State private var isBuildingReport = false
    @State private var isImportingPackage = false
    @State private var isExportingPackage = false
    @State private var packageToExport: PortableTrainingPackage?
    @State private var selectedPackageComponentIDs: Set<UUID> = []
    @State private var hasInitializedPackageSelection = false
    @State private var isLocalPackageBuilderExpanded = false
    @State private var assembledPackage: PortableTrainingPackage?
    @State private var localPackageExportConfirmed = false
    @State private var packageAssemblyError: String?
    @State private var importedPackage: PortableTrainingPackage?
    @State private var importPreview: PortableImportPreview?
    @State private var importDecisions: [UUID: PortableImportResolution] = [:]
    @State private var importResult: PortableImportApplicationResult?
    @State private var isApplyingImport = false
    @State private var importError: String?
    @State private var packageExportConfirmed = false
    @State private var reportShareConfirmed = false

    var body: some View {
        List {
            packageSection
            reportSection
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle(String(localized: "coach.exchange.title", defaultValue: "Coach exchange"))
        .accessibilityIdentifier("coach-exchange-screen")
        .fileImporter(
            isPresented: $isImportingPackage,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: importPackage
        )
        .fileExporter(
            isPresented: $isExportingPackage,
            document: PortableTrainingPackageFileDocument(package: packageToExport),
            contentType: .json,
            defaultFilename: "training-package.json",
            onCompletion: { _ in packageExportConfirmed = false }
        )
        .alert(
            String(localized: "coach.exchange.import.error.title", defaultValue: "Package action failed"),
            isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )
        ) {
            Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? String(localized: "coach.exchange.import.error.unknown", defaultValue: "The package is unavailable."))
        }
        .task {
            if AppLaunchArguments.current.contains("-ui-testing-coach-exchange-builder-expanded") {
                isLocalPackageBuilderExpanded = true
            }
            initializeWorkoutSelectionIfNeeded()
            initializePackageSelectionIfNeeded()
            if AppLaunchArguments.current.contains("-ui-testing-coach-exchange-build-first") {
                assembleLocalPackage()
                isLocalPackageBuilderExpanded = false
            }
            loadUITestConflictPackageIfNeeded()
            await buildReport()
        }
        .onChange(of: startDate) { _, _ in rebuildReport() }
        .onChange(of: endDate) { _, _ in rebuildReport() }
        .onChange(of: selectedWorkoutIDs) { _, _ in rebuildReport() }
        .onChange(of: includeSportSpecificPerformance) { _, _ in rebuildReport() }
        .onChange(of: includeMobility) { _, _ in rebuildReport() }
        .onChange(of: includeProgressionReceipts) { _, _ in rebuildReport() }
        .onChange(of: includeNotesAndEvidence) { _, _ in rebuildReport() }
    }

    @ViewBuilder
    private var packageSection: some View {
        Section {
            localPackageBuilder

            if let importedPackage {
                packageSummary(importedPackage)
            } else {
                ContentUnavailableView(
                    String(localized: "coach.exchange.package.empty.title", defaultValue: "No package selected"),
                    systemImage: AppIcon.folders,
                    description: Text(String(localized: "coach.exchange.package.empty.detail", defaultValue: "Choose a local training package to inspect its contents before sharing or importing."))
                )
                .accessibilityIdentifier("coach-exchange-package-empty")
            }

            Button {
                isImportingPackage = true
            } label: {
                Label(
                    String(localized: "coach.exchange.package.choose", defaultValue: "Choose package file"),
                    systemImage: AppIcon.folders
                )
            }
            .accessibilityIdentifier("coach-exchange-package-choose")

            if let importedPackage {
                Button {
                    packageExportConfirmed = true
                } label: {
                    Label(
                        String(localized: "coach.exchange.package.export", defaultValue: "Export this package"),
                        systemImage: AppIcon.export
                    )
                }
                .disabled(!importedPackage.validate().isEmpty)
                .accessibilityIdentifier("coach-exchange-package-export")
            }

            if packageExportConfirmed, let importedPackage {
                GymCard(variant: .accent) {
                    Text(String(localized: "coach.exchange.package.export.confirm.title", defaultValue: "Ready to export"))
                        .font(AppFont.headlineSemibold)
                    Text(String(localized: "coach.exchange.package.export.confirm.detail", defaultValue: "This exports selected definitions only. Active runs and completed History are not included."))
                        .font(AppFont.subheadline)
                        .foregroundStyle(Color.gymSubduedText)
                    Button(String(localized: "coach.exchange.package.export.confirm.action", defaultValue: "Confirm export")) {
                        packageToExport = importedPackage
                        isExportingPackage = true
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("coach-exchange-package-export-confirm")
                    Button(String(localized: "common.cancel", defaultValue: "Cancel"), role: .cancel) {
                        packageExportConfirmed = false
                    }
                    .accessibilityIdentifier("coach-exchange-package-export-cancel")
                }
            }

            if let importPreview {
                importPreviewView(importPreview)
            }
        } header: {
            GymSectionHeader(
                title: String(localized: "coach.exchange.package.section", defaultValue: "Training package"),
                detail: String(localized: "coach.exchange.package.section.detail", defaultValue: "Inspect local definitions before any import decision."),
                systemImage: AppIcon.folders
            )
        } footer: {
            Text(String(localized: "coach.exchange.package.footer", defaultValue: "Imports apply definitions only. Active runs and completed History stay unchanged."))
        }
    }

    @ViewBuilder
    private var localPackageBuilder: some View {
        GymCard(variant: .standard) {
            DisclosureGroup(isExpanded: $isLocalPackageBuilderExpanded) {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    Text(String(localized: "coach.exchange.package.create.detail", defaultValue: "Select definitions to package. Dependencies are declared in the artifact; performed workouts and active runs never leave this screen."))
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)

                    if packageSources.isEmpty {
                        Text(String(localized: "coach.exchange.package.create.empty", defaultValue: "No local definitions are available."))
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                    } else {
                        Button {
                            assembleLocalPackage()
                        } label: {
                            Label(
                                String(localized: "coach.exchange.package.create.action", defaultValue: "Build package preview"),
                                systemImage: AppIcon.export
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedPackageComponentIDs.isEmpty)
                        .accessibilityIdentifier("coach-exchange-package-create")

                        ForEach(packageSources, id: \.componentID) { source in
                            Toggle(isOn: packageSelectionBinding(for: source.componentID)) {
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text(source.name)
                                        .font(AppFont.subheadlineSemibold)
                                    Text(packageSourceSubtitle(source))
                                        .font(AppFont.caption)
                                        .foregroundStyle(Color.gymSubduedText)
                                }
                            }
                            .accessibilityIdentifier("coach-exchange-package-source-\(source.componentID.uuidString)")
                        }

                    }
                }
                .padding(.top, Spacing.s)
            } label: {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(String(localized: "coach.exchange.package.create.title", defaultValue: "Create a local package"))
                        .font(AppFont.headlineSemibold)
                    Text(packageBuilderSelectionSummary)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                }
            }
            .accessibilityIdentifier("coach-exchange-package-builder-disclosure")

            if let packageAssemblyError {
                Label(packageAssemblyError, systemImage: AppIcon.warning)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymAccent)
                    .accessibilityIdentifier("coach-exchange-package-create-error")
            }

            if let assembledPackage {
                packageSummary(assembledPackage)
                if localPackageExportConfirmed {
                    Button {
                        packageToExport = assembledPackage
                        isExportingPackage = true
                    } label: {
                        Label(
                            String(localized: "coach.exchange.package.create.confirm", defaultValue: "Confirm export"),
                            systemImage: AppIcon.export
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("coach-exchange-package-create-export-confirm")
                    Button(String(localized: "common.cancel", defaultValue: "Cancel"), role: .cancel) {
                        localPackageExportConfirmed = false
                    }
                } else {
                    Button {
                        localPackageExportConfirmed = true
                    } label: {
                        Label(
                            String(localized: "coach.exchange.package.create.export", defaultValue: "Export created package"),
                            systemImage: AppIcon.export
                        )
                    }
                    .accessibilityIdentifier("coach-exchange-package-create-export")
                }
            }
        }
        .accessibilityIdentifier("coach-exchange-package-create-card")
    }

    private var packageBuilderSelectionSummary: String {
        String(
            format: String(
                localized: "coach.exchange.package.create.selection.summary",
                defaultValue: "%lld selected · %lld available"
            ),
            locale: .current,
            Int64(selectedPackageComponentIDs.count),
            Int64(packageSources.count)
        )
    }

    private func packageSummary(_ package: PortableTrainingPackage) -> some View {
        GymCard(variant: .standard) {
            HStack {
                GymIconChip(systemImage: AppIcon.folders)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(package.author.displayName ?? String(localized: "coach.exchange.package.author.unknown", defaultValue: "Unnamed author"))
                        .font(AppFont.headlineSemibold)
                    Text("\(package.components.count) \(packageComponentLabel(count: package.components.count)) · v\(package.packageVersion)")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                }
                Spacer()
                GymStatusBadge(
                    title: package.validate().isEmpty
                        ? String(localized: "coach.exchange.package.valid", defaultValue: "Valid")
                        : String(localized: "coach.exchange.package.invalid", defaultValue: "Needs review"),
                    systemImage: package.validate().isEmpty ? AppIcon.checkmark : AppIcon.warning,
                    tint: package.validate().isEmpty ? Color.gymSuccess : Color.gymAccent
                )
            }
            Text(String(localized: "coach.exchange.package.integrity", defaultValue: "Integrity checksum: %@").replacingOccurrences(of: "%@", with: String(package.checksum.prefix(12)) + "…"))
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
            ForEach(package.components, id: \.componentID) { component in
                Label(component.name, systemImage: component.kind == .mobilityProgram ? AppIcon.mobility : AppIcon.workout)
                    .font(AppFont.subheadline)
                    .accessibilityValue(String(localized: "coach.exchange.package.component.value", defaultValue: "Selected definition"))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("coach-exchange-package-summary")
    }

    private func packageComponentLabel(count: Int) -> String {
        count == 1
            ? String(localized: "coach.exchange.package.component", defaultValue: "component")
            : String(localized: "coach.exchange.package.components", defaultValue: "components")
    }

    @ViewBuilder
    private func importPreviewView(_ preview: PortableImportPreview) -> some View {
        GymCard(variant: preview.canImport ? .completed : .accent) {
            Text(String(localized: "coach.exchange.import.preview.title", defaultValue: "Import preview"))
                .font(AppFont.headlineSemibold)
                .accessibilityIdentifier("coach-exchange-import-preview")
            Text(preview.canImport
                 ? String(localized: "coach.exchange.import.preview.ready", defaultValue: "No conflicts require resolution.")
                 : String(localized: "coach.exchange.import.preview.review", defaultValue: "Review these classifications before any import action."))
                .font(AppFont.subheadline)
                .foregroundStyle(Color.gymSubduedText)

            if !preview.validationFailures.isEmpty {
                Label(
                    String(localized: "coach.exchange.import.validation", defaultValue: "Package validation issues: %@")
                        .replacingOccurrences(of: "%@", with: String(preview.validationFailures.count)),
                    systemImage: AppIcon.warning
                )
                .font(AppFont.caption)
                .foregroundStyle(Color.gymAccent)
                .accessibilityIdentifier("coach-exchange-import-validation-failures")
            }
            if !preview.compatibilityFailures.isEmpty {
                Label(
                    String(localized: "coach.exchange.import.compatibility", defaultValue: "Compatibility requirements are not met."),
                    systemImage: AppIcon.lock
                )
                .font(AppFont.caption)
                .foregroundStyle(Color.gymAccent)
                .accessibilityIdentifier("coach-exchange-import-compatibility-failures")
            }

            ForEach(preview.items, id: \.component.componentID) { item in
                VStack(alignment: .leading, spacing: Spacing.s) {
                    HStack(alignment: .top, spacing: Spacing.s) {
                        GymIconChip(systemImage: importIcon(item.classification), tint: importTint(item.classification))
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(item.component.name)
                                .font(AppFont.subheadlineSemibold)
                            Text(importLabel(item.classification))
                                .font(AppFont.captionBold)
                                .foregroundStyle(importTint(item.classification))
                            Text(item.detail)
                                .font(AppFont.caption)
                                .foregroundStyle(Color.gymSubduedText)
                        }
                    }
                    Picker(
                        String(localized: "coach.exchange.import.decision", defaultValue: "Import decision"),
                        selection: importDecisionBinding(for: item)
                    ) {
                        ForEach(availableResolutions(for: item), id: \.self) { resolution in
                            Text(importResolutionLabel(resolution)).tag(resolution)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel(
                        String(localized: "coach.exchange.import.decision", defaultValue: "Import decision")
                    )
                    .accessibilityValue(importResolutionLabel(importDecisions[item.component.componentID] ?? defaultImportResolution(for: item.classification)))
                    .accessibilityIdentifier("coach-exchange-import-decision-\(item.component.componentID.uuidString)")
                }
                .accessibilityIdentifier("coach-exchange-import-item-\(item.component.componentID.uuidString)")
            }

            Label(
                String(localized: "coach.exchange.import.protection", defaultValue: "Active runs and completed History will remain unchanged."),
                systemImage: AppIcon.lock
            )
            .font(AppFont.caption)
            .foregroundStyle(Color.gymSubduedText)
            .accessibilityIdentifier("coach-exchange-import-protection")

            if let importResult {
                Label(
                    String(
                        format: String(localized: "coach.exchange.import.success", defaultValue: "Import complete: %d added, %d updated, %d kept."),
                        importResult.insertedComponentIDs.count,
                        importResult.updatedComponentIDs.count,
                        importResult.skippedComponentIDs.count
                    ),
                    systemImage: AppIcon.checkmark
                )
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.gymSuccess)
                .accessibilityIdentifier("coach-exchange-import-success")
            } else {
                Button {
                    applyImportedPackage()
                } label: {
                    if isApplyingImport {
                        ProgressView()
                    } else {
                        Label(String(localized: "coach.exchange.import.apply", defaultValue: "Apply selected import"), systemImage: AppIcon.checkmark)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canApplyImport || isApplyingImport)
                .accessibilityLabel(String(
                    localized: isApplyingImport
                        ? "coach.exchange.import.applying"
                        : "coach.exchange.import.apply",
                    defaultValue: isApplyingImport ? "Applying import" : "Apply selected import"
                ))
                .accessibilityIdentifier("coach-exchange-import-apply")
            }
        }
    }

    @ViewBuilder
    private var reportSection: some View {
        Section {
            DatePicker(
                String(localized: "coach.exchange.report.start", defaultValue: "From"),
                selection: $startDate,
                displayedComponents: .date
            )
            .accessibilityIdentifier("coach-exchange-report-start")
            DatePicker(
                String(localized: "coach.exchange.report.end", defaultValue: "To"),
                selection: $endDate,
                displayedComponents: .date
            )
            .accessibilityIdentifier("coach-exchange-report-end")

            if startDate >= endDate {
                Label(
                    String(localized: "coach.exchange.report.invalid.range", defaultValue: "Choose an end date after the start date."),
                    systemImage: AppIcon.warning
                )
                .foregroundStyle(Color.gymAccent)
                .accessibilityIdentifier("coach-exchange-report-invalid-range")
            }

            Toggle(String(localized: "coach.exchange.report.sport", defaultValue: "Sport-specific performance"), isOn: $includeSportSpecificPerformance)
            Toggle(String(localized: "coach.exchange.report.mobility", defaultValue: "Mobility"), isOn: $includeMobility)
            Toggle(String(localized: "coach.exchange.report.progression", defaultValue: "Progression receipts"), isOn: $includeProgressionReceipts)
            Toggle(String(localized: "coach.exchange.report.notes", defaultValue: "Notes and evidence"), isOn: $includeNotesAndEvidence)

            Text(String(localized: "coach.exchange.report.workouts.selected", defaultValue: "Completed workouts"))
                .font(AppFont.headlineSemibold)
            if workouts.filter(\.isCompleted).isEmpty {
                ContentUnavailableView(
                    String(localized: "coach.exchange.report.empty.title", defaultValue: "No completed workouts"),
                    systemImage: AppIcon.history,
                    description: Text(String(localized: "coach.exchange.report.empty.detail", defaultValue: "Complete a workout to include it in a local report."))
                )
                .accessibilityIdentifier("coach-exchange-report-empty")
            } else {
                ForEach(workouts.filter(\.isCompleted), id: \.id) { workout in
                    Toggle(isOn: workoutSelectionBinding(for: workout.id)) {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(workout.name ?? String(localized: "coach.exchange.report.workout.untitled", defaultValue: "Untitled workout"))
                                .font(AppFont.subheadlineSemibold)
                            Text(workout.startTime.formatted(.dateTime.year().month(.abbreviated).day()))
                                .font(AppFont.caption)
                                .foregroundStyle(Color.gymSubduedText)
                        }
                    }
                    .accessibilityIdentifier("coach-exchange-report-workout-\(workout.id.uuidString)")
                }
            }

            reportPreview
        } header: {
            GymSectionHeader(
                title: String(localized: "coach.exchange.report.section", defaultValue: "Training report"),
                detail: String(localized: "coach.exchange.report.section.detail", defaultValue: "Select exactly what the local artifact contains."),
                systemImage: AppIcon.export
            )
        }
    }

    @ViewBuilder
    private var reportPreview: some View {
        if isBuildingReport {
            ProgressView(String(localized: "coach.exchange.report.loading", defaultValue: "Building report preview…"))
                .accessibilityIdentifier("coach-exchange-report-loading")
        } else if startDate >= endDate {
            Text(String(localized: "coach.exchange.report.unavailable", defaultValue: "Report preview unavailable until the date range is valid."))
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
        } else {
            let artifact = reportArtifact
            GymCard(variant: .standard) {
                Text(String(localized: "coach.exchange.report.preview.title", defaultValue: "Artifact preview"))
                    .font(AppFont.headlineSemibold)
                Text("\(artifact.preview.sectionCount) \(String(localized: "coach.exchange.report.preview.sections", defaultValue: "sections")) · \(artifact.preview.rowCount) \(String(localized: "coach.exchange.report.preview.rows", defaultValue: "rows"))")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                ForEach(artifact.sections) { section in
                    Label(section.title, systemImage: AppIcon.chevronRight)
                        .font(AppFont.subheadline)
                }
                if selectedWorkoutIDs.isEmpty {
                    Text(String(localized: "coach.exchange.report.preview.none.selected", defaultValue: "No workouts are selected; the report will contain explicit zero or missing evidence."))
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymAccent)
                }
                if reportShareConfirmed {
                    ShareLink(
                        item: artifact.humanReadableText,
                        subject: Text(String(localized: "coach.exchange.report.share.subject", defaultValue: "GymTracker training report")),
                        message: Text(String(localized: "coach.exchange.report.share.message", defaultValue: "A local report preview selected in GymTracker."))
                    ) {
                        Label(String(localized: "coach.exchange.report.share.open", defaultValue: "Open system share"), systemImage: AppIcon.export)
                    }
                    .accessibilityIdentifier("coach-exchange-report-system-share")
                } else {
                    Button {
                        reportShareConfirmed = true
                    } label: {
                        Label(String(localized: "coach.exchange.report.share.confirm", defaultValue: "Confirm and share"), systemImage: AppIcon.export)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("coach-exchange-report-share-confirm")
                }
                if reportShareConfirmed {
                    Button(String(localized: "coach.exchange.report.share.cancel", defaultValue: "Cancel share"), role: .cancel) {
                        reportShareConfirmed = false
                    }
                    .accessibilityIdentifier("coach-exchange-report-share-cancel")
                }
            }
            .accessibilityIdentifier("coach-exchange-report-preview")
        }
    }

    private var reportArtifact: TrainingReportArtifact {
        TrainingReportProjection.build(
            selection: TrainingReportSelection(
                dateRange: TrainingReportDateRange(start: startDate, end: endDate),
                selectedWorkoutIDs: selectedWorkoutIDs,
                includeSportSpecificPerformance: includeSportSpecificPerformance,
                includeMobility: includeMobility,
                includeProgressionReceipts: includeProgressionReceipts,
                includeNotesAndEvidence: includeNotesAndEvidence
            ),
            workouts: workouts,
            mobilitySessions: mobilitySessions,
            progressionReceipts: progressionReceipts
        )
    }

    private var packageSources: [PortableTrainingAssemblySource] {
        var sources: [PortableTrainingAssemblySource] = []
        sources.append(contentsOf: planDefinitions.compactMap { try? PortableTrainingPackageAssemblyProjection.source(record: $0) })
        sources.append(contentsOf: workoutTemplates.compactMap { try? PortableTrainingPackageAssemblyProjection.source(template: $0) })
        sources.append(contentsOf: repeatingPlans.compactMap { try? PortableTrainingPackageAssemblyProjection.source(repeatingPlan: $0) })
        sources.append(contentsOf: mobilityProgramDefinitions.compactMap { try? PortableTrainingPackageAssemblyProjection.source(record: $0) })
        return sources.sorted {
            if $0.kind != $1.kind { return $0.kind.rawValue < $1.kind.rawValue }
            if $0.name != $1.name { return $0.name < $1.name }
            return $0.componentID.uuidString < $1.componentID.uuidString
        }
    }

    private func packageSourceSubtitle(_ source: PortableTrainingAssemblySource) -> String {
        let dependencyCount = source.dependencies.count
        let dependencyText = dependencyCount == 1 ? "1 dependency" : "\(dependencyCount) dependencies"
        return "\(source.kind.rawValue) · \(dependencyText)"
    }

    private func packageSelectionBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { selectedPackageComponentIDs.contains(id) },
            set: { selected in
                if selected { selectedPackageComponentIDs.insert(id) }
                else { selectedPackageComponentIDs.remove(id) }
            }
        )
    }

    private func initializePackageSelectionIfNeeded() {
        guard !hasInitializedPackageSelection else { return }
        hasInitializedPackageSelection = true
        if AppLaunchArguments.current.contains("-ui-testing-coach-exchange-select-first"),
           let first = packageSources.first(where: { $0.name == "Strength Day" }) ?? packageSources.first {
            selectedPackageComponentIDs = [first.componentID]
        }
    }

    private func assembleLocalPackage() {
        do {
            assembledPackage = try PortableTrainingPackageAssemblyProjection.assemble(
                selection: PortableTrainingPackageSelection(componentIDs: selectedPackageComponentIDs),
                sources: packageSources,
                author: PortableTrainingAuthor(authorID: nil, displayName: "GymTracker", organization: nil),
                provenance: PortableTrainingProvenance(
                    kind: .userAuthored,
                    sourceIdentifier: "local-selection",
                    statement: "Selected locally from GymTracker definitions."
                ),
                compatibility: PortableTrainingCompatibility(
                    minimumAppBuild: nil,
                    minimumSchemaVersion: 1,
                    requiredCapabilityIDs: []
                )
            )
            packageAssemblyError = nil
            localPackageExportConfirmed = false
        } catch {
            assembledPackage = nil
            packageAssemblyError = String(localized: "coach.exchange.package.create.error", defaultValue: "The selected definitions could not be packaged.")
        }
    }

    private func workoutSelectionBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { selectedWorkoutIDs.contains(id) },
            set: { selected in
                if selected { selectedWorkoutIDs.insert(id) }
                else { selectedWorkoutIDs.remove(id) }
            }
        )
    }

    private func initializeWorkoutSelectionIfNeeded() {
        guard !hasInitializedWorkoutSelection else { return }
        selectedWorkoutIDs = Set(workouts.filter(\.isCompleted).map(\.id))
        hasInitializedWorkoutSelection = true
    }

    private func rebuildReport() {
        isBuildingReport = true
        Task { @MainActor in
            await buildReport()
        }
    }

    private func buildReport() async {
        isBuildingReport = true
        await Task.yield()
        isBuildingReport = false
    }

    private func importPackage(_ result: Result<[URL], Error>) {
        do {
            let url = try result.get().first.unwrap(or: CoachExchangeError.noFileSelected)
            let didStartSecurityScope = url.startAccessingSecurityScopedResource()
            defer {
                if didStartSecurityScope {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let data = try Data(contentsOf: url)
            let package = try JSONDecoder().decode(PortableTrainingPackage.self, from: data)
            importedPackage = package
            importPreview = PortableImportPreviewPolicy.preview(
                package: package,
                localComponents: PortableLocalComponentInventory.build(using: modelContext),
                supportedCapabilityIDs: EngineCapabilities.current,
                minimumSchemaVersion: 1
            )
            importDecisions = Dictionary(uniqueKeysWithValues: (importPreview?.items ?? []).map {
                ($0.component.componentID, defaultImportResolution(for: $0.classification))
            })
            importResult = nil
            importError = nil
        } catch {
            importedPackage = nil
            importPreview = nil
            importDecisions = [:]
            importResult = nil
            importError = error.localizedDescription
        }
    }

    private var canApplyImport: Bool {
        guard let preview = importPreview else { return false }
        return preview.validationFailures.isEmpty && preview.compatibilityFailures.isEmpty &&
            preview.items.allSatisfy { importDecisions[$0.component.componentID] != nil }
    }

    private func applyImportedPackage() {
        guard let package = importedPackage else { return }
        isApplyingImport = true
        defer { isApplyingImport = false }
        do {
            importResult = try PortableTrainingPackageImportService.apply(
                package: package,
                decisions: importDecisions.map { PortableImportDecision(componentID: $0.key, resolution: $0.value) },
                using: modelContext
            )
            importError = nil
        } catch {
            importResult = nil
            importError = error.localizedDescription
        }
    }

    /// Deterministic capture-only seam. The system document picker is not UI
    /// testable, so this builds the same valid package the picker would decode
    /// from an existing local definition and enters the real preview/apply flow.
    private func loadUITestConflictPackageIfNeeded() {
        guard AppLaunchArguments.current.contains("-ui-testing-coach-exchange-import-conflict"),
              importedPackage == nil,
              let template = workoutTemplates.first,
              let source = try? PortableTrainingPackageAssemblyProjection.source(template: template),
              var payload = try? JSONSerialization.jsonObject(with: source.payload) as? [String: Any]
        else { return }
        payload["name"] = "Coach variation"
        guard let changedPayload = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) else { return }
        let changedSource = PortableTrainingAssemblySource(
            componentID: source.componentID,
            contentID: source.contentID,
            kind: source.kind,
            name: "Coach variation",
            contentVersion: source.contentVersion + 1,
            payload: changedPayload,
            dependencies: source.dependencies
        )
        guard let package = try? PortableTrainingPackageAssemblyProjection.assemble(
            selection: .init(componentIDs: [source.componentID]),
            sources: [changedSource],
            author: .init(authorID: nil, displayName: "UI Test Coach", organization: nil),
            provenance: .init(kind: .imported, sourceIdentifier: "ui-test", statement: nil),
            compatibility: .init(minimumAppBuild: nil, minimumSchemaVersion: 1, requiredCapabilityIDs: [])
        ) else { return }
        importedPackage = package
        importPreview = PortableImportPreviewPolicy.preview(
            package: package,
            localComponents: PortableLocalComponentInventory.build(using: modelContext),
            supportedCapabilityIDs: EngineCapabilities.current,
            minimumSchemaVersion: 1
        )
        importDecisions = Dictionary(uniqueKeysWithValues: (importPreview?.items ?? []).map {
            ($0.component.componentID, defaultImportResolution(for: $0.classification))
        })
    }

    private func importDecisionBinding(for item: PortableImportItemPreview) -> Binding<PortableImportResolution> {
        Binding(
            get: { importDecisions[item.component.componentID] ?? defaultImportResolution(for: item.classification) },
            set: { importDecisions[item.component.componentID] = $0 }
        )
    }

    private func availableResolutions(for item: PortableImportItemPreview) -> [PortableImportResolution] {
        switch item.classification {
        case .addition: [.importSeparateCopy]
        case .exactMatch: [.keepExisting, .importSeparateCopy]
        case .safeUpdate:
            importedPackage?.provenance.kind == .bundled
                ? [.keepExisting, .importSeparateCopy, .updateExisting]
                : [.keepExisting, .importSeparateCopy]
        case .identityConflict, .nameConflict, .versionConflict: [.keepExisting, .importSeparateCopy]
        case .missingDependency, .incompatible: [.keepExisting]
        }
    }

    private func defaultImportResolution(for classification: PortableImportClassification) -> PortableImportResolution {
        switch classification {
        case .addition: .importSeparateCopy
        default: .keepExisting
        }
    }

    private func importResolutionLabel(_ resolution: PortableImportResolution) -> String {
        switch resolution {
        case .keepExisting: String(localized: "coach.exchange.import.resolution.keep", defaultValue: "Keep existing")
        case .importSeparateCopy: String(localized: "coach.exchange.import.resolution.copy", defaultValue: "Import separate copy")
        case .updateExisting: String(localized: "coach.exchange.import.resolution.update", defaultValue: "Update eligible definition")
        }
    }

    private func importIcon(_ classification: PortableImportClassification) -> String {
        switch classification {
        case .addition: AppIcon.plus
        case .exactMatch: AppIcon.checkmark
        case .safeUpdate: AppIcon.progression
        case .identityConflict, .nameConflict, .versionConflict: AppIcon.warning
        case .missingDependency: AppIcon.relationship
        case .incompatible: AppIcon.lock
        }
    }

    private func importTint(_ classification: PortableImportClassification) -> Color {
        switch classification {
        case .addition, .exactMatch: Color.gymSuccess
        case .safeUpdate: Color.gymPrimary
        case .identityConflict, .nameConflict, .versionConflict, .missingDependency, .incompatible: Color.gymAccent
        }
    }

    private func importLabel(_ classification: PortableImportClassification) -> String {
        switch classification {
        case .addition: String(localized: "coach.exchange.import.classification.addition", defaultValue: "Addition")
        case .exactMatch: String(localized: "coach.exchange.import.classification.exact", defaultValue: "Exact match")
        case .safeUpdate: String(localized: "coach.exchange.import.classification.update", defaultValue: "Safe update")
        case .identityConflict: String(localized: "coach.exchange.import.classification.identity", defaultValue: "Identity conflict")
        case .nameConflict: String(localized: "coach.exchange.import.classification.name", defaultValue: "Name conflict")
        case .missingDependency: String(localized: "coach.exchange.import.classification.dependency", defaultValue: "Missing dependency")
        case .incompatible: String(localized: "coach.exchange.import.classification.incompatible", defaultValue: "Incompatible")
        case .versionConflict: String(localized: "coach.exchange.import.classification.version", defaultValue: "Version conflict")
        }
    }
}

private enum CoachExchangeError: LocalizedError {
    case noFileSelected

    var errorDescription: String? {
        String(localized: "coach.exchange.import.error.no.file", defaultValue: "No package file was selected.")
    }
}

private extension Optional where Wrapped == URL {
    func unwrap(or error: Error) throws -> URL {
        guard let self else { throw error }
        return self
    }
}

private struct PortableTrainingPackageFileDocument: FileDocument {
    private static let maximumFileBytes = 14 * 1_024 * 1_024
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    let data: Data

    init(package: PortableTrainingPackage?) {
        self.data = (try? JSONEncoder().encode(package)) ?? Data()
    }

    init(configuration: ReadConfiguration) throws {
        let contents = configuration.file.regularFileContents ?? Data()
        guard contents.count <= Self.maximumFileBytes else {
            throw CocoaError(.fileReadTooLarge)
        }
        data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

#endif
