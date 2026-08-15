import SwiftUI

extension View {
    func folderScreenStyle() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Color.trameCanvas)
            .foregroundStyle(Color.trameText)
            .tint(Color.trameStrength)
            .toolbarBackground(Color.trameCanvas, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.trameSurface, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
    }

    func folderRowBackground() -> some View {
        self.listRowBackground(Color.trameSurface)
    }

    func folderSelectedRowBackground(_ isSelected: Bool) -> some View {
        self.listRowBackground(isSelected ? Color.trameCurrent : Color.trameSurface)
    }
}
