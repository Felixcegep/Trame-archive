import AppIntents
import Foundation
import SwiftData

/// A deliberately small system-facing representation. The app remains the
/// source of truth; this entity exists only so Siri and Shortcuts can resolve
/// an exercise name when a lifter asks for prior performance.
struct ExerciseIntentEntity: AppEntity, Identifiable, Hashable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Exercise")
    static let defaultQuery = ExerciseIntentQuery()

    let id: UUID
    let name: String
    let equipment: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(equipment)")
    }
}

struct ExerciseIntentQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [ExerciseIntentEntity] {
        await MainActor.run {
            guard let container = GymTrackerModelContainer.shared else { return [] }
            let context = ModelContext(container)
            let requested = Set(identifiers)
            let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
            return exercises
                .filter { requested.contains($0.id) && !$0.isArchived }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                .map(ExerciseIntentEntity.init)
        }
    }

    func entities(matching string: String) async throws -> [ExerciseIntentEntity] {
        await MainActor.run {
            guard let container = GymTrackerModelContainer.shared else { return [] }
            let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines)
            let exercises = (try? ModelContext(container)
                .fetch(FetchDescriptor<Exercise>())) ?? []
            return exercises
                .filter { exercise in
                    !exercise.isArchived && (
                        normalized.isEmpty
                        || exercise.name.localizedCaseInsensitiveContains(normalized)
                        || exercise.tags.contains { $0.localizedCaseInsensitiveContains(normalized) }
                    )
                }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                .prefix(20)
                .map(ExerciseIntentEntity.init)
        }
    }

    func suggestedEntities() async throws -> [ExerciseIntentEntity] {
        try await entities(matching: "")
    }
}

private extension ExerciseIntentEntity {
    init(_ exercise: Exercise) {
        id = exercise.id
        name = exercise.name
        equipment = exercise.equipmentType?.rawValue ?? "Exercise"
    }
}

enum RestShortcutAction: String, AppEnum {
    case pause
    case resume
    case skip
    case addThirtySeconds

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Rest action")
    static let caseDisplayRepresentations: [RestShortcutAction: DisplayRepresentation] = [
        .pause: DisplayRepresentation(title: "Pause"),
        .resume: DisplayRepresentation(title: "Resume"),
        .skip: DisplayRepresentation(title: "Skip"),
        .addThirtySeconds: DisplayRepresentation(title: "Add 30 seconds")
    ]
}

struct StartTodaysWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Start today's workout"
    static let description = IntentDescription("Starts today's planned workout, or a free workout when no plan is due.")
    static let openAppWhenRun = true

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let container = GymTrackerModelContainer.shared else {
            return .result(dialog: "GymTracker data is temporarily unavailable.")
        }
        let context = ModelContext(container)
        guard let workout = WorkoutIntentService.startToday(using: context) else {
            return .result(dialog: "GymTracker could not start a workout.")
        }
        AppIntentRouteStore.shared.submit(.activeWorkout(workout.id))
        return .result(dialog: "Your workout is ready.")
    }
}

struct ShowTodayPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Show today's plan"
    static let description = IntentDescription("Shows the active workout or the workout scheduled for today.")

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let container = GymTrackerModelContainer.shared else {
            return .result(dialog: "GymTracker data is temporarily unavailable.")
        }
        let context = ModelContext(container)
        let plan = WorkoutIntentProjectionService.todayPlan(using: context)
        switch plan.state {
        case .activeWorkout:
            let current = plan.exercises.first(where: \.isCurrent)?.name
            let currentText = current.map { " Current exercise: \($0)." } ?? ""
            return .result(dialog: "\(plan.title) is active. \(plan.completedSetCount) of \(plan.totalSetCount) sets completed.\(currentText)")
        case .scheduledWorkout:
            let names = plan.exercises.prefix(4).map(\.name).joined(separator: ", ")
            let remainder = plan.exercises.count > 4 ? " and \(plan.exercises.count - 4) more" : ""
            let planText = plan.planName.map { " from \($0)" } ?? ""
            return .result(dialog: "Today: \(plan.title)\(planText). \(plan.exercises.count) exercises and \(plan.totalSetCount) prescribed sets: \(names)\(remainder).")
        case .noWorkout:
            return .result(dialog: "There is no workout scheduled today.")
        }
    }
}

