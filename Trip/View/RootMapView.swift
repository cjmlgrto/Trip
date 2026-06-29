import SwiftUI
import SwiftData
import MapKit

// MARK: - Root: map background + itinerary half-sheet
//
// The whole app sits over a Map that carries the app's top toolbar (filter +
// search). The itinerary is a persistent sheet at half height that expands when
// pulled up. Tapping an item opens its detail as a sheet over the list (closed
// with an X), and the map behind focuses that item's pin when it has a
// coordinate. The selected segment is the single source of truth for both the
// detail sheet and the map focus.

struct RootMapView: View {
    @Query private var segments: [TripSegment]

    @State private var selected: TripSegment?
    @State private var detent: PresentationDetent = .medium
    @State private var camera: MapCameraPosition = .automatic

    // Filtering lives at the app level (the map's toolbar), shared into the list.
    @State private var hideCompleted = true
    @State private var todayOnly = false
    @State private var hiddenKinds: Set<SegmentKind> = []

    var body: some View {
        NavigationStack {
            Map(position: $camera, selection: $selected) {
                ForEach(pins) { segment in
                    if let coordinate = segment.coordinate {
                        Marker(segment.title, systemImage: segment.kind.symbol, coordinate: coordinate)
                            .tint(segment.kind.indicatorColor)
                            .tag(segment)
                    }
                }
            }
            .ignoresSafeArea()
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { filterMenu }
            }
            .sheet(isPresented: .constant(true)) {
                TripListView(hideCompleted: hideCompleted, todayOnly: todayOnly,
                             hiddenKinds: hiddenKinds, selection: $selected)
                    .presentationDetents([.medium, .large], selection: $detent)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                    .presentationDragIndicator(.visible)
                    .interactiveDismissDisabled()
                    .sheet(item: $selected) { segment in
                        detailSheet(segment)
                    }
            }
        }
        .onChange(of: selected) {
            // Collapse the list sheet to half height while a detail is open, and
            // restore it to half when the detail closes.
            detent = .medium
            focusMap()
        }
        .onAppear { camera = defaultCamera() }
        .onChange(of: segments.count) {
            if selected == nil { withAnimation(.smooth) { camera = defaultCamera() } }
        }
    }

    // MARK: Detail sheet (over the list, closed with an X)

    private func detailSheet(_ segment: TripSegment) -> some View {
        NavigationStack {
            SegmentDetailView(segment: segment)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            selected = nil
                        } label: {
                            Label("Close", systemImage: "xmark")
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .presentationDragIndicator(.visible)
    }

    // MARK: Filter toolbar

    private var filterMenu: some View {
        Menu {
            Toggle(isOn: $hideCompleted) {
                Label("Hide Completed", systemImage: "checkmark.circle")
            }
            Toggle(isOn: $todayOnly) {
                Label("Today Only", systemImage: "calendar")
            }
            Section("Categories") {
                ForEach(SegmentKind.spectrumOrder, id: \.self) { kind in
                    Toggle(isOn: visibility(of: kind)) {
                        Label { Text(kind.label) } icon: { Image(uiImage: kind.swatchImage) }
                    }
                }
            }
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease")
        }
    }

    private func visibility(of kind: SegmentKind) -> Binding<Bool> {
        Binding(
            get: { !hiddenKinds.contains(kind) },
            set: { shown in
                if shown { hiddenKinds.remove(kind) } else { hiddenKinds.insert(kind) }
            }
        )
    }

    // MARK: Map focus / framing

    /// The selected detail, if it has a coordinate to focus on.
    private var focused: TripSegment? {
        guard let selected, selected.coordinate != nil else { return nil }
        return selected
    }

    /// Only the focused pin while viewing a located detail; otherwise all pins.
    private var pins: [TripSegment] {
        if let focused { return [focused] }
        return segments.filter { $0.coordinate != nil }
    }

    private func focusMap() {
        withAnimation(.smooth) {
            if let focused, let coordinate = focused.coordinate {
                camera = .region(region(fitting: [coordinate]))
            } else {
                camera = defaultCamera()
            }
        }
    }

    /// Default framing: the current day's pins, else all pins.
    private func defaultCamera() -> MapCameraPosition {
        if let region = currentDayRegion() { return .region(region) }
        return .automatic
    }

    private func currentDayRegion() -> MKCoordinateRegion? {
        let today = DateText.dayKey(Date())
        let coordinates = segments
            .filter { $0.day?.date == today }
            .compactMap(\.coordinate)
        guard !coordinates.isEmpty else { return nil }
        return region(fitting: coordinates)
    }

    /// A region enclosing the given coordinates, padded and nudged south so the
    /// pins sit in the map area above the half-sheet.
    private func region(fitting coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        let lats = coordinates.map(\.latitude)
        let lngs = coordinates.map(\.longitude)
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLng = lngs.min()!, maxLng = lngs.max()!
        let spanLat = max((maxLat - minLat) * 1.6, 0.02)
        let spanLng = max((maxLng - minLng) * 1.6, 0.02)
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2 - spanLat * 0.2,
            longitude: (minLng + maxLng) / 2
        )
        return MKCoordinateRegion(center: center,
                                  span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLng))
    }
}

#Preview {
    RootMapView()
        .modelContainer(PreviewData.container)
}
