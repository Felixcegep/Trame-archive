import SwiftUI
import ActivityKit
import SwiftData

struct HomeView: View {
    let workoutVM: WorkoutViewModel
    @Binding var navigationPath: [HomeRoute]
    @Query private var exerciceTemplates: [ExerciceTemplate]
    @State private var showSetting : Bool = false
    
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
            if (!workoutVM.hasActiveWorkout) {
                Button {
                    // Utiliser des exercices existants de la base de données s'il y en a, sinon en instancier des nouveaux temporaires
                    let testExercises: [ExerciceTemplate] = exerciceTemplates.isEmpty ? [
                        ExerciceTemplate(name: "Bench Press", PrimaryMuscle: [.middleChest]),
                        ExerciceTemplate(name: "Back Squat", PrimaryMuscle: [.quadriceps])
                    ] : Array(exerciceTemplates.prefix(3))
                    
                    let template = WorkoutTemplate(name: "Test Workout", exercises: testExercises)
                    workoutVM.startWorkoutWithTemplate(Template: template)
                    navigationPath.append(.activeWorkout)
                } label: {
                    Text("Lancer TemplateWorkout")
                }
            }
        }.navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSetting = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }.sheet(isPresented: $showSetting) {
                NavigationView {
                    SettingView()
                }
            }
    }
}
