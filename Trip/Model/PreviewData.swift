import SwiftData

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
}
