//
//  WorkoutTemplateDetailView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import SwiftData
import SwiftUI

struct WorkoutTemplateDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }) private var availableExercises: [Exercise]
    @Query(
        filter: #Predicate<MobilityRoutine> { !$0.isArchived },
        sort: \MobilityRoutine.name
    ) private var mobilityRoutines: [MobilityRoutine]

    let template: WorkoutTemplate
    let onStartWorkout: (WorkoutTemplate) -> Void

    @State private var isShowingExercisePicker = false
    @State private var groupingExercise: TemplateExercise?
    @State private var isShowingExecutionBlockBuilder = false
    @State private var executionBlockToEdit: TemplateExerciseBlock?
    @State private var mobilityPlacementToEdit: WorkoutMobilityPlacement?
    @State private var mobilityLinkError: Error?

    var body: some View {
        List {
            if !template.orderedExecutionBlocks.isEmpty {
                Section("Execution Blocks") {
                    ForEach(template.orderedExecutionBlocks, id: \.persistentModelID) { block in
                        HStack {
                            Image(systemName: AppIcon.relationship)
                                .foregroundStyle(Color.gymPrimary)
                            VStack(alignment: .leading) {
                                Text(block.name ?? block.kind.title)
                                Text(templateBlockSummary(block))
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.gymSubduedText)
                            }
                            Spacer()
                            Button("Edit") {
                                executionBlockToEdit = block
                            }
                            .font(AppFont.captionBold)
                            Button("Remove", role: .destructive) {
                                TemplateExecutionBlockService.remove(block, from: template)
                                modelContext.delete(block)
                                saveModelContext(modelContext)
                            }
                            .font(AppFont.captionBold)
                        }
                    }
                }
            }
            Section("Exercises") {
                if orderedTemplateExercises.isEmpty {
                    Text("No exercises in this workout")
                        .foregroundStyle(Color.gymSubduedText)
                } else {
                    ForEach(orderedTemplateExercises, id: \.persistentModelID) { templateExercise in
                        NavigationLink {
                            TemplateExerciseEditorView(templateExercise: templateExercise)
                        } label: {
                            FolderRow(
                                title: templateExercise.exercise.name,
                                subtitle: prescriptionSummary(templateExercise),
                                systemImage: "figure.strengthtraining.traditional"
                            )
                        }
                        .accessibilityIdentifier("template-exercise-editor-\(templateExercise.exercise.name)")
                        .contextMenu {
                            if templateExercise.supersetGroupID == nil {
                                Button("Superset with…") {
                                    groupingExercise = templateExercise
                                }
                            } else {
                                Button("Remove from superset") {
                                    templateExercise.supersetGroupID = nil
                                    template.normalizeTemplateExerciseOrder()
                                    saveModelContext(modelContext)
                                }
                            }
                        }
                    }
                    .onDelete(perform: removeExercises)
                }
            }

            // Mobility is setup for this workout, not the workout itself, so it
            // sits below the exercises it wraps around.
            Section {
                ForEach(WorkoutMobilityPlacement.allCases, id: \.self) { placement in
                    let link = WorkoutMobilityLinkService.link(for: placement, on: template)
                    WorkoutMobilityLinkRow(
                        placement: placement,
                        routine: link.routine,
                        unavailableName: link.isUnavailable ? link.routineNameSnapshot : nil,
                        isEditable: true
                    ) {
                        mobilityPlacementToEdit = placement
                    }
                    .accessibilityIdentifier("template-\(placement.accessibilityIdentifier)")
                }
            } header: {
                Text("Workout mobility")
            } footer: {
                Text("These routines are offered before or after future starts of this workout. Completed mobility history stays unchanged.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle(template.name)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Start", systemImage: "play.fill") {
                    onStartWorkout(template)
                }
                .disabled(orderedTemplateExercises.isEmpty)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Add exercise", systemImage: AppIcon.plus) {
                        isShowingExercisePicker = true
                    }
                    Button("Add execution block", systemImage: AppIcon.relationship) {
                        isShowingExecutionBlockBuilder = true
                    }
                    .disabled(orderedTemplateExercises.isEmpty)
                    .accessibilityIdentifier("add-template-execution-block")
                } label: {
                    Image(systemName: AppIcon.plus)
                }
                .accessibilityIdentifier("template-add-menu")
            }
        }
        .sheet(isPresented: $isShowingExercisePicker) {
            NavigationStack {
                ExercisePickerView(exercises: exercisesToAdd) { exercise in
                    addExercise(exercise)
                }
            }
        }
        .sheet(isPresented: $isShowingExecutionBlockBuilder) {
            TemplateExecutionBlockBuilderSheet(template: template) {
                saveModelContext(modelContext)
            }
        }
        .sheet(item: $executionBlockToEdit) { block in
            TemplateExecutionBlockBuilderSheet(template: template, blockToEdit: block) {
                saveModelContext(modelContext)
            }
        }
        .sheet(item: $mobilityPlacementToEdit) { placement in
            let link = WorkoutMobilityLinkService.link(for: placement, on: template)
            WorkoutMobilityRoutinePicker(
                placement: placement,
                routines: mobilityRoutines,
                currentRoutine: link.routine
            ) { routine in
                do {
                    try WorkoutMobilityLinkService.set(
                        routine,
                        for: placement,
                        on: template,
                        using: modelContext
                    )
                } catch {
                    mobilityLinkError = error
                }
            }
        }
        .alert(
            "Couldn’t update workout mobility",
            isPresented: Binding(
                get: { mobilityLinkError != nil },
                set: { if !$0 { mobilityLinkError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { mobilityLinkError = nil }
        } message: {
            Text("Your previous mobility setting was kept. Please try again.")
        }
        .confirmationDialog(
            "Superset with…",
            isPresented: Binding(
                get: { groupingExercise != nil },
                set: { if !$0 { groupingExercise = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let source = groupingExercise {
                ForEach(orderedTemplateExercises.filter {
                    $0.persistentModelID != source.persistentModelID && $0.supersetGroupID == nil
                }, id: \.persistentModelID) { candidate in
                    Button(candidate.exercise.name) {
                        createSuperset(source, with: candidate)
                    }
                }
            }
        }
    }

    private var exercisesToAdd: [Exercise] {
        availableExercises.filter { exercise in
            !template.exercises.contains {
                $0.persistentModelID == exercise.persistentModelID
            }
        }
    }

    private func addExercise(_ exercise: Exercise) {
        guard !template.exercises.contains(where: {
            $0.persistentModelID == exercise.persistentModelID
        }) else {
            return
        }

        template.templateExercises.append(
            TemplateExercise(exercise: exercise, order: template.templateExercises.count)
        )
        template.normalizeTemplateExerciseOrder()
        saveModelContext(modelContext)
    }

    private func removeExercises(at offsets: IndexSet) {
        let prescriptionsToRemove = offsets.map { orderedTemplateExercises[$0] }
        template.templateExercises.removeAll { prescription in
            prescriptionsToRemove.contains { $0.persistentModelID == prescription.persistentModelID }
        }

        for prescription in prescriptionsToRemove {
            modelContext.delete(prescription)
        }
        removeInvalidExecutionBlocks()
        template.normalizeTemplateExerciseOrder()
        saveModelContext(modelContext)
    }

    private func createSuperset(_ first: TemplateExercise, with second: TemplateExercise) {
        let groupID = UUID()
        first.supersetGroupID = groupID
        second.supersetGroupID = groupID
        var ordered = orderedTemplateExercises
        ordered.removeAll { $0.persistentModelID == second.persistentModelID }
        guard let firstIndex = ordered.firstIndex(where: { $0.persistentModelID == first.persistentModelID }) else {
            return
        }
        ordered.insert(second, at: firstIndex + 1)
        for (index, exercise) in ordered.enumerated() {
            exercise.orderIndex = index
        }
        template.normalizeTemplateExerciseOrder()
        saveModelContext(modelContext)
        groupingExercise = nil
    }

    private var orderedTemplateExercises: [TemplateExercise] {
        template.orderedTemplateExercises
    }

    private func prescriptionSummary(_ templateExercise: TemplateExercise) -> String {
        var components = [
            "\(templateExercise.targetSets) sets",
            "\(templateExercise.repRangeMinimum)-\(templateExercise.repRangeMaximum) reps",
            "\(templateExercise.restSeconds) sec rest"
        ]

        if let rpe = templateExercise.targetRPE {
            components.append("RPE \(Formatters.formatFloat(Float(rpe)))")
        }
        if let rir = templateExercise.targetRIR {
            components.append("RIR \(rir)")
        }
        return components.joined(separator: " · ")
    }

    private func templateBlockSummary(_ block: TemplateExerciseBlock) -> String {
        let names = orderedTemplateExercises
            .filter { $0.executionBlockID == block.id }
            .sorted { ($0.executionBlockComponentOrder ?? .max) < ($1.executionBlockComponentOrder ?? .max) }
            .map { $0.exercise.name }
            .joined(separator: " · ")
        return names
    }

    private func removeInvalidExecutionBlocks() {
        let blocksToRemove = template.orderedExecutionBlocks.filter { block in
            let count = template.templateExercises.filter { $0.executionBlockID == block.id }.count
            return switch block.kind {
            case .straight: count != 1
            case .pairedSet: count != 2
            case .triset: count != 3
            case .giantSet: count < 4
            default: count == 0
            }
        }
        for block in blocksToRemove {
            TemplateExecutionBlockService.remove(block, from: template)
            modelContext.delete(block)
        }
    }
}