struct StartFreeWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Start free workout"
    static let description = IntentDescription("Starts an unplanned workout or resumes the current active workout.")
    static let openAppWhenRun = true

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let container = GymTrackerModelContainer.shared else {
            return .result(dialog: "GymTracker data is temporarily unavailable.")
        }
        let context = ModelContext(container)
        let result = WorkoutIntentService.startFree(using: context)
        guard let workout = result.workout else {
            return .result(dialog: "GymTracker could not start a free workout.")
        }
        AppIntentRouteStore.shared.submit(.activeWorkout(workout.id))
        switch result {
        case .started:
            return .result(dialog: "Free workout started.")
        case .resumed:
            return .result(dialog: "Resuming your active workout.")
        case .failed:
            return .result(dialog: "GymTracker could not start a free workout.")
        }
    }
}

struct ShowWeeklyVolumeIntent: AppIntent {
    static let title: LocalizedStringResource = "Show weekly volume"
    static let description = IntentDescription("Summarizes eligible completed strength work from the current local week.")
    static var parameterSummary: some ParameterSummary {
        Summary("Show weekly volume") {
            \.$scope
        }
    }

    @Parameter(title: "Scope") var scope: WeeklyVolumeScope
    @Parameter(title: "Exercise") var exercise: ExerciseIntentEntity?
    @Parameter(title: "Muscle group") var muscleGroup: MuscleGroupIntentOption?

    init() {
        scope = .total
        exercise = nil
        muscleGroup = nil
    }

    init(scope: WeeklyVolumeScope, exercise: ExerciseIntentEntity? = nil, muscleGroup: MuscleGroupIntentOption? = nil) {
        self.scope = scope
        self.exercise = exercise
        self.muscleGroup = muscleGroup
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard scope != .exercise || exercise != nil else {
            return .result(dialog: "Choose an exercise for an exercise volume summary.")
        }
        guard scope != .muscleGroup || muscleGroup != nil else {
            return .result(dialog: "Choose a muscle group for a muscle-group volume summary.")
        }

        guard let container = GymTrackerModelContainer.shared else {
            return .result(dialog: "GymTracker data is temporarily unavailable.")
        }
        let context = ModelContext(container)
        let unit: WeightType = UserDefaults.standard.unitSystem == .metric ? .kg : .lbs
        let projection = WorkoutIntentProjectionService.weeklyVolume(
            using: context,
            scope: scope,
            exerciseID: exercise?.id,
            muscleGroup: muscleGroup?.muscles,
            preferredUnit: unit
        )
        guard projection.completedWorkoutCount > 0 else {
            return .result(dialog: "No eligible completed strength work was recorded this week.")
        }

        switch scope {
        case .muscleGroup:
            let name = muscleGroup?.displayName ?? "this muscle group"
            let estimate = Formatters.formatFloat(projection.muscleGroupSetEstimate ?? 0)
            return .result(dialog: "\(name) this week: an estimated \(estimate) working-set contributions across \(projection.completedWorkoutCount) workouts.")
        case .total, .exercise:
            guard let volume = projection.loadVolume, let unit = projection.unit else {
                return .result(dialog: "This week includes \(projection.workingSetCount) eligible working sets, but no load volume is available.")
            }
            let subject = projection.subjectName.map { "\($0) " } ?? ""
            return .result(dialog: "\(subject)this week: \(projection.completedWorkoutCount) workouts, \(projection.workingSetCount) working sets, and \(Formatters.formatFloat(volume)) \(unit.rawValue) of completed volume.")
        }
    }
}

struct LogCurrentSetIntent: AppIntent {
    static let title: LocalizedStringResource = "Log current set"
    static let description = IntentDescription("Logs and completes the next set in the active workout.")

    @Parameter(title: "Repetitions") var repetitions: Int?
    /// Weight uses the unit already displayed on the current set. A full
    /// measurement parameter can be added later without changing persisted
    /// workout truth or shortcut phrases.
    @Parameter(title: "Weight") var weight: Double?
    @Parameter(title: "RPE") var rpe: Double?
    @Parameter(title: "RIR") var rir: Int?

    init() {}

