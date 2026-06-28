import SwiftUI

// MARK: - Rows
//
// The list-view components from the design. State (Complete / Current /
// Upcoming) drives color only — all type comes from system text styles and all
// color from semantic styles, so everything tracks Dynamic Type and dark mode.

/// Visual state of an itinerary item, mirroring the design's layer-group names.
enum ItemState {
    case complete, current, upcoming

    init(isCompleted: Bool, isCurrent: Bool) {
        if isCompleted { self = .complete }
        else if isCurrent { self = .current }
        else { self = .upcoming }
    }

    var indicator: AnyShapeStyle {
        switch self {
        case .complete: AnyShapeStyle(.quaternary)
        case .current:  AnyShapeStyle(.red)
        case .upcoming: AnyShapeStyle(Color(.systemGray))
        }
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
    var info: AnyShapeStyle {
        self == .complete ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.secondary)
    }
    var time: AnyShapeStyle {
        switch self {
        case .complete: AnyShapeStyle(.quaternary)
        case .current:  AnyShapeStyle(.red)
        case .upcoming: AnyShapeStyle(.secondary)
        }
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

    private var state: ItemState {
        ItemState(isCompleted: segment.isCompleted, isCurrent: isCurrent)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Capsule()
                .fill(state.indicator)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(segment.title)
                    .font(.headline)
                    .foregroundStyle(state.title)
                Text(segment.summary)
                    .font(.body)
                    .foregroundStyle(state.subtitle)
                if let info = segment.info, !info.isEmpty {
                    Text(info)
                        .font(.footnote)
                        .foregroundStyle(state.info)
                }
            }

            Spacer(minLength: 8)

            Text(segment.displayTime)
                .font(.footnote)
                .foregroundStyle(state.time)
        }
    }
}
