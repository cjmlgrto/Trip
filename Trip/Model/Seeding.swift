import Foundation
import SwiftData

// MARK: - Seeding
//
// Decodes a trip JSON and writes the domain models. On first launch the bundled
// trip.json seeds the store; the editor can later replace the whole trip from a
// pasted/clipboard payload, or reset back to the bundled copy. The bundled JSON
// is authored by us, so a decode failure there is a programmer error and we fail
// loudly — but user-supplied JSON is validated and fails gracefully.

enum Seeding {

    // MARK: First-launch seed

    static func seedIfNeeded(_ context: ModelContext) {
        let alreadySeeded = (try? context.fetchCount(FetchDescriptor<TripDay>())) ?? 0
        guard alreadySeeded == 0 else { return }
        insert(bundledTrip(), into: context)
    }

    // MARK: Editing

    /// Validate a JSON payload without changing anything, returning a count
    /// summary. Throws if it doesn't match the trip schema.
    static func summary(forValidating data: Data) throws -> (days: Int, segments: Int) {
        let file = try JSONDecoder().decode(TripFile.self, from: data)
        let segments = file.trip.days.reduce(0) { $0 + $1.segments.count }
        return (file.trip.days.count, segments)
    }

    /// Replace all stored data with a user-supplied JSON payload. Throws (leaving
    /// the store untouched) if the JSON doesn't match the trip schema.
    static func replaceAll(in context: ModelContext, withJSON data: Data) throws {
        let file = try JSONDecoder().decode(TripFile.self, from: data)
        deleteAll(in: context)
        insert(file.trip, into: context)
        try? context.save()
    }

    /// Wipe all data and re-seed from the bundled trip.json.
    static func resetToBundled(in context: ModelContext) {
        deleteAll(in: context)
        insert(bundledTrip(), into: context)
        try? context.save()
    }

    /// Encode the current store back into the trip JSON schema, so the user can
    /// copy it out, tweak it, and paste it back through the editor. Returns nil
    /// only if there's nothing to read or encoding fails.
    static func exportJSON(from context: ModelContext) -> String? {
        let descriptor = FetchDescriptor<TripDay>(sortBy: [SortDescriptor(\.order)])
        guard let days = try? context.fetch(descriptor) else { return nil }
        let file = TripFile(trip: .init(days: days.map(dayDTO)))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(file) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// A short, human-readable reason a payload failed to validate.
    static func describe(_ error: Error) -> String {
        guard let decoding = error as? DecodingError else {
            return error.localizedDescription
        }
        switch decoding {
        case let .keyNotFound(key, _):
            return "Missing field “\(key.stringValue)”."
        case let .valueNotFound(_, context):
            return "Missing value for “\(context.codingPath.last?.stringValue ?? "field")”."
        case let .typeMismatch(_, context):
            return "Wrong type for “\(context.codingPath.last?.stringValue ?? "field")”."
        case let .dataCorrupted(context):
            return context.debugDescription
        @unknown default:
            return "That doesn’t look like a valid trip."
        }
    }

    // MARK: Internals

    private static func insert(_ trip: TripFile.TripDTO, into context: ModelContext) {
        for (dayIndex, day) in trip.days.enumerated() {
            let model = TripDay(order: dayIndex, date: day.date, label: day.label)
            context.insert(model)
            for (segIndex, seg) in day.segments.enumerated() {
                let segment = TripSegment(
                    id: seg.id, order: segIndex, kindRaw: seg.type, time: seg.time,
                    endTime: seg.endTime, title: seg.title, summary: seg.summary,
                    info: seg.info, detail: seg.detail, ref: seg.ref, seat: seg.seat,
                    attachments: (seg.files ?? []).map { Attachment(name: $0.name, label: $0.label) },
                    link: seg.link,
                    pinName: seg.pin?.name, pinAddress: seg.pin?.address,
                    latitude: seg.pin?.lat, longitude: seg.pin?.lng,
                    commuteMode: seg.commute?.mode, commuteSummary: seg.commute?.summary
                )
                segment.day = model
                context.insert(segment)
            }
        }
    }

    private static func deleteAll(in context: ModelContext) {
        try? context.delete(model: TripSegment.self)
        try? context.delete(model: TripDay.self)
    }

    private static func bundledTrip() -> TripFile.TripDTO {
        decode(TripFile.self, from: "trip").trip
    }

    // MARK: Model → DTO (for export)

    private static func dayDTO(_ day: TripDay) -> TripFile.DayDTO {
        TripFile.DayDTO(date: day.date, label: day.label,
                        segments: day.orderedSegments.map(segmentDTO))
    }

    private static func segmentDTO(_ segment: TripSegment) -> TripFile.SegmentDTO {
        TripFile.SegmentDTO(
            id: segment.id, type: segment.kindRaw, time: segment.time,
            title: segment.title, summary: segment.summary, detail: segment.detail,
            endTime: segment.endTime, info: segment.info, ref: segment.ref,
            seat: segment.seat, link: segment.link,
            files: segment.attachments.isEmpty
                ? nil
                : segment.attachments.map { TripFile.FileDTO(name: $0.name, label: $0.label) },
            commute: segment.commuteMode.map {
                TripFile.CommuteDTO(mode: $0, summary: segment.commuteSummary ?? "")
            },
            pin: pinDTO(segment)
        )
    }

    private static func pinDTO(_ segment: TripSegment) -> TripFile.PinDTO? {
        guard let latitude = segment.latitude, let longitude = segment.longitude else { return nil }
        return TripFile.PinDTO(name: segment.pinName ?? "", lat: latitude, lng: longitude,
                               address: segment.pinAddress ?? "")
    }

    private static func decode<T: Decodable>(_ type: T.Type, from resource: String) -> T {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            fatalError("Missing bundled \(resource).json")
        }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { fatalError("Failed to decode \(resource).json: \(error)") }
    }
}

// MARK: - JSON shapes

private struct TripFile: Codable {
    let trip: TripDTO
    struct TripDTO: Codable {
        let days: [DayDTO]
    }
    struct DayDTO: Codable {
        let date, label: String
        let segments: [SegmentDTO]
    }
    struct SegmentDTO: Codable {
        let id, type, time, title, summary, detail: String
        let endTime, info, ref, seat, link: String?
        let files: [FileDTO]?
        let commute: CommuteDTO?
        let pin: PinDTO?
    }
    struct FileDTO: Codable {
        let name, label: String
    }
    struct CommuteDTO: Codable {
        let mode, summary: String
    }
    struct PinDTO: Codable {
        let name: String, lat: Double, lng: Double, address: String
    }
}
