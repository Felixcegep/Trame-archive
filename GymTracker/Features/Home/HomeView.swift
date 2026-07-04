import SwiftUI

struct HomeView: View {
    let workoutVM: WorkoutViewModel
    @State private var goToWorkout = false

    var body: some View {
        VStack {
            Text("Home")

            Button {
                if workoutVM.workout == nil {
                    workoutVM.startWorkout()
                }

                goToWorkout = true
            } label: {
                Text(workoutVM.workout == nil ? "Lancer Workout" : "Ajouter exercice")
            }
        }
        .navigationDestination(isPresented: $goToWorkout) {
            WorkoutView(viewModel: workoutVM)
        }
    }
}
