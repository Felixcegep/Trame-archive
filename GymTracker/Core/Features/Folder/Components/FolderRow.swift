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
                    .foregroundStyle(Color.gymPrimary)
                    .frame(width: 30, height: 30)
                    .background(Color.gymPrimarySurface, in: RoundedRectangle(cornerRadius: 9))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.gymText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
        }
        .padding(.vertical, Spacing.m)
    }
}
