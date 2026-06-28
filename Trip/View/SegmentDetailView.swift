import SwiftUI
import MapKit

// MARK: - Segment detail
//
// A native Form: the description, an offline map of the location, key facts as
// LabeledContent, the bundled ticket (or a "Confirmation pending" placeholder),
// a Manage-booking link, and a Completed toggle.

struct SegmentDetailView: View {
    @Bindable var segment: TripSegment

    var body: some View {
        Form {
            Section {
                Text(segment.detail)
            }

            if let coordinate = segment.coordinate {
                Section("Location") {
                    Map(initialPosition: .region(region(coordinate))) {
                        Marker(segment.pinName ?? segment.title, coordinate: coordinate)
                    }
                    .frame(height: 170)
                    .listRowInsets(EdgeInsets())
                    .allowsHitTesting(false)

                    if let address = segment.pinAddress {
                        Text(address).foregroundStyle(.secondary)
                    }
                    Button("Open in Maps", systemImage: "map") {
                        openInMaps(coordinate)
                    }
                }
            }

            Section("Details") {
                LabeledContent("Time", value: segment.displayTime)
                if let ref = segment.ref, !ref.isEmpty {
                    LabeledContent("Reference", value: ref)
                }
                if let seat = segment.seat, !seat.isEmpty {
                    LabeledContent("Seat", value: seat)
                }
                ticketRow
                if let link = segment.link, let url = URL(string: link) {
                    Link(destination: url) {
                        Label("Manage booking", systemImage: "safari")
                    }
                }
            }

            Section {
                Toggle("Completed", isOn: $segment.isCompleted)
            }
        }
        .navigationTitle(segment.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var ticketRow: some View {
        if let url = BundlePDF.url(for: segment.file) {
            NavigationLink {
                PDFScreen(url: url, title: segment.title)
            } label: {
                Label("View ticket", systemImage: "doc.text")
            }
        } else if segment.file != nil {
            // Owner will add the PDF later — degrade gracefully, never crash.
            Label("Confirmation pending", systemImage: "doc.text")
                .foregroundStyle(.secondary)
        }
    }

    private func region(_ coordinate: CLLocationCoordinate2D) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    }

    private func openInMaps(_ coordinate: CLLocationCoordinate2D) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = segment.pinName ?? segment.title
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }
}

// MARK: - Bundled PDF lookup

enum BundlePDF {
    static func url(for name: String?) -> URL? {
        guard let name, !name.isEmpty else { return nil }
        let base = (name as NSString).deletingPathExtension
        return Bundle.main.url(forResource: base, withExtension: "pdf")
    }
}
