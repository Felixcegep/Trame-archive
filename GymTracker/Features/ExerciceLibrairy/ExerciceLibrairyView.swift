//
//  ExerciceLibrairyView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//

import SwiftUI

struct ExerciceLibrairyView : View {
    @Environment(\.dismiss) private var dismiss
    
    @State var SelectExercice : Bool
    var SelectedExercice: ExerciceTemplate?
    var ExercicesAvailable: [ExerciceTemplate]
    let onSelect: (ExerciceTemplate) -> Void
    
    
    
    var body: some View {
        // TODO implémenter la recherche qui doit pas etre compliqué
        
        List(ExercicesAvailable, id: \.self){ exercice in
            
            HStack {
                Button {
                    onSelect(exercice)
                    dismiss()
                } label: {
                    VStack(alignment: .leading) {
                        Text(exercice.name)
                        Text("Chest • Barbell")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    ExerciceView(exercice: exercice)
                } label: {
                    Image(systemName: "info.circle")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
            
        }
        
        
    }
}
