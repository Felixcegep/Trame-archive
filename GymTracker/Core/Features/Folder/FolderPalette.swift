//
//  FolderPalette.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import SwiftUI

enum FolderPalette {
    static let text = Color.gymText
    static let background = Color.gymBackground
    static let primary = Color.gymPrimary
    static let secondary = Color.gymSecondary
    static let accent = Color.gymAccent
    static let card = Color.gymCard
    static let cardElevated = Color.white
    static let primarySurface = Color.gymPrimarySurface
    static let secondarySurface = Color.gymSecondarySurface
    static let accentSurface = Color.gymAccentSurface
    static let divider = text.opacity(0.09)
    static let mutedText = text.opacity(0.58)
    static let subtleText = text.opacity(0.42)
}

extension View {
    func folderScreenStyle() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(FolderPalette.background)
            .foregroundStyle(FolderPalette.text)
            .tint(FolderPalette.primary)
            .toolbarBackground(FolderPalette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(FolderPalette.card, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
    }

    func folderRowBackground() -> some View {
        self.listRowBackground(FolderPalette.card)
    }

    func folderSelectedRowBackground(_ isSelected: Bool) -> some View {
        self.listRowBackground(isSelected ? FolderPalette.primarySurface : FolderPalette.card)
    }
}