    init(repetitions: Int? = nil, weight: Double? = nil, rpe: Double? = nil, rir: Int? = nil) {
        self.repetitions = repetitions
        self.weight = weight
        self.rpe = rpe
        self.rir = rir
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let container = GymTrackerModelContainer.shared else {
            return .result(dialog: "GymTracker data is temporarily unavailable.")
        }
        let context = ModelContext(container)
        guard let workout = WorkoutIntentService.activeWorkout(using: context) else {
            return .result(dialog: "There is no active workout to log.")
        }
        let result = ActiveWorkoutMutationService(modelContext: context).logCurrentSet(
            workoutID: workout.id,
            log: .init(repetitions: repetitions, weight: weight, rpe: rpe, rir: rir)
        )
        await WorkoutIntentService.reconcile(result)

        switch result {
        case .applied:
            return .result(dialog: "Set logged. Rest is ready when you are.")
        case .invalid:
            return .result(dialog: "GymTracker needs valid values for the current set before it can log it.")
        case .stale:
            return .result(dialog: "That set is no longer current. Check your active workout.")
        case .unavailable:
            return .result(dialog: "There is no active workout to log.")
        }
    }
}

struct ControlRestIntent: AppIntent {
    static let title: LocalizedStringResource = "Control rest"
    static let description = IntentDescription("Pauses, resumes, skips, or extends the rest timer in the active workout.")
    static var parameterSummary: some ParameterSummary {
        Summary("Control rest") {
            \.$action
        }
    }

    @Parameter(title: "Action") var action: RestShortcutAction

    init() {
        action = .pause
    }

    init(action: RestShortcutAction) {
        self.action = action
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let container = GymTrackerModelContainer.shared else {
            return .result(dialog: "GymTracker data is temporarily unavailable.")
        }
        let context = ModelContext(container)
        guard let workout = WorkoutIntentService.activeWorkout(using: context) else {
            return .result(dialog: "There is no active workout with a rest timer.")
        }
        let service = ActiveWorkoutMutationService(modelContext: context)
        let result: ActiveWorkoutMutationService.Result
        switch action {
        case .pause:
            result = service.pauseRest(workoutID: workout.id)
        case .resume:
            result = service.resumeRest(workoutID: workout.id)
        case .skip:
            result = service.skipRest(workoutID: workout.id)
        case .addThirtySeconds:
            result = service.extendRest(workoutID: workout.id, by: 30)
        }
        await WorkoutIntentService.reconcile(result)

        switch result {
        case .applied:
            return .result(dialog: restSuccessMessage)
        case .invalid, .stale:
            return .result(dialog: "That rest action is not available right now.")
        case .unavailable:
            return .result(dialog: "There is no active workout with a rest timer.")
        }
    }

    private var restSuccessMessage: IntentDialog {
        switch action {
        case .pause: "Rest paused."
        case .resume: "Rest resumed."
        case .skip: "Rest skipped."
        case .addThirtySeconds: "Added 30 seconds to rest."
        }
    }
}

struct ViewPreviousPerformanceIntent: AppIntent {
    static let title: LocalizedStringResource = "View previous performance"
    static let description = IntentDescription("Shows the latest completed performance for an exercise.")
    static var parameterSummary: some ParameterSummary {
        Summary("Show previous performance") {
            \.$exercise
        }
    }

    @Parameter(title: "Exercise") var exercise: ExerciseIntentEntity?

    init() {}

    init(exercise: ExerciseIntentEntity?) {
        self.exercise = exercise
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let container = GymTrackerModelContainer.shared else {
            return .result(dialog: "GymTracker data is temporarily unavailable.")
        }
        let context = ModelContext(container)
        let selectedExercise = exercise ?? activeExerciseEntity(using: context)
        guard let selectedExercise else {
            return .result(dialog: "Choose an exercise to view its previous performance.")
        }
        guard let exercise = (try? context.fetch(FetchDescriptor<Exercise>()))?
            .first(where: { $0.id == selectedExercise.id && !$0.isArchived })
        else {
            return .result(dialog: "That exercise is no longer available.")
        }
        guard let performance = try? ExerciseHistoryService(modelContext: context)
            .mostRecentPerformance(for: exercise, before: .now)
        else {
            return .result(dialog: "No completed performance was found for \(exercise.name).")
        }

        let sets = performance.sets.map { set in
            "\(Int(set.repetitions)) reps at \(set.weight.formatted(.number.precision(.fractionLength(0...2)))) \(set.weightType.rawValue)"
        }.joined(separator: ", ")
        return .result(dialog: "Last \(exercise.name) workout: \(sets).")
    }

