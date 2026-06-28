import SwiftUI
import SwiftData
import Combine

// MARK: - The trip — one scrollable list, read top to bottom
//
// A plain list of day headers and itinerary items, matching the design. The
// "current" item (by device clock) is highlighted; completed items dim. A
// bottom toolbar carries a filter menu (show/hide completed) and search.

struct TripListView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \TripDay.order) private var days: [TripDay]

    @State private var search = ""
    @State private var hideCompleted = false
    @State private var now = Date()

    var body: some View {
        NavigationStack {
            List {
                ForEach(days) { day in
                    let segments = visibleSegments(in: day)
                    if !segments.isEmpty {
                        DayHeaderView(title: DateText.longDate(day.date), summary: day.label)
                            .listRowSeparator(.hidden)
                            .listRowInsets(.init(top: 24, leading: 16, bottom: 8, trailing: 16))

                        ForEach(segments) { segment in
                            NavigationLink(value: segment) {
                                SegmentRow(segment: segment, isCurrent: segment.id == currentSegmentID)
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(.init(top: 12, leading: 16, bottom: 12, trailing: 16))
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                completeButton(for: segment)
                            }
                        }
                    }
                }

                if isEmpty {
                    ContentUnavailableView.search(text: search)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Your Trip")
            .navigationDestination(for: TripSegment.self) { SegmentDetailView(segment: $0) }
            .searchable(text: $search, prompt: "Search")
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Menu {
                        Toggle(isOn: $hideCompleted) {
                            Label("Hide Completed", systemImage: "checkmark.circle")
                        }
                    } label: {
                        Label("Filter", systemImage: hideCompleted
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease")
                    }
                }
                ToolbarSpacer(.flexible, placement: .bottomBar)
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
            }
            .task { Seeding.seedIfNeeded(context) }
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now = $0 }
        }
    }

    @ViewBuilder
    private func completeButton(for segment: TripSegment) -> some View {
        Button {
            segment.isCompleted.toggle()
        } label: {
            Label(segment.isCompleted ? "Undo" : "Done",
                  systemImage: segment.isCompleted ? "arrow.uturn.backward" : "checkmark")
        }
        .tint(.green)
    }

    // MARK: - Now / current

    /// The in-progress item: the last segment (chronologically) whose start time
    /// has passed. Falls back to the first segment before the trip begins.
    private var currentSegmentID: String? {
        let timeline = days
            .flatMap(\.orderedSegments)
            .compactMap { segment -> (id: String, start: Date)? in
                DateText.dateTime(day: segment.day?.date ?? "", time: segment.time)
                    .map { (segment.id, $0) }
            }
        guard !timeline.isEmpty else { return nil }
        return (timeline.last { $0.start <= now } ?? timeline.first)?.id
    }

    // MARK: - Filtering

    private var query: String {
        search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func visibleSegments(in day: TripDay) -> [TripSegment] {
        day.orderedSegments.filter { segment in
            if hideCompleted && segment.isCompleted { return false }
            if !query.isEmpty && !segment.matchText.contains(query) { return false }
            return true
        }
    }

    private var isEmpty: Bool {
        days.allSatisfy { visibleSegments(in: $0).isEmpty }
    }
}

#Preview {
    TripListView()
        .modelContainer(PreviewData.container)
}
