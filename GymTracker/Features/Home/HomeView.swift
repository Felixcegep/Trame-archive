import SwiftUI
import ActivityKit
struct HomeView: View {
    let workoutVM: WorkoutViewModel
    @Binding var navigationPath: [HomeRoute]

    var body: some View {
        VStack {
            Text("Home")

            Button {
                if !workoutVM.hasActiveWorkout {
                    workoutVM.startWorkout()
                }

                navigationPath.append(.activeWorkout)
            } label: {
                Text(workoutVM.hasActiveWorkout ? "Continuer Workout" : "Lancer Workout")
            }
        }
    }
}
