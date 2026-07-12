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

    var title: String {
        switch self {
        case .warmup: String(localized: "Warm-up")
        case .normal: String(localized: "Normal")
        case .dropSet: String(localized: "Drop set")
        case .failure: String(localized: "Failure")
        case .backoff: String(localized: "Back-off")
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
        }
    }
}
