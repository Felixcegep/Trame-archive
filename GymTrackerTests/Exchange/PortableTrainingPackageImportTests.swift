import SwiftData
import XCTest
@testable import GymTracker

#if !GYMTRACKER_EXTENSION

@MainActor
final class PortableTrainingPackageImportTests: XCTestCase {
    func testTemplateImportUsesStableIdentityAndLeavesCompletedHistoryUnchanged() throws {
        let sourceContext = try GymTrackerTestStore.makeInMemoryContext()
        let exerciseID = UUID()
        let exercise = Exercise(name: "Squat", primaryMuscles: [.quadriceps], id: exerciseID)
        let template = WorkoutTemplate(
            name: "Coach Squat",
            exercises: [],
            templateExercises: [TemplateExercise(exercise: exercise, order: 0, targetSets: 4)]
        )
        sourceContext.insert(exercise)
        sourceContext.insert(template)
        try sourceContext.save()
        let source = try PortableTrainingPackageAssemblyProjection.source(template: template)
        let package = try makePackage(source: source)

        let targetContext = try GymTrackerTestStore.makeInMemoryContext()
        targetContext.insert(Exercise(name: "Local Squat", primaryMuscles: [.quadriceps], id: exerciseID))
        let workout = Workout(name: "Completed truth", endTime: Date(timeIntervalSince1970: 1_700_000_000))
        let historicalID = workout.id
        let historicalEnd = workout.endTime
        let activeWorkout = Workout(name: "Active truth")
        let activeID = activeWorkout.id
        targetContext.insert(workout)
        targetContext.insert(activeWorkout)
        try targetContext.save()

        let result = try PortableTrainingPackageImportService.apply(
            package: package,
            decisions: [PortableImportDecision(componentID: source.componentID, resolution: .importSeparateCopy)],
            using: targetContext
        )

        let templates = try targetContext.fetch(FetchDescriptor<WorkoutTemplate>())
        let history = try targetContext.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(result.insertedComponentIDs, [source.contentID])
        XCTAssertEqual(templates.count, 1)
        XCTAssertEqual(templates[0].id, source.contentID)
        XCTAssertEqual(templates[0].orderedTemplateExercises.first?.exercise.id, exerciseID)
        XCTAssertEqual(Set(history.map(\.id)), Set([historicalID, activeID]))
        XCTAssertEqual(history.first(where: { $0.id == historicalID })?.endTime, historicalEnd)
        XCTAssertNil(history.first(where: { $0.id == activeID })?.endTime)
    }

    func testUnsafeUpdateRollsBackWithoutChangingUserTemplate() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Squat", primaryMuscles: [.quadriceps])
        let existing = WorkoutTemplate(name: "Mine", exercises: [exercise])
        context.insert(exercise)
        context.insert(existing)
        try context.save()

        let incoming = WorkoutTemplate(
            name: "Incoming",
            exercises: [],
            templateExercises: [TemplateExercise(exercise: exercise, order: 0, targetSets: 5)]
        )
        incoming.id = existing.id
        let source = try PortableTrainingPackageAssemblyProjection.source(template: incoming)
        let package = try makePackage(source: PortableTrainingAssemblySource(
            componentID: source.componentID,
            contentID: source.contentID,
            kind: source.kind,
            name: source.name,
            contentVersion: 2,
            payload: source.payload,
            dependencies: source.dependencies
        ))

