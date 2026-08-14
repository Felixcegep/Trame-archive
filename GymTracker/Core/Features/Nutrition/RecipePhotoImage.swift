import SwiftUI
import UIKit

/// Loads a recipe thumbnail after the view has entered the hierarchy so list
/// layout never performs file I/O or image decoding synchronously.
struct RecipePhotoImage<Content: View, Placeholder: View>: View {
    let identifier: String?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var image: UIImage?

    init(
        identifier: String?,
        content: @escaping (Image) -> Content,
        placeholder: @escaping () -> Placeholder
    ) {
        self.identifier = identifier
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .task(id: identifier) {
            let loadedImage = await RecipePhotoStore.loadImageAsync(identifier)
            guard !Task.isCancelled else { return }
            image = loadedImage
        }
    }
}
