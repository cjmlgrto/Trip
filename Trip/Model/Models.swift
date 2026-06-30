import Foundation
import SwiftData
import CoreLocation

// MARK: - App Group
//
// Shared container identifier used by both the app and the widget so they read
// and write the same SwiftData store.
enum AppGroup {
    static let identifier = "group.carlos-m.trips"
}

// MARK: - Domain models (SwiftData)
//
// The trip is seeded once from the bundled JSON (see Seeding.swift), then these
// models are the single source of truth. Completion is just a stored property
// we mutate directly — no side tables, no dictionaries. Fully offline.

@Model
final class TripDay {
    var order: Int
    var date: String      // "2026-06-29"
    var label: String

    @Relationship(deleteRule: .cascade, inverse: \TripSegment.day)
    var segments: [TripSegment] = []

    init(order: Int, date: String, label: String) {
        self.order = order
        self.date = date
        self.label = label
    }

    /// Segments in their itinerary order.
    var orderedSegments: [TripSegment] {
        segments.sorted { $0.order < $1.order }
    }
}

@Model
final class TripSegment {
    var id: String
    var order: Int
    var kindRaw: String
    var time: String
    var endTime: String?
    var title: String
    var summary: String
    var info: String?
    var detail: String
    var ref: String?
    var seat: String?
    var attachments: [Attachment]
    var link: String?
    var pinName: String?
    var pinAddress: String?
    var latitude: Double?
    var longitude: Double?
    var commuteMode: String?      // how you get to this event: "walk" / "transit"
    var commuteSummary: String?   // e.g. "An 8 minute walk from Gare du Nord"
    var isCompleted: Bool

    var day: TripDay?

    init(id: String, order: Int, kindRaw: String, time: String, endTime: String?, title: String,
         summary: String, info: String?, detail: String, ref: String?, seat: String?,
         attachments: [Attachment], link: String?, pinName: String?, pinAddress: String?,
         latitude: Double?, longitude: Double?, commuteMode: String?, commuteSummary: String?) {
        self.id = id
        self.order = order
        self.kindRaw = kindRaw
        self.time = time
        self.endTime = endTime
        self.title = title
        self.summary = summary
        self.info = info
        self.detail = detail
        self.ref = ref
        self.seat = seat
        self.attachments = attachments
        self.link = link
        self.pinName = pinName
        self.pinAddress = pinAddress
        self.latitude = latitude
        self.longitude = longitude
        self.commuteMode = commuteMode
        self.commuteSummary = commuteSummary
        self.isCompleted = false
    }

    var kind: SegmentKind { SegmentKind(rawValue: kindRaw) ?? .activity }
    var displayTime: String { DateText.clockTime(time) }

    /// "5:55 PM to 6:15 PM", or just the start when there's no end time.
    var timeRange: String {
        guard let endTime, !endTime.isEmpty else { return displayTime }
        return "\(displayTime) to \(DateText.clockTime(endTime))"
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Attachment

/// A bundled document linked to a segment (ticket, confirmation, travel doc).
/// Stored inline on the segment as a Codable value type.
struct Attachment: Codable, Hashable {
    var name: String      // bundled file name, e.g. "eurostar-confirmation.pdf"
    var label: String     // button title, e.g. "Eurostar ticket"
}

// MARK: - Segment kind

enum SegmentKind: String, CaseIterable {
    case flight, train, hotel, activity, meal, wedding
}

// MARK: - Date formatting helpers

enum DateText {
    static func clockTime(_ time: String) -> String {
        guard !time.isEmpty, let date = hhmm.date(from: time) else { return time }
        return clock.string(from: date)
    }

    /// Combines a day + "HH:mm" time into a local Date, for Now/current logic.
    static func dateTime(day: String, time: String) -> Date? {
        guard !time.isEmpty else { return ymd.date(from: day) }
        return ymdhm.date(from: "\(day) \(time)")
    }

    /// "yyyy-MM-dd" key for a date, to compare against a day's `date`.
    static func dayKey(_ date: Date) -> String {
        ymd.string(from: date)
    }

    /// Parse a "yyyy-MM-dd" day key back into a Date (midnight, POSIX).
    static func day(_ key: String) -> Date? {
        ymd.date(from: key)
    }

    private static let ymd: DateFormatter = {
        let f = DateFormatter(); f.locale = .init(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"; return f
    }()
    private static let ymdhm: DateFormatter = {
        let f = DateFormatter(); f.locale = .init(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm"; return f
    }()
    private static let hhmm: DateFormatter = {
        let f = DateFormatter(); f.locale = .init(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"; return f
    }()
    private static let clock: DateFormatter = {
        let f = DateFormatter(); f.locale = .init(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm a"; return f
    }()
}
