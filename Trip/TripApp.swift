import SwiftUI
import SwiftData

@main
struct TripApp: App {
    var body: some Scene {
        WindowGroup {
            TripListView()
        }
        .modelContainer(for: [TripDay.self, TripSegment.self])
    }
}
