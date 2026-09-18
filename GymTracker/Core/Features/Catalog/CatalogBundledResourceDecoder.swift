import Foundation

/// The typed, non-persisted representation of the three bundled catalogue
/// files. Seeding can map these records into `CatalogDefinitionMetadata`
/// without changing any of the frozen definition models.
nonisolated struct CatalogResourceCatalog: Equatable, Sendable {
    let exercises: [ExerciseCatalogResource]
    let mobilityDefinitions: [MobilityCatalogResource]
    let programs: [ProgramCatalogResource]
}

nonisolated struct ExerciseInstructionResource: Codable, Equatable, Sendable {
    let step: Int
    let title: String
    let text: String

    private enum CodingKeys: String, CodingKey { case step, title, text }
}

nonisolated struct ExerciseCatalogResource: Codable, Equatable, Sendable {
    let name: String
    let stableKey: String
    let sources: [String]
    let category: String?
    let trackingType: String?
    let equipment: String?
    let resistanceType: String?
    let movementPattern: String?
    let movementPatterns: [String]
    let forceType: String?
    let difficulty: String?
    let tags: [String]
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let muscleGroups: [String]
    let anatomicalTargetMuscles: [String]
    let anatomicalSynergistMuscles: [String]
    let description: String?
    let instructions: [ExerciseInstructionResource]
    let videoURL: String?
    let videoEmbedURL: String?
    let videoThumbnail: String?
    let imageURL: String?
    let liftosaurURL: String?
    let liftosaurSlug: String?
    let sportDiscipline: String?
    let frenchName: String?
    let searchAliases: [String]
    let laterality: String?

    private enum CodingKeys: String, CodingKey {
        case name
        case stableKey = "seedkey"
        case sources, category
        case trackingType = "trackingtype"
        case equipment
        case resistanceType = "resistancetype"
        case movementPattern = "movementpattern"
        case movementPatterns = "movementpatterns"
        case forceType = "forcetype"
        case difficulty, tags
        case primaryMuscles = "primarymuscles"
        case secondaryMuscles = "secondarymuscles"
        case muscleGroups = "musclegroups"
        case anatomicalTargetMuscles = "targetmusclesanatomical"
        case anatomicalSynergistMuscles = "synergistmusclesanatomical"
        case description, instructions
        case videoURL = "videourl"
        case videoEmbedURL = "videoembedurl"
        case videoThumbnail = "videothumbnail"
        case imageURL = "imageurl"
        case liftosaurURL = "liftosaururl"
        case liftosaurSlug = "liftosaurslug"
        case sportDiscipline = "sportdiscipline"
        case frenchName = "frenchname"
        case searchAliases = "searchaliases"
        case laterality
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        stableKey = try c.decode(String.self, forKey: .stableKey)
        sources = try c.decodeIfPresent([String].self, forKey: .sources) ?? []
        category = try c.decodeIfPresent(String.self, forKey: .category)
        trackingType = try c.decodeIfPresent(String.self, forKey: .trackingType)
        equipment = try c.decodeIfPresent(String.self, forKey: .equipment)
        resistanceType = try c.decodeIfPresent(String.self, forKey: .resistanceType)
        if let patterns = try c.decodeIfPresent([String].self, forKey: .movementPatterns) {
            movementPatterns = patterns
            movementPattern = patterns.first
        } else if let pattern = try c.decodeIfPresent(String.self, forKey: .movementPattern) {
            movementPattern = pattern
            movementPatterns = [pattern]
        } else {
            movementPattern = nil
            movementPatterns = []
        }
        forceType = try c.decodeIfPresent(String.self, forKey: .forceType)
        difficulty = try c.decodeIfPresent(String.self, forKey: .difficulty)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        primaryMuscles = try c.decodeIfPresent([String].self, forKey: .primaryMuscles) ?? []
        secondaryMuscles = try c.decodeIfPresent([String].self, forKey: .secondaryMuscles) ?? []
        muscleGroups = try c.decodeIfPresent([String].self, forKey: .muscleGroups) ?? []
        anatomicalTargetMuscles = try c.decodeIfPresent([String].self, forKey: .anatomicalTargetMuscles) ?? []
        anatomicalSynergistMuscles = try c.decodeIfPresent([String].self, forKey: .anatomicalSynergistMuscles) ?? []
        description = try c.decodeIfPresent(String.self, forKey: .description)
        instructions = try c.decodeIfPresent([ExerciseInstructionResource].self, forKey: .instructions) ?? []
        videoURL = try c.decodeIfPresent(String.self, forKey: .videoURL)
        videoEmbedURL = try c.decodeIfPresent(String.self, forKey: .videoEmbedURL)
        videoThumbnail = try c.decodeIfPresent(String.self, forKey: .videoThumbnail)
        imageURL = try c.decodeIfPresent(String.self, forKey: .imageURL)
        liftosaurURL = try c.decodeIfPresent(String.self, forKey: .liftosaurURL)
        liftosaurSlug = try c.decodeIfPresent(String.self, forKey: .liftosaurSlug)
        sportDiscipline = try c.decodeIfPresent(String.self, forKey: .sportDiscipline)
        frenchName = try c.decodeIfPresent(String.self, forKey: .frenchName)
        searchAliases = try c.decodeIfPresent([String].self, forKey: .searchAliases) ?? []
        laterality = try c.decodeIfPresent(String.self, forKey: .laterality)
    }
}

