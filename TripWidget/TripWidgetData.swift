import Foundation

// MARK: - Widget data
//
// The widget runs in its own process and only needs static trip content plus
// the clock to show the current and next event, so it reads a bundled copy of
// trip.json directly — no SwiftData, no App Group. (If trip.json changes, copy
// it into the widget target too.)

struct WidgetEvent: Identifiable {
    let id: String
    let kind: String
    let title: String
    let location: String
    let start: Date
    let end: Date?

    var timeRange: String {
        let startText = WidgetDate.clock(start)
        guard let end else { return startText }
        return "\(startText) to \(WidgetDate.clock(end))"
    }
}

/// One line shown in the widget: an event plus its role label.
struct WidgetItem: Identifiable {
    let label: String          // "Now" / "Next" / "Then"
    let event: WidgetEvent
    let inProgress: Bool
    var id: String { event.id }
}

enum WidgetTripData {
    /// All events, sorted by start time. Loaded once.
    static let events: [WidgetEvent] = load()

    /// The current (in-progress) event and the upcoming ones, capped at two
    /// lines total.
    static func lineup(at now: Date) -> [WidgetItem] {
        var items: [WidgetItem] = []
        if let current = events.first(where: { event in
            event.start <= now && now < (event.end ?? event.start.addingTimeInterval(3600))
        }) {
            items.append(WidgetItem(label: "Now", event: current, inProgress: true))
        }
        let upcoming = events.filter { $0.start > now }
        let labels = ["Next", "Then"]
        for (index, event) in upcoming.prefix(2 - items.count).enumerated() {
            items.append(WidgetItem(label: labels[min(index, labels.count - 1)],
                                    event: event, inProgress: false))
        }
        return items
    }

    /// Timestamps at which the displayed lineup changes (event starts and ends),
    /// so the widget timeline refreshes exactly then.
    static func refreshDates(after now: Date) -> [Date] {
        var dates: Set<Date> = [now]
        for event in events {
            if event.start > now { dates.insert(event.start) }
            if let end = event.end, end > now { dates.insert(end) }
        }
        return dates.sorted()
    }

    private static func load() -> [WidgetEvent] {
        guard let url = Bundle.main.url(forResource: "trip", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(TripFile.self, from: data) else {
            return []
        }
        let events = file.trip.days.flatMap { day in
            day.segments.compactMap { seg -> WidgetEvent? in
                guard let start = WidgetDate.dateTime(day: day.date, time: seg.time) else { return nil }
                return WidgetEvent(
                    id: seg.id, kind: seg.type, title: seg.title, location: seg.summary,
                    start: start,
                    end: seg.endTime.flatMap { WidgetDate.dateTime(day: day.date, time: $0) }
                )
            }
        }
        return events.sorted { $0.start < $1.start }
    }

    // Decode-only shapes (a subset of trip.json).
    private struct TripFile: Decodable {
        let trip: TripDTO
        struct TripDTO: Decodable { let days: [DayDTO] }
        struct DayDTO: Decodable { let date: String; let segments: [SegmentDTO] }
        struct SegmentDTO: Decodable {
            let id, type, time, title, summary: String
            let endTime: String?
        }
    }
}

// MARK: - Date helpers

enum WidgetDate {
    static func clock(_ date: Date) -> String { clockFormatter.string(from: date) }

    static func dateTime(day: String, time: String) -> Date? {
        ymdhm.date(from: "\(day) \(time)")
    }

    private static let ymdhm: DateFormatter = {
        let f = DateFormatter(); f.locale = .init(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm"; return f
    }()
    private static let clockFormatter: DateFormatter = {
        let f = DateFormatter(); f.locale = .init(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm a"; return f
    }()
}
