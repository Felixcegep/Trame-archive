import SwiftUI

struct WorkoutView: View {
    @State var viewModel : WorkoutViewModel 
    
    @State var seconds = 0
    
    @State var difference : TimeInterval = 0
   
    @State var workoutSaved : Bool = false
    let startDate = Date.now
    
    var body: some View {
        VStack {
            Text("Hello World")
            Text(startDate, style: .timer)
            
            NavigationLink("changer fenetre") {
                ExerciceLibrairyView(
                    SelectExercice: true,
                    ExercicesAvailable: $viewModel.exercicesTemplate,
                    onSelect: viewModel.addExercice
                )
            }
            if let workout = viewModel.workout {
                List(viewModel.workout?.exercises ?? []) { exercice in
                    ExerciceEntryCard(
                        exerciceActuel: exercice,
                        workoutVM: viewModel
                    )
                }
            }
            Button("save the workout", action: {
                guard let WorkoutToSave = viewModel.workout else {
                    return
                }
                
                viewModel.saveWorkout(workoutSaved: WorkoutToSave)
                workoutSaved = true
            }
                
            )
            // devrais retourner au home
            
        }.navigationDestination(isPresented: $workoutSaved) {
            HomeView()
        }
    }
}