nonisolated struct MobilityCatalogResource: Codable, Equatable, Sendable {
    let name: String
    let stableKey: String
    let sources: [String]
    let category: String?
    let familyName: String?
    let trackingType: String?
    let defaultDurationSeconds: Int?
    let defaultRepetitions: Int?
    let difficulty: String?
    let equipment: String?
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let instructions: String?
    let benefits: String?
    let sanskritName: String?
    let met: Double?
    let imageURL: String?
    let svgURL: String?

    private enum CodingKeys: String, CodingKey {
        case name
        case stableKey = "seedkey"
        case sources, category
        case familyName = "familyname"
        case trackingType = "trackingtype"
        case defaultDurationSeconds = "defaultdurationseconds"
        case defaultRepetitions = "defaultrepetitions"
        case difficulty, equipment, primaryMuscles = "primarymuscles"
        case secondaryMuscles = "secondarymuscles", instructions, benefits
        case sanskritName = "sanskritname", met
        case imageURL = "imageurl", svgURL = "svgurl"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        stableKey = try c.decode(String.self, forKey: .stableKey)
        sources = try c.decodeIfPresent([String].self, forKey: .sources) ?? []
        category = try c.decodeIfPresent(String.self, forKey: .category)
        familyName = try c.decodeIfPresent(String.self, forKey: .familyName)
        trackingType = try c.decodeIfPresent(String.self, forKey: .trackingType)
        defaultDurationSeconds = try c.decodeIfPresent(Int.self, forKey: .defaultDurationSeconds)
        defaultRepetitions = try c.decodeIfPresent(Int.self, forKey: .defaultRepetitions)
        difficulty = try c.decodeIfPresent(String.self, forKey: .difficulty)
        equipment = try c.decodeIfPresent(String.self, forKey: .equipment)
        primaryMuscles = try c.decodeIfPresent([String].self, forKey: .primaryMuscles) ?? []
        secondaryMuscles = try c.decodeIfPresent([String].self, forKey: .secondaryMuscles) ?? []
        instructions = try c.decodeIfPresent(String.self, forKey: .instructions)
        benefits = try c.decodeIfPresent(String.self, forKey: .benefits)
        sanskritName = try c.decodeIfPresent(String.self, forKey: .sanskritName)
        if c.contains(.met) {
            if let value = try? c.decode(Double.self, forKey: .met) {
                met = value
            } else if let raw = try? c.decode(String.self, forKey: .met), let value = Double(raw) {
                met = value
            } else {
                throw DecodingError.dataCorruptedError(forKey: .met, in: c, debugDescription: "MET must be numeric")
            }
        } else {
            met = nil
        }
        imageURL = try c.decodeIfPresent(String.self, forKey: .imageURL)
        svgURL = try c.decodeIfPresent(String.self, forKey: .svgURL)
    }
}

