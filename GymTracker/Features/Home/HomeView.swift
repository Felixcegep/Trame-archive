import SwiftUI
import ActivityKit
struct HomeView: View {
    let workoutVM: WorkoutViewModel
    
    @State private var goToWorkout = false

    var body: some View {
        VStack {
            Text("Home")

            Button {
                if !workoutVM.hasActiveWorkout {
                    workoutVM.startWorkout()
                    
                }

                goToWorkout = true
            } label: {
                Text(workoutVM.hasActiveWorkout ? "Continuer Workout" : "Lancer Workout")
            }
        }
        .navigationDestination(isPresented: $goToWorkout) {
            WorkoutStartedView(workoutVM: workoutVM)
        }
    }
}
