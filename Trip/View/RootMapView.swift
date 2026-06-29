import SwiftUI
import SwiftData
import MapKit

// MARK: - Root: map background + itinerary half-sheet
//
// The whole app sits over a Map. The itinerary is a persistent sheet that
// starts at half height and expands when pulled up. Tapping an item pushes its
// detail inside the sheet; the map behind reacts by hiding the other pins and
// focusing the selected one (when it has a coordinate). The navigation path is
// the single source of truth for both the pushed detail and the map's focus.

struct RootMapView: View {
    @Query private var segments: [TripSegment]

    @State private var path: [TripSegment] = []
    @State private var detent: PresentationDetent = .medium
    @State private var camera: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $camera) {
            ForEach(pins) { segment in
                if let coordinate = segment.coordinate {
                    Marker(segment.title, coordinate: coordinate)
                        .tint(segment.kind.indicatorColor)
                }
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            NavigationStack(path: $path) {
                TripListView()
                    .navigationDestination(for: TripSegment.self) { segment in
                        SegmentDetailView(segment: segment)
                    }
            }
            .presentationDetents([.medium, .large], selection: $detent)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
        }
        .onChange(of: path) { focusMap() }
    }

    /// The detail currently shown, if it has a coordinate to focus on.
    private var focused: TripSegment? {
        guard let last = path.last, last.coordinate != nil else { return nil }
        return last
    }

    /// Only the focused pin while viewing a located detail; otherwise all pins.
    private var pins: [TripSegment] {
        if let focused { return [focused] }
        return segments.filter { $0.coordinate != nil }
    }

    private func focusMap() {
        withAnimation(.smooth) {
            if let focused, let coordinate = focused.coordinate {
                // Shift the region south so the pin sits in the map area visible
                // above the half-sheet rather than under its top edge.
                let span = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                let center = CLLocationCoordinate2D(
                    latitude: coordinate.latitude - span.latitudeDelta * 0.25,
                    longitude: coordinate.longitude
                )
                camera = .region(MKCoordinateRegion(center: center, span: span))
                detent = .medium   // ease the sheet down so the focused pin shows
            } else {
                camera = .automatic
            }
        }
    }
}

#Preview {
    RootMapView()
        .modelContainer(PreviewData.container)
}
