import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class DailySupportIntentServiceTests: XCTestCase {

    // MARK: - Caffeine

    func testLogPresetCreatesFoodAndLoggedMealWithSizedMilligrams() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()

        let meal = CaffeineLoggingService.logPreset(
            name: "Coffee · Brewed",
            defaultMediumMilligrams: 145,
            sizedMilligrams: 190,
            sizeTitle: "Large",
            using: context
        )

        let loggedMeal = try XCTUnwrap(meal)
        let caffeineMilligrams = try XCTUnwrap(loggedMeal.orderedItems.first?.caffeineMilligramsSnapshot)
        XCTAssertEqual(caffeineMilligrams, 190, accuracy: 0.001)
        let foods = try context.fetch(FetchDescriptor<FoodItem>())
        XCTAssertEqual(foods.count, 1)
        XCTAssertEqual(foods.first?.name, "Coffee · Brewed")
    }

    func testLogPresetReusesExistingFoodInsteadOfDuplicating() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let existing = FoodItem(name: "Coffee · Espresso", referenceAmount: 1, referenceUnit: .serving, caffeineMilligrams: 94, sourceKind: .curated, confidence: .estimated, preparationState: .cooked)
        existing.isArchived = true
        context.insert(existing)
        try context.save()

        _ = CaffeineLoggingService.logPreset(
            name: "Coffee · Espresso",
            defaultMediumMilligrams: 94,
            sizedMilligrams: 47,
            sizeTitle: "Small",
            using: context
        )

        let foods = try context.fetch(FetchDescriptor<FoodItem>())
        XCTAssertEqual(foods.count, 1, "Logging a known preset by name must reuse the existing food, never duplicate it")
        XCTAssertFalse(try XCTUnwrap(foods.first).isArchived, "Reusing a food for a new log must un-archive it")
    }

    // MARK: - Creatine

    func testConfirmCreatineCreatesOneCompletedOccurrence() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()

        let occurrence = SupplementOccurrenceService.confirmCreatine(using: context)

        XCTAssertEqual(occurrence?.status, .completed)
        let occurrences = try context.fetch(FetchDescriptor<SupplementOccurrence>())
        XCTAssertEqual(occurrences.count, 1)
    }

    func testConfirmCreatineIsIdempotent() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()

        _ = SupplementOccurrenceService.confirmCreatine(using: context)
        _ = SupplementOccurrenceService.confirmCreatine(using: context)

        let occurrences = try context.fetch(FetchDescriptor<SupplementOccurrence>())
        XCTAssertEqual(occurrences.count, 1, "Confirming creatine twice must update the same day's occurrence, not create a second one")
        XCTAssertEqual(occurrences.first?.status, .completed)
    }

    func testPromotedCaffeineShortcutUsesAStablePreconfiguredPreset() {
        let intent = LogCaffeineIntent()

        XCTAssertEqual(intent.drink, .brewed)
        XCTAssertEqual(intent.size, .medium)
        XCTAssertEqual(
            intent.drink.preset.caffeineMilligrams(for: intent.size.size),
            intent.drink.preset.mediumMilligrams,
            accuracy: 0.001
        )
    }

    // MARK: - Meal logging
    //
    // `LogMealIntent.perform()` and `MealTemplateIntentQuery.entities(matching:)`
    // resolve `GymTrackerModelContainer.shared` — the process-wide app
    // container, not an injectable test context — so, matching this test
    // target's existing convention for the workout intents (which never call
    // `.perform()`/`.entities(matching:)` either), coverage here targets the
    // new eligibility predicate directly instead of touching that singleton.

    func testMealTemplateEligibilityExcludesArchivedAndSupersededTemplates() throws {
        let food = FoodItem(name: "Rice", referenceAmount: 100, referenceUnit: .grams, calories: 130, sourceKind: .curated, confidence: .estimated, preparationState: .cooked)

        let current = MealTemplate(name: "Rice bowl")
        current.items = [MealTemplateItem(food: food, orderIndex: 0)]

        let archived = MealTemplate(name: "Old rice bowl")
        archived.items = [MealTemplateItem(food: food, orderIndex: 0)]
        archived.isArchived = true

        let superseded = MealTemplate(name: "Superseded rice bowl", isCurrent: false)
        superseded.items = [MealTemplateItem(food: food, orderIndex: 0)]

        let empty = MealTemplate(name: "Empty template")

        let query = MealTemplateIntentQuery()
        XCTAssertTrue(query.eligible(current))
        XCTAssertFalse(query.eligible(archived))
        XCTAssertFalse(query.eligible(superseded))
        XCTAssertFalse(query.eligible(empty))
    }

    func testNutritionLoggingServiceLogsTemplateWithScaledItems() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let food = FoodItem(name: "Oats", referenceAmount: 100, referenceUnit: .grams, calories: 389, sourceKind: .curated, confidence: .estimated, preparationState: .raw)
        context.insert(food)
        let template = MealTemplate(name: "Breakfast bowl")
        template.items = [MealTemplateItem(food: food, orderIndex: 0, quantity: 0.8)]
        context.insert(template)
        try context.save()

        let logged = NutritionLoggingService.log(template: template, using: context)

        let loggedMeal = try XCTUnwrap(logged)
        XCTAssertEqual(loggedMeal.orderedItems.count, 1)
        XCTAssertEqual(loggedMeal.nameSnapshot, "Breakfast bowl")
    }

    // MARK: - Mobility
    //
    // Same constraint as above: `StartMobilityRoutineIntent.perform()` and
    // `MobilityRoutineIntentQuery.entities(matching:)` depend on
    // `GymTrackerModelContainer.shared`. Coverage targets the new eligibility
    // predicate directly; the existing `MobilitySessionService` start/resume
    // behavior this intent reuses is exercised by its own test suite.

    func testMobilityRoutineEligibilityExcludesArchivedAndEmptyRoutines() throws {
        let definition = MobilityDefinition(name: "Cat-cow", trackingType: .repetitions, defaultDurationSeconds: nil, defaultRepetitions: 10)

        let usable = MobilityRoutine(name: "Spine mobility")
        usable.items = [MobilityRoutineItem(definition: definition, orderIndex: 0, targetRepetitions: 10)]

        let archived = MobilityRoutine(name: "Old spine mobility", isArchived: true)
        archived.items = [MobilityRoutineItem(definition: definition, orderIndex: 0, targetRepetitions: 10)]

        let empty = MobilityRoutine(name: "Empty spine mobility")

        let query = MobilityRoutineIntentQuery()
        XCTAssertTrue(query.eligible(usable))
        XCTAssertFalse(query.eligible(archived))
        XCTAssertFalse(query.eligible(empty))
    }

    func testActiveMobilityRouteIsConsumedOnlyOnce() {
        let store = AppIntentRouteStore.shared
        _ = store.consume()
        let sessionID = UUID()
        store.submit(.activeMobility(sessionID))

        XCTAssertEqual(store.consume(), .activeMobility(sessionID))
        XCTAssertNil(store.consume())
    }

    func testCompleteMobilityNodeRequiresPerformedRepetitionsAndRejectsStaleIdentity() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let definition = MobilityDefinition(name: "Hip rotations", trackingType: .repetitions, defaultDurationSeconds: nil, defaultRepetitions: 8)
        let routine = MobilityRoutine(name: "Hips")
        routine.items = [MobilityRoutineItem(definition: definition, orderIndex: 0, targetRepetitions: 8)]
        context.insert(routine)
        try context.save()
        let session = try XCTUnwrap(MobilitySessionService.start(routine: routine, using: context))
        let entryID = try XCTUnwrap(session.currentEntry?.id)

        XCTAssertEqual(
            MobilityIntentMutationService.completeCurrentNode(using: context),
            .needsPerformedRepetitions
        )
        XCTAssertEqual(
            MobilityIntentMutationService.completeCurrentNode(
                expectedSessionID: session.id,
                expectedEntryID: UUID(),
                performedRepetitions: 8,
                using: context
            ),
            .stale
        )
        XCTAssertEqual(
            MobilityIntentMutationService.completeCurrentNode(
                expectedSessionID: session.id,
                expectedEntryID: entryID,
                performedRepetitions: 8,
                using: context
            ),
            .applied(sessionCompleted: true)
        )
        XCTAssertEqual(session.status, .completed)
        XCTAssertEqual(session.entries.first?.results.first?.performedRepetitions, 8)
    }

    func testCompleteTimedMobilityNodeUsesPersistedTimerElapsedWithoutInventingTarget() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let definition = MobilityDefinition(name: "Hold", trackingType: .duration, defaultDurationSeconds: 60, defaultRepetitions: nil)
        let routine = MobilityRoutine(name: "Timed")
        routine.items = [MobilityRoutineItem(definition: definition, orderIndex: 0, targetDurationSeconds: 60)]
        context.insert(routine)
        try context.save()
        let session = try XCTUnwrap(MobilitySessionService.start(routine: routine, using: context))
        let now = Date(timeIntervalSince1970: 1_000)
        session.currentEntry?.timerStartedAt = now.addingTimeInterval(-17)
        try context.save()

        XCTAssertEqual(
            MobilityIntentMutationService.completeCurrentNode(now: now, using: context),
            .applied(sessionCompleted: true)
        )
        XCTAssertEqual(session.entries.first?.results.first?.performedDurationSeconds, 17)
    }
}
