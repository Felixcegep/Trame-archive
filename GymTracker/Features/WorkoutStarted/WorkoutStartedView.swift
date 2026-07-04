import SwiftUI
import SwiftData
struct WorkoutStartedView: View {
    @Environment(\.modelContext) private var modelContext
    @Query var exerciceTemplates: [ExerciceTemplate]
    
    let workoutVM: WorkoutViewModel
    @State private var viewModel: WorkoutStartedViewModel
    
    @State var seconds = 0
    
    @State var difference : TimeInterval = 0
   
    @State var workoutSaved : Bool = false
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
            if let workout = viewModel.activeWorkout {
                List(workout.exercises) { exercice in
                    ExerciceEntryCard(
                        exerciceActuel: exercice,
                        viewModel: viewModel
                    )
                }
            } else {
                Text("Aucun workout en cours")
            }
            Button("save the workout", action: {
                guard let WorkoutToSave = viewModel.activeWorkout else {
                    return
                }
                
                workoutVM.saveWorkout(using : modelContext)
                workoutSaved = true
            }
                
            )
            // devrais retourner au home
            
        }.navigationDestination(isPresented: $workoutSaved) {
            HomeView(workoutVM: workoutVM)
        }
    }
}
