import SwiftUI
import Foundation
import SwiftData

struct ExerciceEntryCard: View {
    
    @Bindable var exerciseEntry: ExerciceEntry
    let viewModel: ActiveWorkoutViewModel
    let onButtonPress : () -> Void
    var unitSystem: UnitSystem
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

    private var inputTitles: [String] {
        var titles: [String] = []
        let trackingType = exerciseEntry.exercice.trackingType

        if trackingType.usesReps {
            titles.append("Reps")
        }

        if trackingType.usesWeight {
            titles.append("Weight")
        }

        if trackingType.usesDuration {
            titles.append("Duration")
        }

        if trackingType.usesDistance {
            titles.append("Distance")
        }

        return titles
    }
    
    private var headerRow: some View {
        HStack(spacing: 10) {
            Text("Set")
                .frame(width: 70, alignment: .leading)

            ForEach(inputTitles, id: \.self) { title in
                Text(title)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            
            Spacer()
                .frame(width: 76)
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

    private var trackingType: TrackingType {
        exerciseEntry.exercice.trackingType
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Text("Set \(index + 1)")
                .frame(width: 70, alignment: .leading)

            if trackingType.usesReps {
                repsField
            }

            if trackingType.usesWeight {
                weightField
            }

            if trackingType.usesDuration {
                durationField
            }

            if trackingType.usesDistance {
                distanceField
            }
            
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
        inputField(
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
    }
    
    private var weightField: some View {
        inputField(
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
    }

    private var durationField: some View {
        inputField(
            "Seconds",
            text: Binding(
                get: {
                    guard let duration = set.duration else { return "" }
                    return String(Int(duration))
                },
                set: { newValue in
                    if newValue.isEmpty {
                        set.duration = nil
                    } else if let value = TimeInterval(newValue) {
                        set.duration = value
                    }
                }
            )
        )
    }

    private var distanceField: some View {
        inputField(
            "Distance",
            text: Binding(
                get: {
                    guard let distance = set.distance else { return "" }
                    return String(distance)
                },
                set: { newValue in
                    if newValue.isEmpty {
                        set.distance = nil
                    } else if let value = Float(newValue) {
                        set.distance = value
                    }
                }
            )
        )
    }

    private func inputField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .textFieldStyle(.roundedBorder)
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