nonisolated struct ProgramDayStructureResource: Codable, Equatable, Sendable {
    let day: String
    let exercises: [String]

    private enum CodingKeys: String, CodingKey { case day, exercises }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        day = try c.decode(String.self, forKey: .day)
        exercises = try c.decodeIfPresent([String].self, forKey: .exercises) ?? []
    }
}

nonisolated struct ProgramCatalogResource: Codable, Equatable, Sendable {
    let name: String
    let stableKey: String
    let url: String?
    let description: String?
    let author: String?
    let daysPerWeek: String?
    let durationWeeks: String?
    let difficulty: String?
    let category: String?
    let progressionModel: String?
    let routinesSummary: String?
    let daysStructure: [ProgramDayStructureResource]
    let equipment: String?
    let tags: [String]
    let imageURL: String?
    let sources: [String]

    private enum CodingKeys: String, CodingKey {
        case name, stableKey = "slug", url, description, author
        case daysPerWeek = "daysperweek"
        case durationWeeks = "durationweeks"
        case difficulty, category
        case progressionModel = "progressionmodel"
        case routinesSummary = "routinessummary"
        case daysStructure = "daysstructure"
        case equipment, tags, imageURL = "imageurl", sources
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        stableKey = try c.decode(String.self, forKey: .stableKey)
        url = try c.decodeIfPresent(String.self, forKey: .url)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        author = try c.decodeIfPresent(String.self, forKey: .author)
        daysPerWeek = try c.decodeIfPresent(String.self, forKey: .daysPerWeek)
        durationWeeks = try c.decodeIfPresent(String.self, forKey: .durationWeeks)
        difficulty = try c.decodeIfPresent(String.self, forKey: .difficulty)
        category = try c.decodeIfPresent(String.self, forKey: .category)
        progressionModel = try c.decodeIfPresent(String.self, forKey: .progressionModel)
        routinesSummary = try c.decodeIfPresent(String.self, forKey: .routinesSummary)
        daysStructure = try c.decodeIfPresent([ProgramDayStructureResource].self, forKey: .daysStructure) ?? []
        equipment = try c.decodeIfPresent(String.self, forKey: .equipment)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        imageURL = try c.decodeIfPresent(String.self, forKey: .imageURL)
        sources = try c.decodeIfPresent([String].self, forKey: .sources) ?? []
    }
}

nonisolated enum CatalogResourceValidationError: Error, Equatable, Sendable {
    case malformedJSON
    case duplicateStableKey(kind: String, key: String)
    case invalidStableKey(kind: String, key: String)
    case emptyName(kind: String, key: String)
    case invalidURL(kind: String, key: String, field: String, value: String)
    case nonFiniteMET(key: String)
}

