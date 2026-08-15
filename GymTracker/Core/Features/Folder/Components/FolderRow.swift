//
//  FolderRow.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import SwiftUI

struct FolderRow: View {
    let title: String
    let subtitle: String
    let systemImage: String?

    init(title: String, subtitle: String, systemImage: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: Spacing.m) {
            if let systemImage {
                TrameCategoryTile(
                    systemImage: systemImage,
                    fill: Color.trameStrength,
                    size: ComponentSize.iconChip
                )
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(AppFont.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.trameText)
                Text(subtitle)
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
            }
        }
        .padding(.vertical, Spacing.m)
    }
}
