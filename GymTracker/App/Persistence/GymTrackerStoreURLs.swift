import Foundation

/// Centralized store URL provider for GymTracker's SwiftData configurations.
public enum GymTrackerStoreURLs {
    /// Returns the Application Support directory URL for GymTracker.
    public static var applicationSupportDirectory: URL {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = urls[0].appendingPathComponent("GymTracker", isDirectory: true)
        if !FileManager.default.fileExists(atPath: appSupport.path) {
            try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }
        return appSupport
    }

    /// Default URL for the primary local/cloud user store file.
    public static var defaultUserStoreURL: URL {
        applicationSupportDirectory.appendingPathComponent("default.store")
    }

    /// URL for the local-only device configuration store file.
    public static var localDeviceStoreURL: URL {
        applicationSupportDirectory.appendingPathComponent("local_device.store")
    }
}
