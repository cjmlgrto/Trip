import SwiftUI
import SwiftData

@main
struct TripApp: App {
    var body: some Scene {
        WindowGroup {
            TripListView()
        }
        .modelContainer(for: [TripInfo.self, TripDay.self, TripSegment.self])
    }
}
