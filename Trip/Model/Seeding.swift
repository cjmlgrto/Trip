import Foundation
import SwiftData

// MARK: - Seeding
//
// Decodes the bundled trip.json and inserts the domain models
// on first launch only. Everything ships in the app bundle, so this is fully
// offline. Bundled JSON is authored by us, so a decode failure is a programmer
// error and we fail loudly.

enum Seeding {

    static func seedIfNeeded(_ context: ModelContext) {
        let alreadySeeded = (try? context.fetchCount(FetchDescriptor<TripDay>())) ?? 0
        guard alreadySeeded == 0 else { return }

        let trip = decode(TripFile.self, from: "trip").trip

        for (dayIndex, day) in trip.days.enumerated() {
            let model = TripDay(order: dayIndex, date: day.date, label: day.label)
            context.insert(model)
            for (segIndex, seg) in day.segments.enumerated() {
                let segment = TripSegment(
                    id: seg.id, order: segIndex, kindRaw: seg.type, time: seg.time,
                    title: seg.title, summary: seg.summary, info: seg.info, detail: seg.detail,
                    ref: seg.ref, seat: seg.seat, file: seg.file, link: seg.link,
                    pinName: seg.pin?.name, pinAddress: seg.pin?.address,
                    latitude: seg.pin?.lat, longitude: seg.pin?.lng
                )
                segment.day = model
                context.insert(segment)
            }
        }
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

// MARK: - JSON shapes (decode-only)

private struct TripFile: Decodable {
    let trip: TripDTO
    struct TripDTO: Decodable {
        let days: [DayDTO]
    }
    struct DayDTO: Decodable {
        let date, label: String
        let segments: [SegmentDTO]
    }
    struct SegmentDTO: Decodable {
        let id, type, time, title, summary, detail: String
        let info, ref, seat, file, link: String?
        let pin: PinDTO?
    }
    struct PinDTO: Decodable {
        let name: String, lat: Double, lng: Double, address: String
    }
}
