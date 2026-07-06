import SwiftUI
import SwiftData
struct WorkoutStartedView: View {
    @Environment(\.modelContext) private var modelContext
    @Query var exerciceTemplates: [ExerciceTemplate]
    
    let workoutVM: WorkoutViewModel
    @State private var viewModel: WorkoutStartedViewModel
    
    @State var seconds = 0
    
    @State var difference: TimeInterval = 0
    @State var isTimerVisible: Bool = false
    @State var workoutSaved: Bool = false

    @State private var timerEndDate: Date?
    @State private var timerTask: Task<Void, Never>?

    let startDate = Date.now

    init(workoutVM: WorkoutViewModel) {
        self.workoutVM = workoutVM
        _viewModel = State(initialValue: WorkoutStartedViewModel(workoutVM: workoutVM))
    }

    func startTime() {
        let duration: TimeInterval = 90

        timerTask?.cancel()

        timerEndDate = Date.now.addingTimeInterval(duration)
        isTimerVisible = true

        timerTask = Task {
            do {
                try await Task.sleep(for: .seconds(duration))

                guard !Task.isCancelled else {
                    return
                }

                await MainActor.run {
                    isTimerVisible = false
                    timerEndDate = nil
                }
            } catch {
                return
            }
        }
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
            if isTimerVisible,
               let timerEndDate {
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
                        onButtonPress: startTime
                        
                    )
                }
            } else {
                Text("Aucun workout en cours")
            }
            Button("save the workout", action: {
                guard viewModel.activeWorkout != nil else {
                    return
                }

                timerTask?.cancel()
                isTimerVisible = false
                timerEndDate = nil

                workoutVM.saveWorkout(using: modelContext)
                workoutSaved = true
            }
                
            )
            // devrais retourner au home
            
        }.navigationDestination(isPresented: $workoutSaved) {
            HomeView(workoutVM: workoutVM)
        }
    }
}