nonisolated enum CatalogResourceDecoder {
    static let exerciseResourceName = "liftosaur_exercises_all"
    static let mobilityResourceName = "master_mobility_and_yoga_unified"
    static let programResourceName = "liftosaur_programs_all"

    static func decodeBundled(bundle: Bundle = .main) throws -> CatalogResourceCatalog {
        let exercises = try data(named: exerciseResourceName, subdirectory: "Exercises", bundle: bundle)
        let mobility = try data(named: mobilityResourceName, subdirectory: "Mobility", bundle: bundle)
        let programs = try data(named: programResourceName, subdirectory: "Programs", bundle: bundle)
        return try decode(exercises: exercises, mobility: mobility, programs: programs)
    }

    static func decode(
        exercises: Data,
        mobility: Data,
        programs: Data,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> CatalogResourceCatalog {
        let exerciseRecords = try decodeArray(ExerciseCatalogResource.self, from: exercises, decoder: decoder)
        let mobilityRecords = try decodeArray(MobilityCatalogResource.self, from: mobility, decoder: decoder)
        let programRecords = try decodeArray(ProgramCatalogResource.self, from: programs, decoder: decoder)
        try validate(exerciseRecords, kind: "exercise")
        try validate(mobilityRecords, kind: "mobility")
        try validate(programRecords, kind: "program")
        return CatalogResourceCatalog(
            exercises: exerciseRecords.map(normalized),
            mobilityDefinitions: mobilityRecords.map(normalized),
            programs: programRecords.map(normalized)
        )
    }

    private static func data(named name: String, subdirectory: String, bundle: Bundle) throws -> Data {
        // Xcode's synchronized resource groups currently flatten these files
        // into the application bundle. Keep the subdirectory lookup as a
        // compatibility path for conventional resource-group membership.
        guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: subdirectory)
            ?? bundle.url(forResource: name, withExtension: "json") else {
            throw CatalogResourceValidationError.malformedJSON
        }
        return try Data(contentsOf: url)
    }

    private static func decodeArray<Value: Decodable>(
        _ type: Value.Type,
        from data: Data,
        decoder: JSONDecoder
    ) throws -> [Value] {
        let normalizedData = try normalizeJSONKeys(in: stripUTF8BOM(data))
        do {
            return try decoder.decode([Value].self, from: normalizedData)
        } catch {
            throw CatalogResourceValidationError.malformedJSON
        }
    }

    private static func validate(_ records: [ExerciseCatalogResource], kind: String) throws {
        try validateStableKeys(records.map { ($0.stableKey, $0.name) }, kind: kind)
        for record in records {
            try validateURLs(record.stableKey, kind: kind, values: [
                ("videoURL", record.videoURL), ("videoEmbedURL", record.videoEmbedURL),
                ("videoThumbnail", record.videoThumbnail), ("imageURL", record.imageURL),
                ("liftosaurURL", record.liftosaurURL)
            ])
        }
    }

    private static func validate(_ records: [MobilityCatalogResource], kind: String) throws {
        try validateStableKeys(records.map { ($0.stableKey, $0.name) }, kind: kind)
        for record in records {
            if let met = record.met, !met.isFinite {
                throw CatalogResourceValidationError.nonFiniteMET(key: record.stableKey)
            }
            try validateURLs(record.stableKey, kind: kind, values: [("imageURL", record.imageURL), ("svgURL", record.svgURL)])
        }
    }

    private static func validate(_ records: [ProgramCatalogResource], kind: String) throws {
        try validateStableKeys(records.map { ($0.stableKey, $0.name) }, kind: kind)
        for record in records {
            try validateURLs(record.stableKey, kind: kind, values: [("url", record.url), ("imageURL", record.imageURL)])
        }
    }

    private static func validateStableKeys(_ values: [(String, String)], kind: String) throws {
        var seen = Set<String>()
        for (rawKey, name) in values {
            let key = normalizeStableKey(rawKey)
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw CatalogResourceValidationError.emptyName(kind: kind, key: key)
            }
            guard key.range(of: "^[a-z0-9][a-z0-9._-]*$", options: .regularExpression) != nil else {
                throw CatalogResourceValidationError.invalidStableKey(kind: kind, key: rawKey)
            }
            guard seen.insert(key).inserted else {
                throw CatalogResourceValidationError.duplicateStableKey(kind: kind, key: key)
            }
        }
    }

    private static func validateURLs(
        _ key: String,
        kind: String,
        values: [(String, String?)]
    ) throws {
        for (field, rawValue) in values {
            let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !value.isEmpty else { continue }
            guard let url = URL(string: value), let scheme = url.scheme?.lowercased(),
                  ["http", "https"].contains(scheme), url.host != nil else {
                throw CatalogResourceValidationError.invalidURL(kind: kind, key: key, field: field, value: value)
            }
        }
    }

    private static func normalizeStableKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func normalized(_ value: ExerciseCatalogResource) -> ExerciseCatalogResource {
        ExerciseCatalogResource(
            name: value.name.trimmingCharacters(in: .whitespacesAndNewlines), stableKey: normalizeStableKey(value.stableKey),
            sources: value.sources.map(normalizeToken), category: value.category, trackingType: value.trackingType,
            equipment: value.equipment, resistanceType: value.resistanceType, movementPattern: value.movementPattern,
            movementPatterns: value.movementPatterns, forceType: value.forceType,
            difficulty: value.difficulty, tags: value.tags.map(normalizeToken), primaryMuscles: value.primaryMuscles,
            secondaryMuscles: value.secondaryMuscles, muscleGroups: value.muscleGroups,
            anatomicalTargetMuscles: value.anatomicalTargetMuscles, anatomicalSynergistMuscles: value.anatomicalSynergistMuscles,
            description: value.description, instructions: value.instructions, videoURL: value.videoURL,
            videoEmbedURL: value.videoEmbedURL, videoThumbnail: value.videoThumbnail, imageURL: value.imageURL,
            liftosaurURL: value.liftosaurURL, liftosaurSlug: value.liftosaurSlug,
            sportDiscipline: value.sportDiscipline,
            frenchName: value.frenchName?.trimmingCharacters(in: .whitespacesAndNewlines),
            searchAliases: value.searchAliases.map(normalizeToken),
            laterality: value.laterality
        )
    }

    private static func normalized(_ value: MobilityCatalogResource) -> MobilityCatalogResource {
        MobilityCatalogResource(
            name: value.name.trimmingCharacters(in: .whitespacesAndNewlines), stableKey: normalizeStableKey(value.stableKey),
            sources: value.sources.map(normalizeToken), category: value.category, familyName: value.familyName,
            trackingType: value.trackingType, defaultDurationSeconds: value.defaultDurationSeconds,
            defaultRepetitions: value.defaultRepetitions, difficulty: value.difficulty, equipment: value.equipment,
            primaryMuscles: value.primaryMuscles, secondaryMuscles: value.secondaryMuscles, instructions: value.instructions,
            benefits: value.benefits, sanskritName: value.sanskritName, met: value.met, imageURL: value.imageURL, svgURL: value.svgURL
        )
    }

    private static func normalized(_ value: ProgramCatalogResource) -> ProgramCatalogResource {
        ProgramCatalogResource(
            name: value.name.trimmingCharacters(in: .whitespacesAndNewlines), stableKey: normalizeStableKey(value.stableKey),
            url: value.url, description: value.description, author: value.author, daysPerWeek: value.daysPerWeek,
            durationWeeks: value.durationWeeks, difficulty: value.difficulty, category: value.category,
            progressionModel: value.progressionModel, routinesSummary: value.routinesSummary, daysStructure: value.daysStructure,
            equipment: value.equipment, tags: value.tags.map(normalizeToken), imageURL: value.imageURL,
            sources: value.sources.map(normalizeToken)
        )
    }

    private static func normalizeToken(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func stripUTF8BOM(_ data: Data) -> Data {
        data.starts(with: [0xEF, 0xBB, 0xBF]) ? data.dropFirst(3) : data
    }

    private static func normalizeJSONKeys(in data: Data) throws -> Data {
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            throw CatalogResourceValidationError.malformedJSON
        }
        return try JSONSerialization.data(withJSONObject: normalizeJSONValue(object))
    }

    private static func normalizeJSONValue(_ value: Any) -> Any {
        if let object = value as? [String: Any] {
            return object.reduce(into: [String: Any]()) { result, entry in
                result[compactKey(entry.key)] = normalizeJSONValue(entry.value)
            }
        }
        if let array = value as? [Any] {
            return array.map(normalizeJSONValue)
        }
        return value
    }

    private static func compactKey(_ key: String) -> String {
        key.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
            .map { String($0).lowercased() }
            .joined()
    }
}