    @MainActor
    private func activeExerciseEntity(using context: ModelContext) -> ExerciseIntentEntity? {
        guard let workout = WorkoutIntentService.activeWorkout(using: context),
              let entry = WorkoutSetSelector.nextIncompleteSet(in: workout)?.entry
        else {
            return nil
        }
        return ExerciseIntentEntity(entry.exercise)
    }
}

enum CaffeineDrinkAppEnum: String, AppEnum {
    case espresso
    case brewed
    case coldBrew
    case latte

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Coffee drink")
    static let caseDisplayRepresentations: [CaffeineDrinkAppEnum: DisplayRepresentation] = [
        .espresso: DisplayRepresentation(title: "Espresso"),
        .brewed: DisplayRepresentation(title: "Brewed"),
        .coldBrew: DisplayRepresentation(title: "Cold brew"),
        .latte: DisplayRepresentation(title: "Latte")
    ]

    var preset: CaffeineDrinkPreset {
        switch self {
        case .espresso: .espresso
        case .brewed: .brewed
        case .coldBrew: .coldBrew
        case .latte: .latte
        }
    }
}

enum CaffeineSizeAppEnum: String, AppEnum {
    case small
    case medium
    case large

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Size")
    static let caseDisplayRepresentations: [CaffeineSizeAppEnum: DisplayRepresentation] = [
        .small: DisplayRepresentation(title: "Small"),
        .medium: DisplayRepresentation(title: "Medium"),
        .large: DisplayRepresentation(title: "Large")
    ]

    var size: CaffeineDrinkSize {
        switch self {
        case .small: .small
        case .medium: .medium
        case .large: .large
        }
    }
}

struct LogCaffeineIntent: AppIntent {
    static let title: LocalizedStringResource = "Log caffeine"
    static let description = IntentDescription("Logs a coffee preset as a caffeine estimate.")
    static var parameterSummary: some ParameterSummary {
        Summary("Log caffeine") {
            \.$drink
            \.$size
        }
    }

    @Parameter(title: "Drink") var drink: CaffeineDrinkAppEnum
    @Parameter(title: "Size") var size: CaffeineSizeAppEnum

    init() {
        drink = .brewed
        size = .medium
    }

    init(drink: CaffeineDrinkAppEnum, size: CaffeineSizeAppEnum) {
        self.drink = drink
        self.size = size
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let container = GymTrackerModelContainer.shared else {
            return .result(dialog: "GymTracker data is temporarily unavailable.")
        }
        guard FeatureFlags.current.isCaffeineQuickLoggingAvailable else {
            return .result(dialog: "Caffeine logging is not available in this build.")
        }
        let context = ModelContext(container)
        let preset = drink.preset
        let sizeValue = size.size
        guard CaffeineLoggingService.logPreset(
            name: preset.foodName,
            defaultMediumMilligrams: preset.mediumMilligrams,
            sizedMilligrams: preset.caffeineMilligrams(for: sizeValue),
            sizeTitle: sizeValue.title,
            using: context
        ) != nil else {
            return .result(dialog: "GymTracker could not log that caffeine.")
        }
        let mg = FoodLibraryService.format(preset.caffeineMilligrams(for: sizeValue))
        return .result(dialog: "Logged \(mg) mg of caffeine.")
    }
}

struct ConfirmCreatineIntent: AppIntent {
    static let title: LocalizedStringResource = "Confirm creatine"
    static let description = IntentDescription("Marks today's creatine dose as taken.")

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let container = GymTrackerModelContainer.shared else {
            return .result(dialog: "GymTracker data is temporarily unavailable.")
        }
        let context = ModelContext(container)
        guard SupplementOccurrenceService.confirmCreatine(using: context) != nil else {
            return .result(dialog: "GymTracker could not confirm today's creatine.")
        }
        return .result(dialog: "Today's creatine is confirmed.")
    }
}

