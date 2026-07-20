import XCTest
@testable import GymTracker

final class TrainingCalendarModelTests: XCTestCase {
    private var calendar: Calendar!
    private var today: Date!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        today = date(2026, 7, 20, 12)
    }

    func testProjectionPairsCompletedPlanOccurrenceWithItsPerformedWorkout() {
        let completedWorkout = Workout(name: "Completed lower", endTime: date(2026, 7, 20, 11))
        completedWorkout.startTime = date(2026, 7, 20, 10)
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Strength", startDate: today)
        let progress = PlanWorkoutProgress(
            plannedWorkoutID: UUID(),
            plannedWorkoutName: "Lower body",
            weekIndex: 0,
            workoutIndex: 0,
            scheduledDate: today
        )
        progress.status = .completed
        progress.completedWorkout = completedWorkout
        run.workoutProgress = [progress]

        let projection = makeDay(planRuns: [run], workouts: [completedWorkout])

        XCTAssertEqual(projection.plannedWorkouts.count, 1)
        XCTAssertEqual(projection.plannedWorkouts.first?.completedWorkoutID, completedWorkout.id)
        XCTAssertTrue(projection.freeWorkouts.isEmpty)
        XCTAssertEqual(projection.completedWorkoutCount, 1)
    }

    func testProjectionKeepsFreeWorkoutAndDomainSummariesOnTheirOwnSections() {
        let freeWorkout = Workout(name: "Accessory", endTime: date(2026, 7, 20, 18))
        freeWorkout.startTime = date(2026, 7, 20, 17)
        let mobility = MobilitySession(nameSnapshot: "Hip mobility", startTime: date(2026, 7, 20, 9))
        mobility.status = .completed
        let meal = LoggedMeal(day: LocalDay(date: today, calendar: calendar), nameSnapshot: "Lunch")
        meal.items = [LoggedMealItem(
            sourceFoodID: nil,
            foodNameSnapshot: "Rice",
            servingNameSnapshot: "Bowl",
            quantity: 1,
            portionAmountSnapshot: 1,
            portionUnit: .serving,
            caloriesSnapshot: 500,
            proteinGramsSnapshot: 20,
            carbohydrateGramsSnapshot: 80,
            fatGramsSnapshot: 8,
            sourceKind: .userCreated,
            confidence: .userProvided,
            preparationState: .cooked,
            orderIndex: 0
        )]
        let checkIn = DailyLogEntry(day: LocalDay(date: today, calendar: calendar), status: .completed)
        let creatine = SupplementOccurrence(day: LocalDay(date: today, calendar: calendar), status: .completed)

        let projection = makeDay(
            workouts: [freeWorkout],
            mobilitySessions: [mobility],
            meals: [meal],
            checkIns: [checkIn],
            supplements: [creatine]
        )

        XCTAssertEqual(projection.freeWorkouts.map(\.id), [freeWorkout.id])
        XCTAssertEqual(projection.mobilitySessions.map(\.id), [mobility.id])
        XCTAssertEqual(projection.nutrition?.totals.calories, 500)
        XCTAssertEqual(projection.nutrition?.totals.protein, 20)
        XCTAssertEqual(projection.checkIn?.status, .completed)
        XCTAssertEqual(projection.creatine, .completed)
    }

    func testMonthContainsWholeWeeksAndRetainsMissedPlanState() {
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Strength", startDate: today)
        let missed = PlanWorkoutProgress(
            plannedWorkoutID: UUID(),
            plannedWorkoutName: "Missed session",
            weekIndex: 0,
            workoutIndex: 0,
            scheduledDate: date(2026, 7, 18, 8)
        )
        missed.status = .upcoming
        run.workoutProgress = [missed]

        let month = TrainingCalendarBuilder.month(
            containing: today,
            planRuns: [run],
            workouts: [],
            mobilitySessions: [],
            meals: [],
            checkIns: [],
            supplementOccurrences: [],
            today: today,
            calendar: calendar
        )

        XCTAssertTrue(month.weeks.allSatisfy { $0.count == 7 })
        let missedDay = try! XCTUnwrap(month.weeks.flatMap { $0 }.first { $0.day.rawValue == "2026-07-18" })
        XCTAssertEqual(missedDay.plannedWorkouts.first?.state, .missed)
    }

    func testMissingNutritionValuesRemainUnknownInsteadOfZero() {
        let meal = LoggedMeal(day: LocalDay(date: today, calendar: calendar), nameSnapshot: "Estimate")
        meal.items = [LoggedMealItem(
            sourceFoodID: nil,
            foodNameSnapshot: "Unknown food",
            servingNameSnapshot: "Serving",
            quantity: 1,
            portionAmountSnapshot: 1,
            portionUnit: .serving,
            caloriesSnapshot: nil,
            proteinGramsSnapshot: nil,
            carbohydrateGramsSnapshot: nil,
            fatGramsSnapshot: nil,
            sourceKind: .userCreated,
            confidence: .estimated,
            preparationState: .cooked,
            orderIndex: 0
        )]

        let projection = makeDay(meals: [meal])

        XCTAssertEqual(projection.nutrition?.totals.calories, 0)
        XCTAssertTrue(projection.nutrition?.totals.hasUnknownValues == true)
    }

    private func makeDay(
        planRuns: [PlanRun] = [],
        workouts: [Workout] = [],
        mobilitySessions: [MobilitySession] = [],
        meals: [LoggedMeal] = [],
        checkIns: [DailyLogEntry] = [],
        supplements: [SupplementOccurrence] = []
    ) -> TrainingCalendarDay {
        TrainingCalendarBuilder.day(
            for: today,
            planRuns: planRuns,
            workouts: workouts,
            mobilitySessions: mobilitySessions,
            meals: meals,
            checkIns: checkIns,
            supplementOccurrences: supplements,
            today: today,
            calendar: calendar
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
