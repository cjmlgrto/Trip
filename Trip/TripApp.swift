import SwiftUI
import SwiftData

@main
struct TripApp: App {
    var body: some Scene {
        WindowGroup {
            RootMapView()
        }
        .modelContainer(for: [TripDay.self, TripSegment.self])
    }
}
