//
//  SetType.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import Foundation

enum SetType: String, Codable, CaseIterable {
    case warmup
    case normal
    case dropSet
    case failure
    case backoff
    case topSet
    case amrap
    case technique
    case dailyMaximum
    case test
    case recovery

    var title: String {
        switch self {
        case .warmup: String(localized: "Warm-up")
        case .normal: String(localized: "Normal")
        case .dropSet: String(localized: "Drop set")
        case .failure: String(localized: "Failure")
        case .backoff: String(localized: "Back-off")
        case .topSet: String(localized: "Top set")
        case .amrap: String(localized: "AMRAP")
        case .technique: String(localized: "Technique")
        case .dailyMaximum: String(localized: "Daily maximum")
        case .test: String(localized: "Test")
        case .recovery: String(localized: "Recovery")
        }
    }

    /// Single-letter badge shown in place of the set number; nil for normal
    /// sets, which display their position instead.
    var shortLabel: String? {
        switch self {
        case .normal: nil
        case .warmup: "W"
        case .dropSet: "D"
        case .failure: "F"
        case .backoff: "B"
        case .topSet: "T"
        case .amrap: "A"
        case .technique: "T"
        case .dailyMaximum: "M"
        case .test: "X"
        case .recovery: "R"
        }
    }
}
