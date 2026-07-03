import SwiftUI

struct WorkoutView: View {
    var viewModel: WorkoutViewModel
    
    var body: some View {
        VStack {
            Text("Hello World")
            
            Button("Add") {
                viewModel.addExercice()
            }
            
            List(viewModel.exercices) { exercice in
                ExerciceEntryCard(
                    exerciceActuel: exercice,
                    workoutVM: viewModel
                )
            }
        }
    }
}

