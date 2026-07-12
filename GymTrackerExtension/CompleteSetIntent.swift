import AppIntents
import ActivityKit
import SwiftData

struct CompleteSetIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Complete set"
    static var description = IntentDescription("Completes the current set from the Lock Screen.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        let container = try ModelContainer(
            for: Workout.self,
            ExerciceTemplate.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            WorkoutCollection.self,
            ExerciceEntry.self,
            ExerciseSet.self,
            WorkoutPlan.self,
            PlanBlock.self,
            PlanWeek.self,
            PlannedWorkout.self,
            PlannedExercise.self,
            PlanRun.self,
            PlanWorkoutProgress.self
        )
        let context = ModelContext(container)
        let workouts = try context.fetch(FetchDescriptor<Workout>())

        guard
            let workout = workouts
                .filter({ $0.status == .active })
                .max(by: { $0.startTime < $1.startTime }),
            let exercise = workout.orderedExercises.first(where: { $0.orderedSets.contains(where: { !$0.done }) }),
            let set = exercise.orderedSets.first(where: { !$0.done })
        else {
            return .result()
        }

        set.done = true

        let nextExercise = workout.orderedExercises.first(where: { $0.orderedSets.contains(where: { !$0.done }) })
        let restEndDate: Date?
        if nextExercise != nil {
            let defaults = UserDefaults.standard
            let savedDuration = defaults.integer(forKey: DefaultsKey.restTimer)
            let restDuration = defaults.object(forKey: DefaultsKey.restTimer) != nil && savedDuration > 0
                ? savedDuration
                : 20
            restEndDate = Date.now.addingTimeInterval(TimeInterval(restDuration))
        } else {
            restEndDate = nil
        }
        workout.restEndDate = restEndDate

        try context.save()

        if let nextExercise,
           let nextSetIndex = nextExercise.orderedSets.firstIndex(where: { !$0.done }) {
            await updateActivity(
                exerciseName: nextExercise.exercice.name,
                currentSet: nextSetIndex + 1,
                totalSets: nextExercise.orderedSets.count,
                restEndDate: restEndDate
            )
        } else {
            await updateActivity(
                exerciseName: exercise.exercice.name,
                currentSet: exercise.orderedSets.count,
                totalSets: exercise.orderedSets.count,
                restEndDate: nil
            )
        }

        return .result()
    }

    private func updateActivity(
        exerciseName: String,
        currentSet: Int,
        totalSets: Int,
        restEndDate: Date?
    ) async {
        let state = GymTrackerAttributes.ContentState(
            currentExerciseName: exerciseName,
            currentSerie: currentSet,
            totalSeries: totalSets,
            restTimeActive: restEndDate != nil,
            RestTime: restEndDate
        )

        await Activity<GymTrackerAttributes>.activities.first?.update(
            ActivityContent(state: state, staleDate: nil)
        )
    }
}
