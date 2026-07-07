import SwiftUI
import SwiftData
struct WorkoutStartedView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query var exerciceTemplates: [ExerciceTemplate]
    
    let workoutVM: WorkoutViewModel
    @State private var viewModel: WorkoutStartedViewModel
    
    @State var seconds = 0
    
    @State var difference: TimeInterval = 0
    @State var isTimerVisible: Bool = false
    @State var workoutFinished: Bool = false


    let startDate = Date.now

    init(workoutVM: WorkoutViewModel) {
        self.workoutVM = workoutVM
        _viewModel = State(initialValue: WorkoutStartedViewModel(workoutVM: workoutVM))
    }

    
    var body: some View {
        VStack {
            Text("Hello World")
            Text(startDate, style: .timer)
            
            NavigationLink("changer fenetre") {
                ExerciceLibrairyView(
                    SelectExercice: true,
                    ExercicesAvailable: exerciceTemplates,
                    onSelect: viewModel.addExercise
                )
            }
            if let timerEndDate = viewModel.timerEndDate{
                Text(
                    timerInterval: Date.now...timerEndDate,
                    countsDown: true
                )
                .font(.largeTitle)
                .monospacedDigit()
            }

            if let workout = viewModel.activeWorkout {
                List(workout.exercises) { exercice in
                    ExerciceEntryCard(
                        exerciceActuel: exercice,
                        viewModel: viewModel,
                        onButtonPress: viewModel.startTime
                        
                    )
                }
            } else {
                Text("Aucun workout en cours")
            }
            Button("save the workout", action: {
                guard viewModel.activeWorkout != nil else {
                    return
                }
                
                
                viewModel.timerTask?.cancel()
                viewModel.isTimerVisible = false
                viewModel.timerEndDate = nil
                
                workoutVM.saveWorkout(using: modelContext)
                workoutFinished = true
                viewModel.workoutVM.workout = nil
                // retour en arriere 
                dismiss()
            }
                
            )
            Button("discard the workout", action: {
                guard viewModel.activeWorkout != nil else {
                    return
                }
                viewModel.workoutVM.workout = nil
                
                

                viewModel.timerTask?.cancel()
                viewModel.isTimerVisible = false
                viewModel.timerEndDate = nil

                
                workoutFinished = true
                dismiss()
            }
                
            )
            // devrais retourner au home
            
        }
    }
}