private extension ExerciseCatalogResource {
    nonisolated init(
        name: String, stableKey: String, sources: [String], category: String?, trackingType: String?, equipment: String?,
        resistanceType: String?, movementPattern: String?, movementPatterns: [String] = [], forceType: String?, difficulty: String?, tags: [String], primaryMuscles: [String],
        secondaryMuscles: [String], muscleGroups: [String], anatomicalTargetMuscles: [String], anatomicalSynergistMuscles: [String],
        description: String?, instructions: [ExerciseInstructionResource], videoURL: String?, videoEmbedURL: String?, videoThumbnail: String?,
        imageURL: String?, liftosaurURL: String?, liftosaurSlug: String?,
        sportDiscipline: String? = nil,
        frenchName: String? = nil, searchAliases: [String] = [], laterality: String? = nil
    ) {
        self.name = name; self.stableKey = stableKey; self.sources = sources; self.category = category
        self.trackingType = trackingType; self.equipment = equipment; self.resistanceType = resistanceType
        self.movementPattern = movementPattern; self.movementPatterns = movementPatterns.isEmpty ? (movementPattern.map { [$0] } ?? []) : movementPatterns
        self.forceType = forceType; self.difficulty = difficulty; self.tags = tags
        self.primaryMuscles = primaryMuscles; self.secondaryMuscles = secondaryMuscles; self.muscleGroups = muscleGroups
        self.anatomicalTargetMuscles = anatomicalTargetMuscles; self.anatomicalSynergistMuscles = anatomicalSynergistMuscles
        self.description = description; self.instructions = instructions; self.videoURL = videoURL
        self.videoEmbedURL = videoEmbedURL; self.videoThumbnail = videoThumbnail; self.imageURL = imageURL
        self.liftosaurURL = liftosaurURL; self.liftosaurSlug = liftosaurSlug
        self.sportDiscipline = sportDiscipline
        self.frenchName = frenchName; self.searchAliases = searchAliases; self.laterality = laterality
    }
}

