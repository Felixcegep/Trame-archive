import Foundation
import FoundationModels

/// On-device Foundation Models implementation. It receives only immutable
/// snapshots, creates one fresh session per request, and returns untrusted
/// structured data for `WorkoutDraftValidator` to resolve before the editor
/// can save or start anything.
struct FoundationWorkoutDraftGenerator: WorkoutDraftGenerator {
    func generateDraft(from input: WorkoutGenerationInput) async throws -> GeneratedWorkoutDraft {
        guard !input.availableExercises.isEmpty else { throw WorkoutDraftGeneratorError.noEligibleExercises }

        let isAvailable = await MainActor.run(body: { WorkoutGenerationAvailability.status().allowsGeneration })
        if isAvailable {
            let session = LanguageModelSession(instructions: Self.instructions(for: input))
            do {
                let response = try await session.respond(generating: WorkoutDraftResponse.self) {
                    Self.promptText(for: input)
                }
                return Self.draft(from: response.content)
            } catch is CancellationError {
                print("[GymTracker FoundationModels] Workout draft generation cancelled.")
                throw WorkoutDraftGeneratorError.cancelled
            } catch let error as WorkoutDraftGeneratorError {
                throw error
            } catch {
                print("[GymTracker FoundationModels Error] LanguageModelSession request failed: \(error). Using rule-based fallback draft.")
                let nsError = error as NSError
                print("  - Domain: \(nsError.domain), Code: \(nsError.code)")
                print("  - Localized Description: \(nsError.localizedDescription)")
            }
        } else {
            print("[GymTracker FoundationModels] SystemLanguageModel unavailable. Using rule-based fallback draft.")
        }

        return Self.deterministicFallbackDraft(for: input)
    }

    private static func deterministicFallbackDraft(for input: WorkoutGenerationInput) -> GeneratedWorkoutDraft {
        let requestedDuration = input.request.desiredDurationMinutes ?? input.profile.preferredDurationMinutes ?? 45
        let targetCount = min(max(3, requestedDuration / 12), input.availableExercises.count)
        let selectedExercises = Array(input.availableExercises.prefix(targetCount))

        let exercises = selectedExercises.map { option -> GeneratedWorkoutExercise in
            let isDurationOnly = option.trackingType == .duration
            return GeneratedWorkoutExercise(
                exerciseID: option.exerciseID,
                sets: 3,
                minimumRepetitions: isDurationOnly ? nil : 8,
                maximumRepetitions: isDurationOnly ? nil : 12,
                restSeconds: 90,
                targetRIR: 2,
                targetRPE: nil,
                notes: nil,
                groupID: nil
            )
        }

        let name: String
        if let text = input.request.requestText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            name = text.prefix(30).capitalized
        } else if let stimulus = input.request.preferredStimulus ?? input.profile.preferredStimulus {
            name = "\(stimulus.title) Workout"
        } else {
            name = "Personalized Workout"
        }

