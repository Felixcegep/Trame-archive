import Foundation

enum SearchNormalization {
    /// Normalizes text for search indexing and matching:
    /// - Strips diacritics / accents (e.g. "Épaules" -> "Epaules")
    /// - Converts to lowercase
    /// - Trims leading/trailing whitespace
    /// - Standardizes whitespace
    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
        return folded
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Tokenizes normalized query into individual search terms
    static func tokens(from text: String) -> [String] {
        normalize(text).components(separatedBy: " ").filter { !$0.isEmpty }
    }

    /// Returns true if item text or any aliases match the search query (all query tokens matched)
    static func matches(query: String, primaryName: String, alternateName: String? = nil, aliases: [String] = []) -> Bool {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else { return true }

        let queryTokens = tokens(from: normalizedQuery)
        var searchableTexts = [normalize(primaryName)]
        if let alt = alternateName, !alt.isEmpty {
            searchableTexts.append(normalize(alt))
        }
        searchableTexts.append(contentsOf: aliases.map { normalize($0) })

        let combinedSearchable = searchableTexts.joined(separator: " ")

        return queryTokens.allSatisfy { token in
            combinedSearchable.contains(token)
        }
    }
}
