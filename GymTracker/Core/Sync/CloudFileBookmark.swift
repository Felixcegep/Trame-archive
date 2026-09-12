import Foundation

nonisolated enum CloudFileBookmark {
    enum BookmarkError: LocalizedError, Equatable {
        case cannotCreate
        case cannotResolve

        var errorDescription: String? {
            switch self {
            case .cannotCreate:
                String(localized: "Trame could not remember this file location.")
            case .cannotResolve:
                String(localized: "The cloud file is no longer reachable. Choose it again in Files.")
            }
        }
    }

    static func makeBookmark(for url: URL) throws -> Data {
        do {
            return try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw BookmarkError.cannotCreate
        }
    }

    static func resolve(_ bookmarkData: Data) throws -> URL {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return url
        } catch {
            throw BookmarkError.cannotResolve
        }
    }
}
