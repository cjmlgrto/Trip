import WidgetKit
import SwiftUI

// MARK: - Timeline provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> TripEntry {
        TripEntry(date: .now, items: WidgetTripData.lineup(at: .now))
    }

    func getSnapshot(in context: Context, completion: @escaping (TripEntry) -> Void) {
        completion(TripEntry(date: .now, items: WidgetTripData.lineup(at: .now)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TripEntry>) -> Void) {
        let entries = WidgetTripData.refreshDates(after: .now).map { date in
            TripEntry(date: date, items: WidgetTripData.lineup(at: date))
        }
        completion(Timeline(entries: entries.isEmpty ? [placeholder(in: context)] : entries,
                            policy: .atEnd))
    }
}

struct TripEntry: TimelineEntry {
    let date: Date
    let items: [WidgetItem]
}

// MARK: - Per-family layout (system text styles, scaled to the widget size)

private struct RowStyle {
    let title: Font
    let location: Font
    let time: Font
    let showsLocation: Bool
}

private struct WidgetLayout {
    let header: Font
    let row: RowStyle
    let maxEvents: Int
    let rowSpacing: CGFloat

    static func forFamily(_ family: WidgetFamily) -> WidgetLayout {
        switch family {
        case .systemLarge:
            return WidgetLayout(
                header: .title2.bold(),
                row: RowStyle(title: .headline, location: .body, time: .footnote, showsLocation: true),
                maxEvents: 4, rowSpacing: 16)
        case .systemMedium:
            return WidgetLayout(
                header: .headline,
                row: RowStyle(title: .subheadline.weight(.semibold), location: .footnote,
                              time: .caption2, showsLocation: true),
                maxEvents: 2, rowSpacing: 10)
        default: // systemSmall
            return WidgetLayout(
                header: .subheadline.weight(.semibold),
                row: RowStyle(title: .subheadline.weight(.semibold), location: .footnote,
                              time: .caption2, showsLocation: true),
                maxEvents: 1, rowSpacing: 8)
        }
    }
}

// MARK: - Category styling (mirrors the app's blue-family rails)

private func railColor(for item: WidgetItem) -> Color {
    if item.inProgress { return .red }
    switch item.event.kind {
    case "flight":   return Color(.systemBlue)
    case "train":    return Color(.systemCyan)
    case "hotel":    return Color(.systemIndigo)
    case "activity": return Color(.systemTeal)
    case "meal":     return Color(.systemMint)
    case "wedding":  return Color(.systemPurple)
    default:         return Color(.systemBlue)
    }
}

// MARK: - Row

private struct WidgetEventRow: View {
    let item: WidgetItem
    let style: RowStyle

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Capsule()
                .fill(railColor(for: item))
                .frame(width: 4)
                .overlay { progressDot }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.event.title)
                    .font(style.title)
                    .foregroundStyle(item.inProgress ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
                    .lineLimit(1)
                if style.showsLocation {
                    Text(item.event.location)
                        .font(style.location)
                        .lineLimit(1)
                }
                Text(item.event.timeRange)
                    .font(style.time)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var progressDot: some View {
        if let progress = item.progress {
            GeometryReader { geo in
                ZStack {
                    Circle().fill(Color(.systemBackground)).frame(width: 12, height: 12)
                    Circle().fill(.red).frame(width: 8, height: 8)
                }
                .position(x: geo.size.width / 2, y: geo.size.height * progress)
            }
        }
    }
}

// MARK: - Entry view

struct TripWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TripEntry

    var body: some View {
        if entry.items.isEmpty {
            emptyState
        } else {
            let layout = WidgetLayout.forFamily(family)
            let shown = Array(entry.items.prefix(layout.maxEvents))
            VStack(alignment: .leading, spacing: layout.rowSpacing) {
                Text(WidgetDate.longDate(shown.first?.event.start ?? entry.date))
                    .font(layout.header)
                ForEach(shown) { WidgetEventRow(item: $0, style: layout.row) }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your Trip").font(.headline)
            Text("No upcoming events").font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Widget

struct TripWidget: Widget {
    let kind = "TripWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            TripWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Your Trip")
        .description("Your current and next event.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemMedium) {
    TripWidget()
} timeline: {
    TripEntry(date: .now, items: WidgetTripData.lineup(at: .now))
}
