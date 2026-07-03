//
//  ExerciceLibrairyView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//

import SwiftUI

struct ExerciceLibrairyView : View {
    @Environment(\.dismiss) private var dismiss
    
    @State  var SelectExercice : Bool
     var SelectedExercice: ExerciceTemplate?
    @Binding  var ExercicesAvailable: [ExerciceTemplate]
    let onSelect: (ExerciceTemplate) -> Void
    
    
    
    var body: some View {
        var search = ""
        
        List(ExercicesAvailable, id: \.self){ exercice in
            NavigationLink(destination: ExerciceView(exercice: exercice)) {
                HStack {
                    Text(exercice.name)
                    Button(action: {
                        onSelect(exercice)
                        // add exercice and go back to the menu
                        dismiss()
                    }) {
                        Image(systemName: "chevron.right")
                    }
                                        
                }
            }
        }
        
        
    }
}
