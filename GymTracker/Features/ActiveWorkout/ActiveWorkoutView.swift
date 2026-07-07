import SwiftUI
import SwiftData
struct ActiveWorkoutView: View {
    @Query var exerciceTemplates: [ExerciceTemplate]
    
    let workoutVM: WorkoutViewModel
    @Binding var navigationPath: [HomeRoute]
    @State private var viewModel: ActiveWorkoutViewModel


    init(workoutVM: WorkoutViewModel, navigationPath: Binding<[HomeRoute]>) {
        self.workoutVM = workoutVM
        _navigationPath = navigationPath
        _viewModel = State(initialValue: ActiveWorkoutViewModel(workoutVM: workoutVM))
    }

    
    var body: some View {
        VStack {
            Text("Workout")
            
            if let startTime = viewModel.activeWorkout?.startTime {
                Text(startTime, style: .timer)
                    .font(.largeTitle)
                    .monospacedDigit()
            }
            
            NavigationLink("Add Exercise") {
                ExerciceLibrairyView(
                    isSelectingExercise: true,
                    availableExercises: exerciceTemplates,
                    onSelect: viewModel.addExercise
                )
            }

            if let workout = viewModel.activeWorkout {
                List(workout.exercises) { exercise in
                    ExerciceEntryCard(
                        exerciseEntry: exercise,
                        viewModel: viewModel,
                        onButtonPress: viewModel.startTime
                        
                    )
                }
            } else {
                Text("Aucun workout en cours")
            }
            Button("Save Workout", action: {
                guard viewModel.activeWorkout != nil else {
                    return
                }
                
                viewModel.cancelTimer()
                if navigationPath.last != .saveWorkout {
                    navigationPath.append(.saveWorkout)
                }
            }
                
            )
            Button("Discard Workout", action: {
                guard viewModel.activeWorkout != nil else {
                    return
                }

                viewModel.cancelTimer()
                viewModel.workoutVM.workout = nil
                navigationPath.removeAll()
            }
                
            )
        }
    }
}
