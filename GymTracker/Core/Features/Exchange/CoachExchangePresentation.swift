import Foundation

#if !GYMTRACKER_EXTENSION

/// Small state contracts keep empty/loading/error/ready semantics testable
/// without coupling the exchange policy to SwiftUI or persistence.
enum CoachExchangeReportUIState: Equatable {
    case loading
    case empty
    case invalidDateRange
    case ready(TrainingReportArtifactPreview)
}

enum CoachExchangeImportUIState: Equatable {
    case idle
    case preview(PortableImportPreview)
    case failed(String)
}

#endif
