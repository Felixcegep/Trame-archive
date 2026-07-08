//
//  MovementPattern.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

enum MovementPattern: String, Codable, CaseIterable {
    case horizontalPush = "Horizontal Push"
    case verticalPush = "Vertical Push"
    case horizontalPull = "Horizontal Pull"
    case verticalPull = "Vertical Pull"
    case squat = "Squat"
    case hinge = "Hinge"
    case lunge = "Lunge"
    case carry = "Carry"
    case rotation = "Rotation"
    case antiRotation = "Anti-Rotation"
    case isolation = "Isolation"
    case other = "Other"
}
