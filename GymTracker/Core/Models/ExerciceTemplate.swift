//
//  Exercice.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//


struct ExerciceTemplate : Codable{
    var name: String
    var PrimaryMuscle: [Muscle]
    var SecondaryMuscle: [Muscle]?
}

