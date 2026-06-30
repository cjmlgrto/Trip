import SwiftUI
import UIKit

// MARK: - Rows
//
// The list-view components from the design. State (Complete / Current /
// Upcoming) drives color only — all type comes from system text styles and all
// color from semantic styles, so everything tracks Dynamic Type and dark mode.

// MARK: - Category styling
//
// Upcoming items are color-coded by category using system colors from the blue
// family, so the single red "current" indicator always stands out.

extension SegmentKind {
    var indicatorColor: Color {
        switch self {
        case .flight:   Color(.systemBlue)
        case .train:    Color(.systemCyan)
        case .hotel:    Color(.systemIndigo)
        case .activity: Color(.systemTeal)
        case .meal:     Color(.systemMint)
        case .wedding:  Color(.systemPurple)
        }
    }

    /// SF Symbol for the map pin balloon.
    var symbol: String {
        switch self {
        case .flight:   "airplane"
        case .train:    "tram.fill"
        case .hotel:    "bed.double.fill"
        case .activity: "building.columns.fill"
        case .meal:     "fork.knife"
        case .wedding:  "heart.fill"
        }
    }

    /// Plural label for the filter menu.
    var label: String {
        switch self {
        case .flight:   "Flights"
        case .train:    "Trains"
        case .hotel:    "Hotels"
        case .activity: "Activities"
        case .meal:     "Meals"
        case .wedding:  "Wedding"
        }
    }

    var indicatorUIColor: UIColor {
        switch self {
        case .flight:   .systemBlue
        case .train:    .systemCyan
        case .hotel:    .systemIndigo
        case .activity: .systemTeal
        case .meal:     .systemMint
        case .wedding:  .systemPurple
        }
    }

    /// A filled circle in the category color, for use as a menu icon. Rendered
    /// as an original-mode image so the menu keeps the color instead of
    /// templating it to the tint.
    var swatchImage: UIImage {
        let diameter: CGFloat = 12
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter))
        return renderer.image { context in
            indicatorUIColor.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: diameter, height: diameter))
        }.withRenderingMode(.alwaysOriginal)
    }

    /// Categories ordered along the color spectrum (mint → teal → cyan → blue
    /// → indigo → purple), for the filter menu.
    static let spectrumOrder: [SegmentKind] = [.meal, .activity, .train, .flight, .hotel, .wedding]
}

/// How much of each row to show. Pinching out collapses tertiary then
/// secondary lines; pinching in restores them.
enum DetailLevel: Int {
    case minimal = 0   // title only
    case medium = 1    // title + location
    case full = 2      // title + location + time

    var collapsed: DetailLevel { DetailLevel(rawValue: rawValue - 1) ?? .minimal }
    var expanded: DetailLevel { DetailLevel(rawValue: rawValue + 1) ?? .full }

    var showsSubtitle: Bool { rawValue >= DetailLevel.medium.rawValue }
    var showsTime: Bool { rawValue >= DetailLevel.full.rawValue }
}

/// Visual state of an itinerary item, mirroring the design's layer-group names.
enum ItemState {
    case complete, current, upcoming

    init(isCompleted: Bool, isCurrent: Bool) {
        if isCompleted { self = .complete }
        else if isCurrent { self = .current }
        else { self = .upcoming }
    }

    var title: AnyShapeStyle {
        switch self {
        case .complete: AnyShapeStyle(.quaternary)
        case .current:  AnyShapeStyle(.red)
        case .upcoming: AnyShapeStyle(.primary)
        }
    }
    var subtitle: AnyShapeStyle {
        self == .complete ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.primary)
    }
    var time: AnyShapeStyle {
        switch self {
        case .complete: AnyShapeStyle(.quaternary)
        case .current:  AnyShapeStyle(.red)
        case .upcoming: AnyShapeStyle(.secondary)
        }
    }
}

/// A quiet connector between events: how you get to the next one.
struct CommuteCard: View {
    let mode: String
    let summary: String

    private var symbol: String {
        switch mode {
        case "transit": "tram.fill"
        case "drive":   "car.fill"
        default:        "figure.walk"
        }
    }

    var body: some View {
        // First-baseline alignment keeps the icon on the topmost line's baseline
        // when the summary wraps to two lines, instead of centering on the block.
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol)
                .font(.footnote)
                .frame(width: 4)            // sits in the indicator rail's column
            Text(summary)
                .font(.footnote)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.primary)
    }
}

