import Foundation

/// Persists only optional draft preferences using the app's existing local
/// preference pattern. This is intentionally not a SwiftData entity: it has
/// no relationship to training history and can be discarded independently.
@MainActor
enum WorkoutGenerationPreferencesStore {
    private static let key = "workoutGenerationPreferences.v1"

    static func load(defaults: UserDefaults = .standard) -> WorkoutGenerationPreferences {
        guard
            let data = defaults.data(forKey: key),
            let preferences = try? JSONDecoder().decode(WorkoutGenerationPreferences.self, from: data)
        else {
            return WorkoutGenerationPreferences()
        }
        return preferences
    }

    static func save(_ preferences: WorkoutGenerationPreferences, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: key)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}
