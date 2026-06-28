import SwiftUI
import SwiftData
import MapKit

// MARK: - Segment detail (matches the "Event Detail" Sketch design)
//
// A scrolling layout: the title is the collapsing large nav title; the content
// opens with the location + time, then Notes, Location (address + offline map),
// a Details table with alternating row fills (facts + tappable documents), and
// a stack of Primary / Secondary / Tertiary actions.

struct SegmentDetailView: View {
    @Bindable var segment: TripSegment

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header
                if !segment.detail.isEmpty {
                    DetailSection("Notes") { Text(segment.detail).font(.body) }
                }
                if let coordinate = segment.coordinate {
                    locationSection(coordinate)
                }
                if !detailRows.isEmpty {
                    DetailSection("Details") { detailsTable }
                }
                actions
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle(segment.title)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(segment.summary).font(.body)
            Text(segment.timeRange).font(.body).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Location

    private func locationSection(_ coordinate: CLLocationCoordinate2D) -> some View {
        DetailSection("Location") {
            VStack(alignment: .leading, spacing: 8) {
                if let address = segment.pinAddress {
                    Text(address).font(.body)
                }
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))) {
                    Marker(segment.pinName ?? segment.title, coordinate: coordinate)
                }
                .frame(height: 168)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: Details table (alternating row fills)

    private var detailsTable: some View {
        VStack(spacing: 0) {
            ForEach(Array(detailRows.enumerated()), id: \.element.id) { index, row in
                detailRow(row)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(index.isMultiple(of: 2) ? Color(.quaternarySystemFill) : .clear)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func detailRow(_ row: DetailRowModel) -> some View {
        switch row {
        case let .fact(label, value):
            HStack {
                Text(label)
                Spacer(minLength: 8)
                Text(value).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
            }
        case let .document(attachment):
            if let url = BundlePDF.url(for: attachment.name) {
                NavigationLink {
                    PDFScreen(url: url, title: attachment.label)
                } label: {
                    documentLabel(attachment.label, pending: false)
                }
                .buttonStyle(.plain)
            } else {
                documentLabel(attachment.label, pending: true)
            }
        }
    }

    private func documentLabel(_ label: String, pending: Bool) -> some View {
        HStack {
            Text("Document")
            Spacer(minLength: 8)
            Label(pending ? "\(label) (pending)" : label, systemImage: "paperclip")
                .labelStyle(.titleAndIcon)
                .foregroundStyle(pending ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
        }
    }

    // MARK: Actions

    private var actions: some View {
        VStack(spacing: 16) {
            if let coordinate = segment.coordinate {
                Button {
                    openInMaps(coordinate)
                } label: {
                    Text("Open in Maps").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            Button {
                segment.isCompleted.toggle()
            } label: {
                Text(segment.isCompleted ? "Mark as Not Done" : "Mark as Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if let link = segment.link, let url = URL(string: link) {
                Link("Manage booking", destination: url)
                    .font(.body)
            }
        }
        .controlSize(.large)
        .padding(.top, 16)
    }

    // MARK: Rows model

    private enum DetailRowModel: Identifiable {
        case fact(label: String, value: String)
        case document(Attachment)

        var id: String {
            switch self {
            case let .fact(label, _): "fact-\(label)"
            case let .document(attachment): "doc-\(attachment.name)"
            }
        }
    }

    private var detailRows: [DetailRowModel] {
        var rows: [DetailRowModel] = []
        if let info = segment.info, !info.isEmpty { rows.append(.fact(label: "Good to know", value: info)) }
        if let ref = segment.ref, !ref.isEmpty { rows.append(.fact(label: "Reference", value: ref)) }
        if let seat = segment.seat, !seat.isEmpty { rows.append(.fact(label: "Seat", value: seat)) }
        rows.append(contentsOf: segment.attachments.map(DetailRowModel.document))
        return rows
    }

    private func openInMaps(_ coordinate: CLLocationCoordinate2D) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = segment.pinName ?? segment.title
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }
}

// MARK: - Section (bold header + content), matching the design

private struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content.frame(maxWidth: .infinity, alignment: .leading)
        }
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

#Preview {
    NavigationStack {
        DetailPreview()
    }
    .modelContainer(PreviewData.container)
}

private struct DetailPreview: View {
    @Query(sort: \TripSegment.order) private var segments: [TripSegment]
    var body: some View {
        if let segment = segments.first(where: { !$0.attachments.isEmpty }) ?? segments.first {
            SegmentDetailView(segment: segment)
        }
    }
}