        XCTAssertThrowsError(try PortableTrainingPackageImportService.apply(
            package: package,
            decisions: [PortableImportDecision(componentID: source.componentID, resolution: .updateExisting)],
            using: context
        )) { error in
            XCTAssertEqual(error as? PortableTrainingPackageImportError, .unsafeUpdate(source.componentID))
        }
        XCTAssertEqual(try context.fetch(FetchDescriptor<WorkoutTemplate>()).count, 1)
        XCTAssertEqual(existing.name, "Mine")
        XCTAssertEqual(existing.orderedTemplateExercises.first?.targetSets, 3)
    }

    func testInvalidChecksumFailsBeforeMutation() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let component = PortableTrainingComponentDescriptor(
            componentID: UUID(), contentID: UUID(), kind: .workoutTemplate, name: "Bad",
            contentVersion: 1, selectionOrder: 0, dependencyIDs: [], payload: Data("bad".utf8)
        )
        let package = PortableTrainingPackage(
            author: .init(authorID: nil, displayName: "Coach", organization: nil),
            provenance: .init(kind: .imported, sourceIdentifier: nil, statement: nil),
            compatibility: .init(minimumAppBuild: nil, minimumSchemaVersion: 1, requiredCapabilityIDs: []),
            components: [component], dependencies: [], checksum: "tampered"
        )

        XCTAssertThrowsError(try PortableTrainingPackageImportService.apply(package: package, decisions: [], using: context))
        XCTAssertTrue(try context.fetch(FetchDescriptor<WorkoutTemplate>()).isEmpty)
    }

    func testOversizedComponentFailsBeforeDecodeOrMutation() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let component = PortableTrainingComponentDescriptor(
            componentID: UUID(), contentID: UUID(), kind: .workoutTemplate, name: "Oversized",
            contentVersion: 1, selectionOrder: 0, dependencyIDs: [],
            payload: Data(repeating: 0x41, count: PortableTrainingPackage.maximumComponentPayloadBytes + 1)
        )
        let package = PortableTrainingPackage(
            author: .init(authorID: nil, displayName: "Coach", organization: nil),
            provenance: .init(kind: .imported, sourceIdentifier: nil, statement: nil),
            compatibility: .init(minimumAppBuild: nil, minimumSchemaVersion: 1, requiredCapabilityIDs: []),
            components: [component], dependencies: []
        )

        XCTAssertThrowsError(try PortableTrainingPackageImportService.apply(package: package, decisions: [], using: context)) {
            XCTAssertEqual($0 as? PortableTrainingPackageImportError, .invalidPackage)
        }
        XCTAssertTrue(try context.fetch(FetchDescriptor<WorkoutTemplate>()).isEmpty)
    }

    func testFailureBeforeCommitRollsBackEveryInsertedDefinition() throws {
        enum Sentinel: Error { case stop }
        let sourceContext = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Squat", primaryMuscles: [.quadriceps])
        let template = WorkoutTemplate(name: "Imported", exercises: [exercise])
        sourceContext.insert(exercise)
        sourceContext.insert(template)
        try sourceContext.save()
        let source = try PortableTrainingPackageAssemblyProjection.source(template: template)
        let package = try makePackage(source: source)

        let targetContext = try GymTrackerTestStore.makeInMemoryContext()
        targetContext.insert(Exercise(name: "Squat", primaryMuscles: [.quadriceps], id: exercise.id))
        try targetContext.save()

        XCTAssertThrowsError(try PortableTrainingPackageImportService.apply(
            package: package,
            decisions: [],
            beforeCommit: { throw Sentinel.stop },
            using: targetContext
        ))
        XCTAssertTrue(try targetContext.fetch(FetchDescriptor<WorkoutTemplate>()).isEmpty)
    }

    func testTemplateImportPreservesBlockMembershipAndRemapsLocalGroupIdentity() throws {
        let sourceContext = try GymTrackerTestStore.makeInMemoryContext()
        let firstExercise = Exercise(name: "Clean", primaryMuscles: [.quadriceps])
        let secondExercise = Exercise(name: "Jerk", primaryMuscles: [.frontDeltoid])
        let groupID = UUID()
        let first = TemplateExercise(exercise: firstExercise, order: 0, supersetGroupID: groupID)
        let second = TemplateExercise(exercise: secondExercise, order: 1, supersetGroupID: groupID)
        let block = TemplateExerciseBlock(orderIndex: 0, kind: .forTime, name: "Complex")
        first.executionBlockID = block.id
        first.executionBlockComponentOrder = 0
        second.executionBlockID = block.id
        second.executionBlockComponentOrder = 1
        let template = WorkoutTemplate(name: "Complex", exercises: [], templateExercises: [first, second])
        template.executionBlocks = [block]
        sourceContext.insert(firstExercise)
        sourceContext.insert(secondExercise)
        sourceContext.insert(template)
        try sourceContext.save()
        let source = try PortableTrainingPackageAssemblyProjection.source(template: template)
        let package = try makePackage(source: source)

        let targetContext = try GymTrackerTestStore.makeInMemoryContext()
        targetContext.insert(Exercise(name: "Clean", primaryMuscles: [.quadriceps], id: firstExercise.id))
        targetContext.insert(Exercise(name: "Jerk", primaryMuscles: [.frontDeltoid], id: secondExercise.id))
        try targetContext.save()
        _ = try PortableTrainingPackageImportService.apply(package: package, decisions: [], using: targetContext)

        let imported = try XCTUnwrap(targetContext.fetch(FetchDescriptor<WorkoutTemplate>()).first)
        let importedBlock = try XCTUnwrap(imported.orderedExecutionBlocks.first)
        XCTAssertNotEqual(importedBlock.id, block.id)
        XCTAssertEqual(imported.orderedTemplateExercises.map(\.executionBlockID), [importedBlock.id, importedBlock.id])
        XCTAssertEqual(imported.orderedTemplateExercises.map(\.executionBlockComponentOrder), [0, 1])
        XCTAssertEqual(Set(imported.orderedTemplateExercises.compactMap(\.supersetGroupID)).count, 1)
        XCTAssertNotEqual(imported.orderedTemplateExercises.first?.supersetGroupID, groupID)
    }

    func testNewerBundledDefinitionMaySafelyUpdateMatchingBuiltInIdentity() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Squat", primaryMuscles: [.quadriceps])
        let existing = WorkoutTemplate(name: "Bundled v1", exercises: [exercise], isBuiltIn: true)
        context.insert(exercise)
        context.insert(existing)
        try context.save()

        let incomingRow = TemplateExercise(exercise: exercise, order: 0, targetSets: 5)
        let incoming = WorkoutTemplate(name: "Bundled v2", exercises: [], templateExercises: [incomingRow], isBuiltIn: true)
        incoming.id = existing.id
        let rawSource = try PortableTrainingPackageAssemblyProjection.source(template: incoming)
        let source = PortableTrainingAssemblySource(
            componentID: rawSource.componentID,
            contentID: rawSource.contentID,
            kind: rawSource.kind,
            name: rawSource.name,
            contentVersion: 2,
            payload: rawSource.payload,
            dependencies: rawSource.dependencies
        )
        let package = try makePackage(
            source: source,
            provenance: .init(kind: .bundled, sourceIdentifier: "trame.catalog", statement: nil)
        )

        let result = try PortableTrainingPackageImportService.apply(
            package: package,
            decisions: [.init(componentID: source.componentID, resolution: .updateExisting)],
            using: context
        )

        XCTAssertEqual(result.updatedComponentIDs, [source.componentID])
        let updated = try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutTemplate>()).first)
        XCTAssertEqual(updated.id, existing.id)
        XCTAssertEqual(updated.name, "Bundled v2")
        XCTAssertEqual(updated.orderedTemplateExercises.first?.targetSets, 5)
        XCTAssertTrue(updated.isBuiltIn)
    }

    func testRepeatingPlanAndTemplateImportInDependencyOrder() throws {
        let sourceContext = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Squat", primaryMuscles: [.quadriceps])
        let template = WorkoutTemplate(name: "Day A", exercises: [exercise])
        let plan = RepeatingPlan(
            name: "Alternating strength",
            slots: [RepeatingPlanSlot(orderIndex: 0, workoutTemplate: template)]
        )
        sourceContext.insert(exercise)
        sourceContext.insert(template)
        sourceContext.insert(plan)
        try sourceContext.save()
        let templateSource = try PortableTrainingPackageAssemblyProjection.source(template: template)
        let planSource = try PortableTrainingPackageAssemblyProjection.source(repeatingPlan: plan)
        let package = try PortableTrainingPackageAssemblyProjection.assemble(
            selection: .init(componentIDs: [planSource.componentID, templateSource.componentID]),
            sources: [planSource, templateSource],
            author: .init(authorID: nil, displayName: "Coach", organization: nil),
            provenance: .init(kind: .imported, sourceIdentifier: "test", statement: nil),
            compatibility: .init(minimumAppBuild: nil, minimumSchemaVersion: 1, requiredCapabilityIDs: [])
        )

        let targetContext = try GymTrackerTestStore.makeInMemoryContext()
        targetContext.insert(Exercise(name: "Squat", primaryMuscles: [.quadriceps], id: exercise.id))
        try targetContext.save()
        let result = try PortableTrainingPackageImportService.apply(package: package, decisions: [], using: targetContext)

        XCTAssertEqual(Set(result.insertedComponentIDs), Set([template.id, plan.id]))
        let importedTemplate = try XCTUnwrap(targetContext.fetch(FetchDescriptor<WorkoutTemplate>()).first)
        let importedPlan = try XCTUnwrap(targetContext.fetch(FetchDescriptor<RepeatingPlan>()).first)
        XCTAssertEqual(importedPlan.orderedSlots.first?.workoutTemplate?.id, importedTemplate.id)
        XCTAssertEqual(importedPlan.orderedSlots.first?.templateIDSnapshot, importedTemplate.id)
    }

    func testVersionedProgramPayloadImportsThroughExistingRepository() throws {
        let sourceContext = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Squat", primaryMuscles: [.quadriceps])
        sourceContext.insert(exercise)
        let payload = ProgramDefinitionFixture.stage(exerciseID: exercise.id)
        let record = try ProgramDefinitionRepository.save(payload, isBuiltIn: false, in: sourceContext)
        try sourceContext.save()
        let source = try PortableTrainingPackageAssemblyProjection.source(record: record)
        let package = try makePackage(source: source)

        let targetContext = try GymTrackerTestStore.makeInMemoryContext()
        targetContext.insert(Exercise(name: "Squat", primaryMuscles: [.quadriceps], id: exercise.id))
        try targetContext.save()
        _ = try PortableTrainingPackageImportService.apply(package: package, decisions: [], using: targetContext)

        let imported = try XCTUnwrap(targetContext.fetch(FetchDescriptor<ProgramDefinitionRecord>()).first)
        XCTAssertEqual(imported.id, payload.id)
        XCTAssertEqual(try imported.payload(), payload)
        XCTAssertFalse(imported.isBuiltIn)
    }

    private func makePackage(
        source: PortableTrainingAssemblySource,
        provenance: PortableTrainingProvenance = .init(kind: .imported, sourceIdentifier: "test", statement: nil)
    ) throws -> PortableTrainingPackage {
        try PortableTrainingPackageAssemblyProjection.assemble(
            selection: PortableTrainingPackageSelection(componentIDs: [source.componentID]),
            sources: [source],
            author: PortableTrainingAuthor(authorID: nil, displayName: "Coach", organization: nil),
            provenance: provenance,
            compatibility: PortableTrainingCompatibility(minimumAppBuild: nil, minimumSchemaVersion: 1, requiredCapabilityIDs: [])
        )
    }
}

#endif
