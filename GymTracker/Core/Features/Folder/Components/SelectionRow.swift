//
//  SelectionRow.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import SwiftUI

struct SelectionRow: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack {
                Text(LocalizedStringKey(title))
                    .foregroundStyle(Color.trameText)
                Spacer()
                if isSelected {
                    Image(systemName: AppIcon.checkmark)
                        .foregroundStyle(Color.trameCompleted)
                }
            }
        }
    }
}
