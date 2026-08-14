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
    nonisolated static let maxDimension: CGFloat = 512
    nonisolated private static let compressionQuality: CGFloat = 0.7
    nonisolated private static let directoryName = "RecipePhotos"
    private static let imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 24 * 1_024 * 1_024
        cache.countLimit = 96
        return cache
    }()

    nonisolated private static var directoryURL: URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(directoryName, isDirectory: true)
    }

    nonisolated private static func url(for identifier: String) -> URL {
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
    nonisolated static func store(_ data: Data) -> String? {
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
        if let identifier, let cached = imageCache.object(forKey: identifier as NSString) {
            return cached
        }
        guard let data = loadData(identifier) else { return nil }
        let image = UIImage(data: data)
        if let identifier, let image {
            imageCache.setObject(
                image,
                forKey: identifier as NSString,
                cost: cacheCost(of: image)
            )
        }
        return image
    }

    nonisolated static func loadData(_ identifier: String?) -> Data? {
        guard let identifier else { return nil }
        return try? Data(contentsOf: url(for: identifier))
    }

    static func loadImageAsync(_ identifier: String?) async -> UIImage? {
        guard let identifier else { return nil }
        if let cached = imageCache.object(forKey: identifier as NSString) {
            return cached
        }
        let data = await Task.detached(priority: .utility) {
            try? Data(contentsOf: url(for: identifier))
        }.value
        guard let data else { return nil }
        let image = UIImage(data: data)
        if let image {
            imageCache.setObject(
                image,
                forKey: identifier as NSString,
                cost: cacheCost(of: image)
            )
        }
        return image
    }

    private static func cacheCost(of image: UIImage) -> Int {
        let pixelsWide = image.size.width * image.scale
        let pixelsHigh = image.size.height * image.scale
        return max(1, Int(pixelsWide * pixelsHigh * 4))
    }

    /// Decodes, downscales, encodes, and writes a newly selected photo away
    /// from the main actor. The editor keeps only the original picker bytes
    /// until this completes, so tapping Save cannot stall form interaction.
    static func storeImageDataAsync(_ sourceData: Data) async -> String? {
        await Task.detached(priority: .utility) {
            guard let image = UIImage(data: sourceData),
                  let data = compressedData(from: image)
            else {
                return nil
            }
            return store(data)
        }.value
    }

    static func decodeImageAsync(_ data: Data?) async -> UIImage? {
        guard let data else { return nil }
        let previewData: Data? = await Task.detached(priority: .utility) { () -> Data? in
            guard let image = UIImage(data: data) else { return nil }
            return compressedData(from: image)
        }.value
        // UIKit state never crosses the detached-task boundary. Only immutable
        // encoded bytes return to the UI actor, which owns image construction.
        return previewData.flatMap { UIImage(data: $0) }
    }

    /// Deletes the file for `identifier` only when no `MealTemplate` in the
    /// context still references it, so a shared photo survives while any
    /// revision still points at it.
    static func deleteIfUnreferenced(_ identifier: String?, in context: ModelContext) {
        guard let identifier else { return }
        var descriptor = FetchDescriptor<MealTemplate>(
            predicate: #Predicate { $0.photoIdentifier == identifier }
        )
        descriptor.fetchLimit = 1
        let stillReferenced = ((try? context.fetch(descriptor)) ?? []).isEmpty == false
        guard stillReferenced == false else { return }
        try? FileManager.default.removeItem(at: url(for: identifier))
        imageCache.removeObject(forKey: identifier as NSString)
    }

    /// Reduces an image to a JPEG no larger than `maxDimension` on its longest
    /// edge. Returns `nil` if the image cannot be encoded.
    nonisolated static func compressedData(from image: UIImage) -> Data? {
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
