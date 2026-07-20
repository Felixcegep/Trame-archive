//
//  MusclePickerView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-19.
//

import SwiftUI

struct MusclePickerView: View {
    @Binding var primaryMuscles: Set<Muscle>
    @Binding var secondaryMuscles: Set<Muscle>

    private enum Role: String, CaseIterable {
        case primary = "Primary"
        case secondary = "Secondary"
    }

    @State private var role: Role = .primary
    @State private var searchText = ""

    var body: some View {
        Form {
            Section {
                Picker("Muscle role", selection: $role) {
                    ForEach(Role.allCases, id: \.self) { role in
                        Text(LocalizedStringKey(role.rawValue)).tag(role)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            } footer: {
                Text(role == .primary
                     ? "Primary muscles drive the movement. Pick at least one."
                     : "Secondary muscles assist the movement.")
            }

            ForEach(Muscle.Group.allCases, id: \.self) { group in
                let muscles = filteredMuscles(in: group)
                if !muscles.isEmpty {
                    Section(LocalizedStringKey(group.rawValue)) {
                        ForEach(muscles, id: \.self) { muscle in
                            muscleRow(muscle)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Muscles Worked")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search muscles"
        )
    }

    private func muscleRow(_ muscle: Muscle) -> some View {
        let isSelected = selectedSet.contains(muscle)
        let hasOtherRole = otherSet.contains(muscle)

        return Button {
            toggle(muscle)
        } label: {
            HStack {
                Text(muscle.displayName)
                    .foregroundStyle(Color.gymText)
                Spacer()
                if isSelected {
                    Image(systemName: AppIcon.checkmark)
                        .font(AppFont.subheadlineSemibold)
                        .foregroundStyle(Color.gymPrimary)
                } else if hasOtherRole {
                    Text(role == .primary ? "Secondary" : "Primary")
                        .font(AppFont.footnote)
                        .foregroundStyle(Color.gymSubduedText)
                }
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var selectedSet: Set<Muscle> {
        role == .primary ? primaryMuscles : secondaryMuscles
    }

    private var otherSet: Set<Muscle> {
        role == .primary ? secondaryMuscles : primaryMuscles
    }

    private func filteredMuscles(in group: Muscle.Group) -> [Muscle] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return group.muscles }
        return group.muscles.filter {
            $0.displayName.localizedCaseInsensitiveContains(query)
        }
    }

    private func toggle(_ muscle: Muscle) {
        if role == .primary {
            if primaryMuscles.contains(muscle) {
                primaryMuscles.remove(muscle)
            } else {
                primaryMuscles.insert(muscle)
                secondaryMuscles.remove(muscle)
            }
        } else {
            if secondaryMuscles.contains(muscle) {
                secondaryMuscles.remove(muscle)
            } else {
                secondaryMuscles.insert(muscle)
                primaryMuscles.remove(muscle)
            }
        }
    }
}
