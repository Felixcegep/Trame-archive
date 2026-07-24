import Foundation
import SwiftData
import UIKit

/// Stores optional recipe recognition photos as files outside SwiftData. Only a
/// stable filename is kept on `MealTemplate.photoIdentifier`; the bytes live in
/// Application Support so the primary store stays small.
///
/// Photos are a recognition aid, never nutrition evidence: they are compressed
/// to a small thumbnail and are safe to lose without affecting any logged meal.
enum RecipePhotoStore {
    /// Longest edge of a stored photo. A recognition thumbnail does not need
    /// more, and this keeps files in the ~150–250 KB target range.
    static let maxDimension: CGFloat = 512
    private static let compressionQuality: CGFloat = 0.7
    private static let directoryName = "RecipePhotos"

    private static var directoryURL: URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(directoryName, isDirectory: true)
    }

    private static func url(for identifier: String) -> URL {
        directoryURL.appendingPathComponent(identifier)
    }

    /// Compresses `image` to a small JPEG and writes it under a fresh
    /// identifier, returning that identifier. Returns `nil` if encoding fails.
    @discardableResult
    static func store(_ image: UIImage) -> String? {
        guard let data = compressedData(from: image) else { return nil }
        return store(data)
    }

    /// Writes already-encoded JPEG bytes (used by backup restore) under a fresh
    /// identifier. The bytes are trusted to already be reasonably sized.
    @discardableResult
    static func store(_ data: Data) -> String? {
        let identifier = "\(UUID().uuidString).jpg"
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            try data.write(to: url(for: identifier), options: .atomic)
            return identifier
        } catch {
            return nil
        }
    }

    static func loadImage(_ identifier: String?) -> UIImage? {
        guard let data = loadData(identifier) else { return nil }
        return UIImage(data: data)
    }

    static func loadData(_ identifier: String?) -> Data? {
        guard let identifier else { return nil }
        return try? Data(contentsOf: url(for: identifier))
    }

    /// Deletes the file for `identifier` only when no `MealTemplate` in the
    /// context still references it, so a shared photo survives while any
    /// revision still points at it.
    static func deleteIfUnreferenced(_ identifier: String?, in context: ModelContext) {
        guard let identifier else { return }
        let stillReferenced = ((try? context.fetch(FetchDescriptor<MealTemplate>())) ?? [])
            .contains { $0.photoIdentifier == identifier }
        guard stillReferenced == false else { return }
        try? FileManager.default.removeItem(at: url(for: identifier))
    }

    /// Reduces an image to a JPEG no larger than `maxDimension` on its longest
    /// edge. Returns `nil` if the image cannot be encoded.
    static func compressedData(from image: UIImage) -> Data? {
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: compressionQuality)
    }
}
