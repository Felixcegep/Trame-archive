//
//  ResistanceType.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

enum ResistanceType: String, Codable, CaseIterable {
    case externalWeight = "External Weight"
    case bodyweight = "Bodyweight"
    case assistedBodyweight = "Assisted Bodyweight"
    case weightedBodyweight = "Weighted Bodyweight"
    case elastic = "Elastic"
    case machine = "Machine"
    case none = "None"
    case other = "Other"
}
