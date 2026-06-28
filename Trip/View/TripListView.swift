import SwiftUI
import SwiftData

// MARK: - The trip — one scrollable list, read top to bottom
//
// Days are sections; tapping a row opens its detail. Search and a single
// "Hide Completed" toggle are the only controls. Completion is a leading swipe,
// so you can follow along the trip as it happens.

struct TripListView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \TripDay.order) private var days: [TripDay]

    @State private var search = ""
    @State private var hideCompleted = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(days) { day in
                    let segments = visibleSegments(in: day)
                    if !segments.isEmpty {
                        Section(day.header) {
                            ForEach(segments) { segment in
                                NavigationLink(value: segment) {
                                    SegmentRow(segment: segment)
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    completeButton(for: segment)
                                }
                            }
                        }
                    }
                }

                if isEmpty {
                    ContentUnavailableView.search(text: search)
                }
            }
            .navigationTitle("Your Trip")
            .navigationDestination(for: TripSegment.self) { SegmentDetailView(segment: $0) }
            .searchable(text: $search, prompt: "Search the trip")
            .toolbar {
                Menu {
                    Toggle(isOn: $hideCompleted) {
                        Label("Hide Completed", systemImage: "checkmark.circle")
                    }
                } label: {
                    Label("Options", systemImage: "ellipsis.circle")
                }
            }
            .task { Seeding.seedIfNeeded(context) }
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