/// A deliberately small system-facing representation of a saved recipe, so
/// Siri and Shortcuts can resolve one by name without exposing ingredients.
struct MealTemplateIntentEntity: AppEntity, Identifiable, Hashable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Recipe")
    static let defaultQuery = MealTemplateIntentQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct MealTemplateIntentQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [MealTemplateIntentEntity] {
        await MainActor.run {
            guard let container = GymTrackerModelContainer.shared else { return [] }
            let requested = Set(identifiers)
            let templates = (try? ModelContext(container).fetch(FetchDescriptor<MealTemplate>())) ?? []
            return templates
                .filter { requested.contains($0.id) && eligible($0) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                .map { MealTemplateIntentEntity(id: $0.id, name: $0.name) }
        }
    }

    func entities(matching string: String) async throws -> [MealTemplateIntentEntity] {
        await MainActor.run {
            guard let container = GymTrackerModelContainer.shared else { return [] }
            let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines)
            let templates = (try? ModelContext(container).fetch(FetchDescriptor<MealTemplate>())) ?? []
            return templates
                .filter { eligible($0) && (normalized.isEmpty || $0.name.localizedCaseInsensitiveContains(normalized)) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                .prefix(20)
                .map { MealTemplateIntentEntity(id: $0.id, name: $0.name) }
        }
    }

    func suggestedEntities() async throws -> [MealTemplateIntentEntity] {
        try await entities(matching: "")
    }

    /// Non-private so `LogMealIntent`'s eligibility filtering can be verified
    /// without depending on `GymTrackerModelContainer.shared`.
    func eligible(_ template: MealTemplate) -> Bool {
        template.isArchived == false && template.isCurrent && template.orderedItems.isEmpty == false
    }
}

struct LogMealIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a meal"
    static let description = IntentDescription("Logs a saved recipe to today's meals.")
    static var parameterSummary: some ParameterSummary {
        Summary("Log a meal") {
            \.$meal
        }
    }

    @Parameter(title: "Recipe") var meal: MealTemplateIntentEntity

    init() {}

    init(meal: MealTemplateIntentEntity) {
        self.meal = meal
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let container = GymTrackerModelContainer.shared else {
            return .result(dialog: "GymTracker data is temporarily unavailable.")
        }
        guard FeatureFlags.current.isEnabled(.nutrition) else {
            return .result(dialog: "Nutrition logging is not available in this build.")
        }
        let context = ModelContext(container)
        guard let template = (try? context.fetch(FetchDescriptor<MealTemplate>()))?
            .first(where: { $0.id == meal.id && $0.isArchived == false && $0.isCurrent })
        else {
            return .result(dialog: "\(meal.name) is no longer available.")
        }
        guard NutritionLoggingService.log(template: template, using: context) != nil else {
            return .result(dialog: "GymTracker could not log \(template.name).")
        }
        let totals = MealTemplateNutrition.totals(for: template)
        let calories = FoodLibraryService.format(totals.calories)
        return .result(dialog: "Logged \(template.name) — \(calories) kcal.")
    }
}

/// A deliberately small system-facing representation of a mobility routine,
/// so Siri and Shortcuts can resolve one by name without exposing its items.
struct MobilityRoutineIntentEntity: AppEntity, Identifiable, Hashable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Mobility routine")
    static let defaultQuery = MobilityRoutineIntentQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct MobilityRoutineIntentQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [MobilityRoutineIntentEntity] {
        await MainActor.run {
            guard let container = GymTrackerModelContainer.shared else { return [] }
            let requested = Set(identifiers)
            let routines = (try? ModelContext(container).fetch(FetchDescriptor<MobilityRoutine>())) ?? []
            return routines
                .filter { requested.contains($0.id) && eligible($0) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                .map { MobilityRoutineIntentEntity(id: $0.id, name: $0.name) }
        }
    }

    func entities(matching string: String) async throws -> [MobilityRoutineIntentEntity] {
        await MainActor.run {
            guard let container = GymTrackerModelContainer.shared else { return [] }
            let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines)
            let routines = (try? ModelContext(container).fetch(FetchDescriptor<MobilityRoutine>())) ?? []
            return routines
                .filter { eligible($0) && (normalized.isEmpty || $0.name.localizedCaseInsensitiveContains(normalized)) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                .prefix(20)
                .map { MobilityRoutineIntentEntity(id: $0.id, name: $0.name) }
        }
    }

    func suggestedEntities() async throws -> [MobilityRoutineIntentEntity] {
        try await entities(matching: "")
    }

    /// Non-private so `StartMobilityRoutineIntent`'s eligibility filtering
    /// can be verified without depending on `GymTrackerModelContainer.shared`.
    func eligible(_ routine: MobilityRoutine) -> Bool {
        routine.isArchived == false && routine.orderedItems.isEmpty == false
    }
}

