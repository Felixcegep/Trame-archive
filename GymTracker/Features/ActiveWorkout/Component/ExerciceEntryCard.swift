import SwiftUI
import Foundation
import SwiftData

struct ExerciceEntryCard: View {
    
    @Bindable var exerciseEntry: ExerciceEntry
    let viewModel: ActiveWorkoutViewModel
    let onButtonPress : () -> Void
    var body: some View {
        VStack(alignment: .leading) {
            DisclosureGroup(titleText) {
                VStack(alignment: .leading, spacing: 10) {
                    headerRow
                    
                    setRows
                    
                    addSetButton
                }
                .padding(.top, 8)
            }
            
            removeExerciseButton
        }
    }
    
    private var titleText: String {
        "\(exerciseEntry.exercice.name) set: \(exerciseEntry.sets.count)"
    }
    
    private var headerRow: some View {
        HStack {
            Text("Set")
                .frame(width: 70, alignment: .leading)
            
            Text("Reps")
                .frame(width: 80, alignment: .center)
            
            Text("Weight")
                .frame(width: 80, alignment: .center)
            
            Spacer()
        }
        .padding(.bottom, 5)
    }
    
    private var setRows: some View {
        ForEach(
            Array(exerciseEntry.sets.enumerated()),
            id: \.element.persistentModelID
        ) { index, set in
            SetRowView(
                index: index,
                set: set,
                exerciseEntry: exerciseEntry,
                viewModel: viewModel,
                onButtonPress: onButtonPress
            )
        }
    }
    
    private var addSetButton: some View {
        HStack{
            Button {
                viewModel.addSet(exerciseEntry)
            } label: {
                Label("Add set", systemImage: "plus.circle")
            }
            .buttonStyle(.borderless)
            .padding(.top, 5)
            Button {
                viewModel.addSetCopyLastSet(exerciseEntry: exerciseEntry)
            } label: {
                Label("copyLast set", systemImage: "plus.circle")
            }
            .buttonStyle(.borderless)
            .padding(.top, 5)
                
        }
        
    }
    
    
    private var removeExerciseButton: some View {
        Button {
            viewModel.removeExercise(exerciseEntry)
        } label: {
            Label("Remove exercise", systemImage: "trash")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.red)
        .padding(.top, 6)
    }
}

struct SetRowView: View {
    
    let index: Int
    @Bindable var set: ExerciseSet
    let exerciseEntry: ExerciceEntry
    let viewModel: ActiveWorkoutViewModel
    let onButtonPress: () -> Void
    
    var body: some View {
        HStack {
            Text("Set \(index + 1)")
                .frame(width: 70, alignment: .leading)
            
            repsField
            
            weightField
            
            Spacer()
            
            doneButton
            
            removeButton
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(rowBackground)
        .overlay(rowBorder)
    }
    
    private var repsField: some View {
        TextField(
            "Reps",
            text: Binding(
                get: { String(set.repetition) },
                set: { newValue in
                    if let value = Float(newValue) {
                        set.repetition = value
                    }
                }
            )
        )
        .keyboardType(.decimalPad)
        .multilineTextAlignment(.center)
        .frame(width: 80)
    }
    
    private var weightField: some View {
        TextField(
            "Weight",
            text: Binding(
                get: { String(set.weight) },
                set: { newValue in
                    if let value = Float(newValue) {
                        set.weight = value
                    }
                }
            )
        )
        .keyboardType(.decimalPad)
        .multilineTextAlignment(.center)
        .frame(width: 80)
    }
    
    private var doneButton: some View {
        Button {
            
            viewModel.switchStateDoneSet(exerciseEntry, set)
            onButtonPress()
            
        } label: {
            Image(systemName: set.done ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(set.done ? .green : .gray)
        }
        .buttonStyle(.borderless)
    }
    
    private var removeButton: some View {
        Button {
            viewModel.removeSet(exerciseEntry, set)
        } label: {
            Image(systemName: "trash")
                .foregroundStyle(.red)
        }
        .buttonStyle(.borderless)
    }
    
    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.secondarySystemBackground))
    }
    
    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(
                set.done ? Color.green : Color.gray.opacity(0.3),
                lineWidth: set.done ? 2 : 1
            )
    }
}

#Preview {
    ExerciceEntryCard(
        exerciseEntry: ExerciceEntry(
            Comment: "Great set",
            exercice: ExerciceTemplate(
                name: "Bench Press",
                PrimaryMuscle: [.middleChest]
            ),
            sets: [
                ExerciseSet(repetition: 1, weight: 1),
                ExerciseSet(repetition: 2, weight: 3)
            ]
        ),
        viewModel: ActiveWorkoutViewModel(workoutVM: WorkoutViewModel()),
        onButtonPress: {}
    )
}
