import Foundation

protocol MealPhotoEstimator: Sendable {
    func estimate(imageJPEG: Data) async throws -> MealPhotoEstimateDraft
}

enum MealPhotoEstimatorError: Error, Equatable {
    case missingAPIKey
    case consentDenied
    case invalidResponse
    case invalidKey
    case requestFailed
}

/// Direct Gemini REST. The request body is a compressed JPEG plus the JSON
/// schema prompt — never the local food library, keychain contents, or meals.
struct GeminiMealPhotoEstimator: MealPhotoEstimator {
    static let modelID = "gemini-2.5-flash"
    private static let endpoint = URL(
        string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelID):generateContent"
    )!

    private let session: URLSession
    private let keyStore: GeminiAPIKeyStore

    init(session: URLSession = .shared, keyStore: GeminiAPIKeyStore = .shared) {
        self.session = session
        self.keyStore = keyStore
    }

    func estimate(imageJPEG: Data) async throws -> MealPhotoEstimateDraft {
        guard let apiKey = keyStore.load() else { throw MealPhotoEstimatorError.missingAPIKey }
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONEncoder().encode(
            GenerateContentRequest(
                contents: [
                    .init(parts: [
                        .init(text: Self.prompt, inlineData: nil),
                        .init(
                            text: nil,
                            inlineData: .init(mimeType: "image/jpeg", data: imageJPEG.base64EncodedString())
                        )
                    ])
                ],
                generationConfig: .init(temperature: 0.2, responseMimeType: "application/json")
            )
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw MealPhotoEstimatorError.requestFailed
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 400 || status == 401 || status == 403 {
            throw MealPhotoEstimatorError.invalidKey
        }
        guard (200..<300).contains(status) else {
            throw MealPhotoEstimatorError.requestFailed
        }
        let decoded = try JSONDecoder().decode(GenerateContentResponse.self, from: data)
        if decoded.error != nil {
            throw MealPhotoEstimatorError.requestFailed
        }
        guard let text = decoded.candidates?.first?.content.parts.compactMap(\.text).first,
              text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        else {
            throw MealPhotoEstimatorError.invalidResponse
        }
        return try MealPhotoEstimateParser.parse(text)
    }

    private static let prompt = """
    Estimate the edible foods visible in this meal photo for a training food log.
    Return JSON only:
    {"unclear": bool, "items": [{"name": string, "grams": number|null, "calories": number|null, "proteinGrams": number|null, "carbohydrateGrams": number|null, "fatGrams": number|null}]}
    Rules:
    - unclear=true if this is not a meal or foods cannot be identified.
    - Omit a nutrient (null) rather than guessing.
    - Do not invent branded products that are not visible.
    - grams is edible portion mass.
    - Use the language on packaging when visible, otherwise English.
    """
}

private struct GenerateContentRequest: Encodable {
    var contents: [Content]
    var generationConfig: GenerationConfig

    struct Content: Encodable {
        var parts: [Part]
    }

    struct Part: Encodable {
        var text: String?
        var inlineData: InlineData?

        enum CodingKeys: String, CodingKey {
            case text
            case inlineData
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            if let text { try container.encode(text, forKey: .text) }
            if let inlineData { try container.encode(inlineData, forKey: .inlineData) }
        }
    }

    struct InlineData: Encodable {
        var mimeType: String
        var data: String
    }

    struct GenerationConfig: Encodable {
        var temperature: Double
        var responseMimeType: String
    }
}

private struct GenerateContentResponse: Decodable {
    var candidates: [Candidate]?
    var error: APIError?

    struct Candidate: Decodable {
        var content: Content
    }

    struct Content: Decodable {
        var parts: [Part]
    }

    struct Part: Decodable {
        var text: String?
    }

    struct APIError: Decodable {
        var message: String?
    }
}
