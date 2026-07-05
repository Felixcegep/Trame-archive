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
                    if let activeWorkout = workoutVM.activeWorkout {
                        let gymTrackerAttributes = GymTrackerAttributes(startTime: activeWorkout.startTime)
                        Task {
                            let initialState = GymTrackerAttributes.ContentState()
                            
                            let content = ActivityContent(state: initialState, staleDate: nil, relevanceScore: 0.0)
                            
                            let activity = try Activity.request(
                                attributes:gymTrackerAttributes,
                                content: content,
                            pushType: nil)
                        }
                        
                    }
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
