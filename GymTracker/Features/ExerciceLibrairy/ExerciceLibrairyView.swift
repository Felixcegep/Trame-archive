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
    
    
    
    var body: some View {
        // TODO implémenter la recherche qui doit pas etre compliqué
        
        List(availableExercises, id: \.self){ exercise in
            
            HStack {
                Button {
                    onSelect(exercise)
                    dismiss()
                } label: {
                    VStack(alignment: .leading) {
                        Text(exercise.name)
                        Text("Chest • Barbell")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    ExerciceView(exercice: exercise)
                } label: {
                    Image(systemName: "info.circle")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
            
        }
        
        
    }
}
