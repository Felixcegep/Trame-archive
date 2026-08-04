import Foundation
import Combine
import CloudKit

public enum UserCloudAccountStatus: String, Sendable {
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    case couldNotDetermine
}

/// Observes and reports current iCloud account availability using `CKContainer`.
@MainActor
public final class CloudAccountStatusService: ObservableObject {
    @Published public private(set) var status: UserCloudAccountStatus = .couldNotDetermine

    public init() {}

    public func checkAccountStatus() async {
        do {
            let ckStatus = try await CKContainer.default().accountStatus()
            switch ckStatus {
            case .available:
                status = .available
            case .noAccount:
                status = .noAccount
            case .restricted:
                status = .restricted
            case .couldNotDetermine:
                status = .couldNotDetermine
            case .temporarilyUnavailable:
                status = .temporarilyUnavailable
            @unknown default:
                status = .couldNotDetermine
            }
        } catch {
            status = .couldNotDetermine
        }
    }
}
