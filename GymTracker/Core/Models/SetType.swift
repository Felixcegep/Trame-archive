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
}