private extension MobilityCatalogResource {
    nonisolated init(
        name: String, stableKey: String, sources: [String], category: String?, familyName: String?, trackingType: String?,
        defaultDurationSeconds: Int?, defaultRepetitions: Int?, difficulty: String?, equipment: String?, primaryMuscles: [String],
        secondaryMuscles: [String], instructions: String?, benefits: String?, sanskritName: String?, met: Double?, imageURL: String?, svgURL: String?
    ) {
        self.name = name; self.stableKey = stableKey; self.sources = sources; self.category = category; self.familyName = familyName
        self.trackingType = trackingType; self.defaultDurationSeconds = defaultDurationSeconds; self.defaultRepetitions = defaultRepetitions
        self.difficulty = difficulty; self.equipment = equipment; self.primaryMuscles = primaryMuscles; self.secondaryMuscles = secondaryMuscles
        self.instructions = instructions; self.benefits = benefits; self.sanskritName = sanskritName; self.met = met
        self.imageURL = imageURL; self.svgURL = svgURL
    }
}

private extension ProgramCatalogResource {
    nonisolated init(
        name: String, stableKey: String, url: String?, description: String?, author: String?, daysPerWeek: String?, durationWeeks: String?,
        difficulty: String?, category: String?, progressionModel: String?, routinesSummary: String?, daysStructure: [ProgramDayStructureResource],
        equipment: String?, tags: [String], imageURL: String?, sources: [String]
    ) {
        self.name = name; self.stableKey = stableKey; self.url = url; self.description = description; self.author = author
        self.daysPerWeek = daysPerWeek; self.durationWeeks = durationWeeks; self.difficulty = difficulty; self.category = category
        self.progressionModel = progressionModel; self.routinesSummary = routinesSummary; self.daysStructure = daysStructure
        self.equipment = equipment; self.tags = tags; self.imageURL = imageURL; self.sources = sources
    }
}
