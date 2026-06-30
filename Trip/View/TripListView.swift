import SwiftUI
import SwiftData
import Combine

// MARK: - The trip — itinerary list (content of the root map sheet)
//
// A plain list of day headers and itinerary items. Navigation and the filter /
// search controls live in RootMapView (the app's top toolbar over the map);
// this view just receives the filter state and renders. The "current" item (by
// device clock) is highlighted; completed items dim.

struct TripListView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \TripDay.order) private var days: [TripDay]

    // Filter state, owned by RootMapView.
    let hideCompleted: Bool
    let hideCommutes: Bool
    @Binding var selectedDay: String?
    let hiddenKinds: Set<SegmentKind>
    @Binding var selection: TripSegment?

    @State private var detailLevel: DetailLevel = .full
    @State private var pinchBaseLevel: DetailLevel?
    @State private var now = Date()
    @State private var showingEdit = false

    var body: some View {
        VStack(spacing: 0) {
            WeekCalendarBar(days: days, selectedDay: $selectedDay)
            itinerary
        }
    }

    private var itinerary: some View {
        // Computed once per render — not once per row.
        let currentID = currentSegmentID
        let segments = visibleSegments

        return List {
            ForEach(segments) { segment in
                if detailLevel == .full, !hideCommutes, let commute = segment.commuteSummary {
                    CommuteCard(mode: segment.commuteMode ?? "walk", summary: commute)
                        .listRowSeparator(.hidden)
                        .listRowInsets(.init(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
                Button {
                    selection = segment
                } label: {
                    SegmentRow(segment: segment, isCurrent: segment.id == currentID,
                               now: now, detail: detailLevel)
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowInsets(.init(top: 12, leading: 16, bottom: 12, trailing: 16))
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    completeButton(for: segment)
                }
            }

            if segments.isEmpty {
                ContentUnavailableView("Nothing planned", systemImage: "calendar",
                                       description: Text("No events for this day, or the filter hides them all."))
            }

            // Edit the trip — same quiet text-action treatment as the detail
            // screen's "Mark as Done" button.
            Button {
                showingEdit = true
            } label: {
                Text("Edit Trip").fontWeight(.semibold).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
            .controlSize(.large)
            .padding(12)
            .listRowSeparator(.hidden)
            .listRowInsets(.init(top: 16, leading: 16, bottom: 24, trailing: 16))
        }
        .listStyle(.plain)
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    // Track the level live as the pinch progresses: zooming out
                    // (magnification < 1) drops tertiary then secondary; zooming
                    // back in restores them. ~0.3 of pinch per detail level.
                    let base = pinchBaseLevel ?? detailLevel
                    if pinchBaseLevel == nil { pinchBaseLevel = base }
                    let steps = Int(((value.magnification - 1) / 0.3).rounded())
                    let target = min(max(base.rawValue + steps,
                                         DetailLevel.minimal.rawValue),
                                     DetailLevel.full.rawValue)
                    if let level = DetailLevel(rawValue: target), level != detailLevel {
                        withAnimation(.tripInteractive) { detailLevel = level }
                    }
                }
                .onEnded { _ in pinchBaseLevel = nil }
        )
        .animation(.trip, value: hideCompleted)
        .animation(.trip, value: hideCommutes)
        .animation(.trip, value: selectedDay)
        .animation(.trip, value: hiddenKinds)
        .navigationBarHidden(true)
        .sheet(isPresented: $showingEdit) {
            EditTripView()
        }
        .task {
            Seeding.seedIfNeeded(context)
            WidgetSnapshot.publish(from: context)
        }
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

    /// The TripDay matching the calendar selection.
    private var selectedDayModel: TripDay? {
        days.first { $0.date == selectedDay }
    }

    /// The selected day's segments, in order, after the active filter.
    private var visibleSegments: [TripSegment] {
        (selectedDayModel?.orderedSegments ?? []).filter { matches($0) }
    }

    private func matches(_ segment: TripSegment) -> Bool {
        if hideCompleted && segment.isCompleted { return false }
        if hiddenKinds.contains(segment.kind) { return false }
        return true
    }
}

#Preview {
    @Previewable @State var day: String? = "2026-06-30"
    return TripListView(hideCompleted: true, hideCommutes: false, selectedDay: $day,
                        hiddenKinds: [], selection: .constant(nil))
        .modelContainer(PreviewData.container)
}
