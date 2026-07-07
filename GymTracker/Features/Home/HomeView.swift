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
                    let template = WorkoutTemplate(name: "Test Workout", exercises: defaultTemplateExercises)
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

    private var defaultTemplateExercises: [ExerciceTemplate] {
        TrackingType.allCases.map { trackingType in
            exerciceTemplates.first { $0.trackingType == trackingType } ?? sampleExercise(for: trackingType)
        }
    }

    private func sampleExercise(for trackingType: TrackingType) -> ExerciceTemplate {
        switch trackingType {
        case .weightAndReps:
            return ExerciceTemplate(
                name: "Bench Press",
                PrimaryMuscle: [.middleChest],
                trackingType: .weightAndReps,
                equipmentType: .barbell,
                resistanceType: .externalWeight,
                movementPattern: .horizontalPush,
                difficulty: .intermediate
            )
        case .repsOnly:
            return ExerciceTemplate(
                name: "Crunch",
                PrimaryMuscle: [.rectusAbdominis],
                trackingType: .repsOnly,
                equipmentType: .bodyweight,
                resistanceType: .bodyweight,
                movementPattern: .isolation,
                difficulty: .beginner
            )
        case .weightedBodyweight:
            return ExerciceTemplate(
                name: "Pull Up",
                PrimaryMuscle: [.latissimusDorsi],
                trackingType: .weightedBodyweight,
                equipmentType: .bodyweight,
                resistanceType: .weightedBodyweight,
                movementPattern: .verticalPull,
                difficulty: .intermediate
            )
        case .assistedBodyweight:
            return ExerciceTemplate(
                name: "Assisted Pull Up",
                PrimaryMuscle: [.latissimusDorsi],
                trackingType: .assistedBodyweight,
                equipmentType: .machine,
                resistanceType: .assistedBodyweight,
                movementPattern: .verticalPull,
                difficulty: .beginner
            )
        case .duration:
            return ExerciceTemplate(
                name: "Plank",
                PrimaryMuscle: [.transverseAbdominis],
                trackingType: .duration,
                equipmentType: .bodyweight,
                resistanceType: .bodyweight,
                movementPattern: .antiRotation,
                difficulty: .beginner
            )
        case .durationAndDistance:
            return ExerciceTemplate(
                name: "Treadmill Run",
                PrimaryMuscle: [.quadriceps, .hamstrings, .calves],
                category: .cardio,
                trackingType: .durationAndDistance,
                equipmentType: .cardioMachine,
                difficulty: .beginner
            )
        }
    }
}
