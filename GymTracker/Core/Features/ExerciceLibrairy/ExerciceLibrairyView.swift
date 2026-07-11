//
//  ExerciceLibrairyView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//

import SwiftUI

struct ExerciceLibrairyView : View {
    @Environment(\.dismiss) private var dismiss
    
    @State var isSelectingExercise : Bool
    var selectedExercise: ExerciceTemplate?
    var availableExercises: [ExerciceTemplate]
    let onSelect: (ExerciceTemplate) -> Void

    @State private var searchText = ""
    @State private var filter = ExerciseFilterState()

    var body: some View {
        List {
            Section {
                ExerciseFilterControls(filter: $filter, resultCount: filteredExercises.count)
            }

            if filteredExercises.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ForEach(filteredExercises, id: \.self) { exercise in
                    HStack(spacing: 8) {
                        Button {
                            onSelect(exercise)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercise.name)
                                    .font(.body.weight(.medium))
                                 Text(exercise.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            ExerciceView(exercice: exercise)
                        } label: {
                            Image(systemName: "info.circle")
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Details for \(exercise.name)")
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises")
        .navigationTitle("Add Exercise")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private var filteredExercises: [ExerciceTemplate] {
        availableExercises.filter { exercise in
            filter.matches(exercise, searchText: searchText)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

}
