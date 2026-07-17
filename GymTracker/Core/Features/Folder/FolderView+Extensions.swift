import SwiftUI

extension View {
    func folderScreenStyle() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Color.gymBackground)
            .foregroundStyle(Color.gymText)
            .tint(Color.gymPrimary)
            .toolbarBackground(Color.gymBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.gymCard, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
    }

    func folderRowBackground() -> some View {
        self.listRowBackground(Color.gymCard)
    }

    func folderSelectedRowBackground(_ isSelected: Bool) -> some View {
        self.listRowBackground(isSelected ? Color.gymPrimarySurface : Color.gymCard)
    }
}
