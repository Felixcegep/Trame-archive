import Foundation

/// A small, reusable validation result for feature forms. Domain rules remain
/// in their owning service or model; this type only transports the result.
struct ValidationIssue: Identifiable, Equatable, Sendable {
    enum Severity: Equatable, Sendable {
        case error
        case warning
    }

    let id: String
    let severity: Severity
    let message: String
    let fieldID: String?

    init(
        id: String = UUID().uuidString,
        severity: Severity,
        message: String,
        fieldID: String? = nil
    ) {
        self.id = id
        self.severity = severity
        self.message = message
        self.fieldID = fieldID
    }
}
