import SwiftUI

struct WorkoutView: View {
    @State var viewModel: WorkoutViewModel
    
    var body: some View {
        VStack {
            Text("Hello World")
            
            NavigationLink("changer fenetre") {
                ExerciceLibrairyView(
                    SelectExercice: true,
                    ExercicesAvailable: $viewModel.exercicesTemplate,
                    onSelect: viewModel.addExercice
                )
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

