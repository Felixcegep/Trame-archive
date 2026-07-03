//
//  ExerciceView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-03.
//

import Foundation
import SwiftUI

struct ExerciceView : View {
    var exercice: ExerciceTemplate
    var body: some View {
        Text("exercice Name")
        Text(exercice.name)
        Text("Principal Muscle")
        List(exercice.PrimaryMuscle, id: \.self) { muscle in
            Text(muscle.rawValue)
        }
        Text("Secondary Muscle")
        
        if let secondaryMuscle = exercice.SecondaryMuscle
        {
            List(secondaryMuscle, id: \.self) { muscle in
                Text(muscle.rawValue)
            }
        }
    }
}