/// The big day header: "Sunday, Jun 28" over a one-line summary.
struct DayHeaderView: View {
    let title: String
    let summary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            Text(summary)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

/// A single itinerary item: leading indicator rail, title/subtitle/optional
/// info, and a trailing time.
struct SegmentRow: View {
    let segment: TripSegment
    let isCurrent: Bool
    var now: Date = Date()
    var detail: DetailLevel = .full

    private var state: ItemState {
        ItemState(isCompleted: segment.isCompleted, isCurrent: isCurrent)
    }

    /// Complete dims, current is red; otherwise the category color.
    private var indicatorStyle: AnyShapeStyle {
        switch state {
        case .complete: AnyShapeStyle(.quaternary)
        case .current:  AnyShapeStyle(.red)
        case .upcoming: AnyShapeStyle(segment.kind.indicatorColor)
        }
    }

    /// Fraction (0...1) through the current event by wall-clock time, if it has
    /// a known end. Drives the position of the progress dot.
    private var progress: Double? {
        guard state == .current,
              let start = DateText.dateTime(day: segment.day?.date ?? "", time: segment.time),
              let endText = segment.endTime, !endText.isEmpty,
              let end = DateText.dateTime(day: segment.day?.date ?? "", time: endText),
              end > start else { return nil }
        let fraction = now.timeIntervalSince(start) / end.timeIntervalSince(start)
        return min(max(fraction, 0), 1)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Capsule()
                .fill(indicatorStyle)
                .frame(width: 4)
                .overlay { progressDot }

            VStack(alignment: .leading, spacing: 4) {
                Text(segment.title)
                    .font(.headline)
                    .foregroundStyle(state.title)
                if detail.showsSubtitle {
                    Text(segment.summary)
                        .font(.body)
                        .foregroundStyle(state.subtitle)
                        .transition(.opacity)
                }
                if detail.showsTime {
                    Text(segment.timeRange)
                        .font(.footnote)
                        .foregroundStyle(state.time)
                        .transition(.opacity)
                }
            }

            Spacer(minLength: 0)
        }
        .animation(.trip, value: segment.isCompleted)
    }

    /// A red dot with a system-background halo, slid down the bar by `progress`.
    @ViewBuilder
    private var progressDot: some View {
        if let progress {
            GeometryReader { geo in
                ZStack {
                    Circle().fill(Color(.systemBackground)).frame(width: 12, height: 12)
                    Circle().fill(.red).frame(width: 8, height: 8)
                }
                .position(x: geo.size.width / 2, y: geo.size.height * progress)
                .animation(.trip, value: progress)
            }
        }
    }
}

#Preview("Commute cards") {
    List {
        CommuteCard(mode: "walk", summary: "An 8 minute walk from Gare du Nord")
            .listRowSeparator(.hidden)
        CommuteCard(mode: "transit",
                    summary: "Take the Piccadilly line direct from Heathrow to King's Cross St Pancras, about 50 to 60 minutes with no changes")
            .listRowSeparator(.hidden)
    }
    .listStyle(.plain)
}

#Preview("Current row progress") {
    CurrentRowPreview()
}

private struct CurrentRowPreview: View {
    var body: some View {
        let day = TripDay(order: 0, date: "2026-06-29", label: "Day")
        let segment = TripSegment(
            id: "preview", order: 0, kindRaw: "activity", time: "15:00", endTime: "18:00",
            title: "Wander Notting Hill", summary: "Portobello Road", info: nil, detail: "",
            ref: nil, seat: nil, attachments: [], link: nil, pinName: nil, pinAddress: nil,
            latitude: nil, longitude: nil, commuteMode: nil, commuteSummary: nil
        )
        segment.day = day
        let now = DateText.dateTime(day: "2026-06-29", time: "16:30") ?? Date()
        return List {
            SegmentRow(segment: segment, isCurrent: true, now: now, detail: .full)
                .listRowSeparator(.hidden)
            SegmentRow(segment: segment, isCurrent: true, now: now, detail: .medium)
                .listRowSeparator(.hidden)
            SegmentRow(segment: segment, isCurrent: true, now: now, detail: .minimal)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
    }
}
