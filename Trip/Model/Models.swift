import Foundation
import SwiftData
import CoreLocation

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
    var isCompleted: Bool

    var day: TripDay?

    init(id: String, order: Int, kindRaw: String, time: String, title: String,
         summary: String, info: String?, detail: String, ref: String?, seat: String?,
         attachments: [Attachment], link: String?, pinName: String?, pinAddress: String?,
         latitude: Double?, longitude: Double?) {
        self.id = id
        self.order = order
        self.kindRaw = kindRaw
        self.time = time
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
        self.isCompleted = false
    }

    var kind: SegmentKind { SegmentKind(rawValue: kindRaw) ?? .activity }
    var displayTime: String { DateText.clockTime(time) }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Free-text haystack for `.searchable`.
    var matchText: String {
        [title, summary, info ?? "", detail, ref ?? "", seat ?? "", pinName ?? "", time]
            .joined(separator: " ").lowercased()
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

enum SegmentKind: String {
    case flight, train, hotel, activity, meal, wedding

    var symbol: String {
        switch self {
        case .flight:   "airplane"
        case .train:    "tram.fill"
        case .hotel:    "bed.double.fill"
        case .activity: "building.columns"
        case .meal:     "fork.knife"
        case .wedding:  "heart.fill"
        }
    }
}

// MARK: - Date formatting helpers

enum DateText {
    static func clockTime(_ time: String) -> String {
        guard !time.isEmpty, let date = hhmm.date(from: time) else { return time }
        return clock.string(from: date)
    }

    /// "Sunday, Jun 28" — the day-header title.
    static func longDate(_ day: String) -> String {
        guard let date = ymd.date(from: day) else { return day }
        return longDay.string(from: date)
    }

    /// Combines a day + "HH:mm" time into a local Date, for Now/current logic.
    static func dateTime(day: String, time: String) -> Date? {
        guard !time.isEmpty else { return ymd.date(from: day) }
        return ymdhm.date(from: "\(day) \(time)")
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
    private static let longDay: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"; return f
    }()
}
