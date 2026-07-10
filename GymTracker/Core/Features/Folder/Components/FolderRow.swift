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
        HStack(spacing: 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FolderPalette.primary)
                    .frame(width: 30, height: 30)
                    .background(FolderPalette.primarySurface, in: RoundedRectangle(cornerRadius: 9))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(FolderPalette.text)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(FolderPalette.mutedText)
            }
        }
        .padding(.vertical, 4)
    }
}
