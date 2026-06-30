import SwiftData
import Foundation

// MARK: - Preview support
//
// An in-memory container seeded from the bundled JSON, for SwiftUI previews.

@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        let container = try! ModelContainer(
            for: TripDay.self, TripSegment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        Seeding.seedIfNeeded(container.mainContext)
        return container
    }()

    /// The seeded trip days, in itinerary order — handy for component previews.
    static var days: [TripDay] {
        let descriptor = FetchDescriptor<TripDay>(sortBy: [SortDescriptor(\.order)])
        return (try? container.mainContext.fetch(descriptor)) ?? []
    }
}