struct StartMobilityRoutineIntent: AppIntent {
    static let title: LocalizedStringResource = "Start mobility routine"
    static let description = IntentDescription("Starts a mobility routine, or resumes the current active session.")
    static let openAppWhenRun = true
    static var parameterSummary: some ParameterSummary {
        Summary("Start mobility routine") {
            \.$routine
        }
    }

    @Parameter(title: "Routine") var routine: MobilityRoutineIntentEntity?

    init() {}

    init(routine: MobilityRoutineIntentEntity? = nil) {
        self.routine = routine
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let container = GymTrackerModelContainer.shared else {
            return .result(dialog: "GymTracker data is temporarily unavailable.")
        }
        guard FeatureFlags.current.isEnabled(.mobility) else {
            return .result(dialog: "Mobility is not available in this build.")
        }
        let context = ModelContext(container)

        if let activeSession = MobilitySessionService.activeSession(using: context) {
            AppIntentRouteStore.shared.submit(.activeMobility(activeSession.id))
            return .result(dialog: "Resuming \(activeSession.nameSnapshot).")
        }

        let resolvedRoutine: MobilityRoutine?
        if let routine {
            resolvedRoutine = (try? context.fetch(FetchDescriptor<MobilityRoutine>()))?
                .first(where: { $0.id == routine.id && $0.isArchived == false && $0.orderedItems.isEmpty == false })
        } else {
            resolvedRoutine = (try? context.fetch(FetchDescriptor<MobilityRoutine>()))?
                .first(where: { $0.isArchived == false && $0.orderedItems.isEmpty == false })
        }
        guard let resolvedRoutine else {
            return .result(dialog: "No mobility routine is available to start.")
        }
        guard let session = MobilitySessionService.start(routine: resolvedRoutine, using: context) else {
            return .result(dialog: "GymTracker could not start that mobility routine.")
        }
        AppIntentRouteStore.shared.submit(.activeMobility(session.id))
        return .result(dialog: "\(resolvedRoutine.name) is ready.")
    }
}

struct GymTrackerAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ShowTodayPlanIntent(),
            phrases: [
                "Show today's workout in \(.applicationName)",
                "What is my workout today with \(.applicationName)"
            ],
            shortTitle: "Today's plan",
            systemImageName: "calendar"
        )
        AppShortcut(
            intent: StartTodaysWorkoutIntent(),
            phrases: [
                "Start my workout with \(.applicationName)",
                "Start today's workout in \(.applicationName)"
            ],
            shortTitle: "Start workout",
            systemImageName: "figure.strengthtraining.traditional"
        )
        AppShortcut(
            intent: StartFreeWorkoutIntent(),
            phrases: [
                "Start a free workout with \(.applicationName)",
                "Start an unplanned workout in \(.applicationName)"
            ],
            shortTitle: "Start free workout",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: LogCurrentSetIntent(),
            phrases: ["Log my current set with \(.applicationName)"],
            shortTitle: "Log current set",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: ControlRestIntent(action: .pause),
            phrases: ["Pause my rest in \(.applicationName)"],
            shortTitle: "Pause rest",
            systemImageName: "pause.fill"
        )
        AppShortcut(
            intent: ControlRestIntent(action: .resume),
            phrases: ["Resume my rest in \(.applicationName)"],
            shortTitle: "Resume rest",
            systemImageName: "play.fill"
        )
        AppShortcut(
            intent: ControlRestIntent(action: .skip),
            phrases: ["Skip my rest in \(.applicationName)"],
            shortTitle: "Skip rest",
            systemImageName: "forward.fill"
        )
        AppShortcut(
            intent: ControlRestIntent(action: .addThirtySeconds),
            phrases: ["Add 30 seconds to my rest in \(.applicationName)"],
            shortTitle: "Add 30 seconds",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: ViewPreviousPerformanceIntent(),
            phrases: ["Show my previous performance in \(.applicationName)"],
            shortTitle: "Previous performance",
            systemImageName: "chart.line.uptrend.xyaxis"
        )
        AppShortcut(
            intent: ShowWeeklyVolumeIntent(),
            phrases: [
                "Show my weekly volume in \(.applicationName)",
                "How much training volume did I do this week with \(.applicationName)"
            ],
            shortTitle: "Weekly volume",
            systemImageName: "chart.bar"
        )
    }
}
