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
    @State private var todayOnly = false
    @State private var hiddenKinds: Set<SegmentKind> = []
    @State private var detailLevel: DetailLevel = .full
    @State private var now = Date()

    var body: some View {
        NavigationStack {
            itinerary
        }
    }

    private var itinerary: some View {
        // Computed once per render — not once per row.
        let currentID = currentSegmentID
        let sections = visibleSections

        return List {
            ForEach(sections) { section in
                DayHeaderView(title: DateText.longDate(section.day.date), summary: section.day.label)
                    .listRowSeparator(.hidden)
                    .listRowInsets(.init(top: 24, leading: 16, bottom: 8, trailing: 16))

                ForEach(section.segments) { segment in
                    NavigationLink(value: segment) {
                        SegmentRow(segment: segment, isCurrent: segment.id == currentID,
                                   now: now, detail: detailLevel)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(.init(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        completeButton(for: segment)
                    }
                }
            }

            if sections.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
        .listStyle(.plain)
        .gesture(
            MagnifyGesture(minimumScaleDelta: 0.1)
                .onEnded { value in
                    withAnimation(.snappy) {
                        if value.magnification < 1 {
                            detailLevel = detailLevel.collapsed
                        } else if value.magnification > 1 {
                            detailLevel = detailLevel.expanded
                        }
                    }
                }
        )
        .navigationTitle("Your Trip")
        .navigationDestination(for: TripSegment.self) { SegmentDetailView(segment: $0) }
        .searchable(text: $search, prompt: "Search")
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Menu {
                    Toggle(isOn: $hideCompleted) {
                        Label("Hide Completed", systemImage: "checkmark.circle")
                    }
                    Toggle(isOn: $todayOnly) {
                        Label("Today Only", systemImage: "calendar")
                    }
                    Section("Categories") {
                        ForEach(SegmentKind.allCases, id: \.self) { kind in
                            Toggle(isOn: visibility(of: kind)) {
                                Label(kind.label, systemImage: kind.symbol)
                            }
                        }
                    }
                } label: {
                    Label("Filter", systemImage: isFiltering
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

    /// Days with their filtered segments, empty days dropped — computed once.
    private var visibleSections: [DaySection] {
        let query = self.query
        let today = DateText.dayKey(now)
        return days.compactMap { day in
            if todayOnly && day.date != today { return nil }
            let segments = day.orderedSegments.filter { matches($0, query: query) }
            return segments.isEmpty ? nil : DaySection(day: day, segments: segments)
        }
    }

    private var isFiltering: Bool { hideCompleted || todayOnly || !hiddenKinds.isEmpty }

    /// Binding for a category's visibility toggle (on == shown).
    private func visibility(of kind: SegmentKind) -> Binding<Bool> {
        Binding(
            get: { !hiddenKinds.contains(kind) },
            set: { shown in
                if shown { hiddenKinds.remove(kind) } else { hiddenKinds.insert(kind) }
            }
        )
    }

    private func matches(_ segment: TripSegment, query: String) -> Bool {
        if hideCompleted && segment.isCompleted { return false }
        if hiddenKinds.contains(segment.kind) { return false }
        if !query.isEmpty && !segment.matchText.contains(query) { return false }
        return true
    }

    private var query: String {
        search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private struct DaySection: Identifiable {
        let day: TripDay
        let segments: [TripSegment]
        var id: String { day.date }
    }
}

#Preview {
    TripListView()
        .modelContainer(PreviewData.container)
}
