import Foundation
import SwiftData
import WidgetKit

// MARK: - Widget snapshot
//
// The widget can't reach the app's SwiftData store without sharing the model
// types, so instead the app publishes a small Codable snapshot of the events
// into the shared App Group container. The widget reads that — keeping a single
// source of truth (this store) with no bundled JSON copy.

/// The shape shared with the widget (the widget declares a matching struct).
struct WidgetSnapshotEvent: Codable {
    let id: String
    let kind: String
    let title: String
    let location: String
    let timeRange: String
    let start: Date
    let end: Date?
}

enum WidgetSnapshot {
    static let fileName = "widget-snapshot.json"

    static var url: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)?
            .appendingPathComponent(fileName)
    }

    /// Writes the current events to the shared container and refreshes the widget.
    static func publish(from context: ModelContext) {
        guard let url else { return }
        let segments = (try? context.fetch(FetchDescriptor<TripSegment>())) ?? []
        let events = segments
            .compactMap { segment -> WidgetSnapshotEvent? in
                let day = segment.day?.date ?? ""
                guard let start = DateText.dateTime(day: day, time: segment.time) else { return nil }
                let end = segment.endTime.flatMap { DateText.dateTime(day: day, time: $0) }
                return WidgetSnapshotEvent(
                    id: segment.id, kind: segment.kindRaw, title: segment.title,
                    location: segment.summary, timeRange: segment.timeRange,
                    start: start, end: end
                )
            }
            .sorted { $0.start < $1.start }

        guard let data = try? JSONEncoder().encode(events) else { return }
        try? data.write(to: url, options: .atomic)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
