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

// MARK: - Views

struct EventRow: View {
    let item: WidgetItem
    var showsTime = true

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Capsule()
                .fill(railColor(for: item))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.label.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(item.inProgress ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                Text(item.event.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(item.event.location)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if showsTime {
                    Text(item.event.timeRange)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct TripWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TripEntry

    var body: some View {
        if entry.items.isEmpty {
            emptyState
        } else if family == .systemSmall {
            EventRow(item: entry.items[0])
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(entry.items) { EventRow(item: $0) }
                Spacer(minLength: 0)
            }
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
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemMedium) {
    TripWidget()
} timeline: {
    TripEntry(date: .now, items: WidgetTripData.lineup(at: .now))
}
