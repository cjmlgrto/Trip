import Foundation

// MARK: - Widget data
//
// Self-contained: the widget reads a small snapshot the app publishes into the
// shared App Group container (see WidgetSnapshot in the app). No SwiftData
// models, no bundled JSON — a single source of truth lives in the app.

private let appGroupIdentifier = "group.carlos-m.trips"
private let snapshotFileName = "widget-snapshot.json"

/// Matches the app's `WidgetSnapshotEvent` shape.
private struct SnapshotEvent: Codable {
    let id: String
    let kind: String
    let title: String
    let location: String
    let timeRange: String
    let start: Date
    let end: Date?
}

struct WidgetEvent: Identifiable {
    let id: String
    let kind: String
    let title: String
    let location: String
    let timeRange: String
    let start: Date
    let end: Date?
}

/// One event shown in the widget, with its role.
struct WidgetItem: Identifiable {
    let event: WidgetEvent
    let inProgress: Bool
    let progress: Double?      // 0...1 along the rail, when in progress with a known end
    var id: String { event.id }
}

enum WidgetTripData {
    /// All events from the shared snapshot, sorted by start time.
    static func events() -> [WidgetEvent] {
        guard let url = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
                .appendingPathComponent(snapshotFileName),
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode([SnapshotEvent].self, from: data)
        else { return [] }

        return snapshot
            .map { WidgetEvent(id: $0.id, kind: $0.kind, title: $0.title,
                               location: $0.location, timeRange: $0.timeRange,
                               start: $0.start, end: $0.end) }
            .sorted { $0.start < $1.start }
    }

    /// The in-progress event (if any) followed by the upcoming events, in order.
    static func lineup(at now: Date, from events: [WidgetEvent]) -> [WidgetItem] {
        var items: [WidgetItem] = []
        if let current = events.first(where: { event in
            event.start <= now && now < (event.end ?? event.start.addingTimeInterval(3600))
        }) {
            var progress: Double?
            if let end = current.end, end > current.start {
                progress = min(max(now.timeIntervalSince(current.start)
                                   / end.timeIntervalSince(current.start), 0), 1)
            }
            items.append(WidgetItem(event: current, inProgress: true, progress: progress))
        }
        for event in events where event.start > now {
            items.append(WidgetItem(event: event, inProgress: false, progress: nil))
        }
        return items
    }

    /// Timestamps at which the displayed lineup changes, so the timeline
    /// refreshes exactly then.
    static func refreshDates(after now: Date, from events: [WidgetEvent]) -> [Date] {
        var dates: Set<Date> = [now]
        for event in events {
            if event.start > now { dates.insert(event.start) }
            if let end = event.end, end > now { dates.insert(end) }
        }
        return dates.sorted()
    }

    /// "Sunday, Jun 28" for the widget header.
    static func longDate(_ date: Date) -> String { longFormatter.string(from: date) }

    private static let longFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"; return f
    }()
}