        return GeneratedWorkoutDraft(
            name: name,
            estimatedDurationMinutes: requestedDuration,
            rationale: "Selected \(exercises.count) exercises matching your preferences and available equipment.",
            exercises: exercises,
            assumptions: ["Generated using local rule-based drafting while Apple Intelligence model assets prepare on this device."],
            warnings: []
        )
    }

    private static func instructions(for input: WorkoutGenerationInput) -> String {
        var lines = [
            "You create one editable workout-template draft for Trame, a local-first strength-training app.",
            "A completed workout is immutable performed history. Your response is planned prescription only; never call it completed work.",
            "Use only exact exercise ids from the supplied catalogue. Never invent an id or replace an unavailable exercise with an invented name.",
            "Respect the explicit request, equipment, excluded exercises, and profile. Profile facts are optional preferences, never medical facts.",
            "Do not diagnose pain, injury, recovery, or readiness. If the request mentions pain, injury, rehabilitation, or treatment, return no exercises and put a short neutral explanation in warnings.",
            "Prefer one coherent session. Avoid redundant movement patterns unless the request explicitly asks for them.",
            "Use realistic set counts, repetitions, rest, and duration. Each exercise can specify RIR or RPE, but not both.",
            "A groupID means a contiguous superset; use the same non-empty groupID only for two or more adjacent exercises.",
            "Keep names and explanations concise. Explain assumptions briefly.",
            "Profile:",
            profileText(input.profile),
            "Recent completed-training summary (may be empty; do not infer recovery from missing data):",
            recentTrainingText(input.recentTraining),
            "Allowed exercise catalogue:",
        ]

        lines += input.availableExercises.map { exerciseText($0) }
        if !input.examples.isEmpty {
            lines.append("Examples of valid existing local workout structures. Demonstrate shape only; do not copy them blindly:")
            lines += input.examples.map { exampleText($0) }
        }
        return lines.joined(separator: "\n")
    }

    private static func promptText(for input: WorkoutGenerationInput) -> String {
        var lines = ["Create one draft using the supplied schema."]
        if let text = input.request.requestText { lines.append("User request: \(text)") }
        if let minutes = input.request.desiredDurationMinutes ?? input.profile.preferredDurationMinutes {
            lines.append("Desired duration: \(minutes) minutes.")
        }
        if let stimulus = input.request.preferredStimulus ?? input.profile.preferredStimulus {
            lines.append("Requested training stimulus: \(stimulus.rawValue).")
        }
        if input.request.isEmpty { lines.append("No explicit request was supplied; make a conservative, editable general workout from the profile.") }
        return lines.joined(separator: "\n")
    }

    private static func profileText(_ profile: WorkoutGenerationProfileSnapshot) -> String {
        [
            "experience=\(profile.experienceLevel?.rawValue ?? "unspecified")",
            "goal=\(profile.primaryGoal?.rawValue ?? "unspecified")",
            "preferredDurationMinutes=\(profile.preferredDurationMinutes.map(String.init) ?? "unspecified")",
            "equipment=\(profile.availableEquipment.map(\.rawValue).sorted().joined(separator: ", ").nilIfEmpty ?? "unspecified")",
            "avoidedExerciseIDs=\(profile.avoidedExerciseIDs.map(\.uuidString).sorted().joined(separator: ", ").nilIfEmpty ?? "none")",
            "preferredStimulus=\(profile.preferredStimulus?.rawValue ?? "unspecified")",
        ].joined(separator: "; ")
    }

    private static func recentTrainingText(_ summary: WorkoutGenerationRecentTrainingSummary) -> String {
        guard !summary.exposures.isEmpty else { return "No eligible exercise exposure was recorded in the recent window." }
        return summary.exposures.prefix(20).map {
            "- id=\($0.exerciseID.uuidString), completedWorkoutCount=\($0.completedWorkoutCount), lastPerformed=\($0.lastPerformedAt.formatted(.iso8601.year().month().day()))"
        }.joined(separator: "\n")
    }

    private static func exerciseText(_ exercise: WorkoutGenerationExerciseOption) -> String {
        [
            "- id=\(exercise.exerciseID.uuidString)",
            "name=\(exercise.name)",
            "frenchName=\(exercise.frenchName ?? "")",
            "tracking=\(exercise.trackingType.rawValue)",
            "equipment=\(exercise.equipmentType?.rawValue ?? "Unspecified")",
            "primaryMuscles=\(exercise.primaryMuscles.map(\.rawValue).joined(separator: ","))",
            "movement=\(exercise.movementPattern?.rawValue ?? "Unspecified")",
            "difficulty=\(exercise.difficulty?.rawValue ?? "Unspecified")",
        ].joined(separator: ", ")
    }

    private static func exampleText(_ example: WorkoutGenerationExample) -> String {
        let exercises = example.exercises.map {
            "\($0.exerciseID.uuidString): \($0.sets)x\($0.minimumRepetitions)-\($0.maximumRepetitions), rest \($0.restSeconds)s"
        }.joined(separator: " | ")
        return "- \(example.name): \(exercises)"
    }

    private static func draft(from response: WorkoutDraftResponse) -> GeneratedWorkoutDraft {
        GeneratedWorkoutDraft(
            name: response.name,
            estimatedDurationMinutes: response.estimatedDurationMinutes,
            rationale: response.rationale,
            exercises: response.exercises.compactMap { exercise in
                guard let id = UUID(uuidString: exercise.exerciseID) else { return nil }
                return GeneratedWorkoutExercise(
                    exerciseID: id,
                    sets: exercise.sets,
                    minimumRepetitions: exercise.minimumRepetitions,
                    maximumRepetitions: exercise.maximumRepetitions,
                    restSeconds: exercise.restSeconds,
                    targetRIR: exercise.targetRIR,
                    targetRPE: exercise.targetRPE,
                    notes: exercise.notes,
                    groupID: exercise.groupID?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                )
            },
            assumptions: response.assumptions,
            warnings: response.warnings
        )
    }
}

@Generable
private struct WorkoutDraftResponse: Sendable {
    @Guide(description: "A concise workout name.")
    var name: String
    @Guide(description: "Estimated total duration in minutes, from 10 through 180.")
    var estimatedDurationMinutes: Int
    @Guide(description: "A concise explanation of how this draft matches the request.")
    var rationale: String
    var exercises: [WorkoutDraftExerciseResponse]
    @Guide(description: "Brief assumptions made because information was absent.")
    var assumptions: [String]
    @Guide(description: "Brief constraint or safety warnings. Leave empty if none.")
    var warnings: [String]
}

@Generable
private struct WorkoutDraftExerciseResponse: Sendable {
    @Guide(description: "Must exactly equal an id in the supplied exercise catalogue.")
    var exerciseID: String
    @Guide(description: "Sets from 1 through 10.")
    var sets: Int
    @Guide(description: "Minimum repetitions when the exercise uses repetitions. Omit for duration-only exercises.")
    var minimumRepetitions: Int?
    @Guide(description: "Maximum repetitions when the exercise uses repetitions. Omit for duration-only exercises.")
    var maximumRepetitions: Int?
    @Guide(description: "Rest after each set in seconds, from 0 through 600.")
    var restSeconds: Int
    @Guide(description: "Reps in reserve from 0 through 10. Omit when using RPE.")
    var targetRIR: Int?
    @Guide(description: "Rate of perceived exertion from 1 through 10. Omit when using RIR.")
    var targetRPE: Double?
    var notes: String?
    @Guide(description: "A non-empty shared identifier only for adjacent superset members; otherwise omit it.")
    var groupID: String?
}

private extension String {
    nonisolated var nilIfEmpty: String? { isEmpty ? nil : self }
}
