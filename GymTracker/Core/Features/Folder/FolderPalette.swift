//
//  FolderPalette.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import SwiftUI

enum FolderPalette {
    static let text = Color(red: 0x27 / 255.0, green: 0x26 / 255.0, blue: 0x35 / 255.0)
    static let background = Color(red: 0xFB / 255.0, green: 0xF7 / 255.0, blue: 0xEF / 255.0)
    static let primary = Color(red: 0x6A / 255.0, green: 0x95 / 255.0, blue: 0xF1 / 255.0)
    static let secondary = Color(red: 0x6C / 255.0, green: 0x9A / 255.0, blue: 0x8B / 255.0)
    static let accent = Color(red: 0xA1 / 255.0, green: 0x68 / 255.0, blue: 0x3A / 255.0)
    static let card = Color(red: 0xFF / 255.0, green: 0xFD / 255.0, blue: 0xF9 / 255.0)
    static let cardElevated = Color.white
    static let primarySurface = Color(red: 0xE7 / 255.0, green: 0xE9 / 255.0, blue: 0xEF / 255.0)
    static let secondarySurface = Color(red: 0xE7 / 255.0, green: 0xEA / 255.0, blue: 0xE1 / 255.0)
    static let accentSurface = Color(red: 0xF2 / 255.0, green: 0xE9 / 255.0, blue: 0xDD / 255.0)
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
