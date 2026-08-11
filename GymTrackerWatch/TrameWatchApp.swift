import SwiftUI

@main
struct TrameWatchApp: App {
    @State private var connectivity = WatchWorkoutConnectivity()

    var body: some Scene {
        WindowGroup {
            WatchWorkoutView(connectivity: connectivity)
        }
    }
}
