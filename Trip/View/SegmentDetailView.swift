import SwiftUI
import SwiftData
import MapKit

// MARK: - Segment detail (matches the updated "Event Detail" Sketch design)
//
// Layout follows the spec's margin system: the content sits in a 16pt margin,
// but *text* is inset a further 16pt (so ~32pt from the edge), while rich
// content — the map and the Details table — uses only the 16pt margin and so
// runs wider than the text. The title carries the same leading rail (and
// progress dot) as the list's current item.

struct SegmentDetailView: View {
    @Bindable var segment: TripSegment
    @Environment(\.openURL) private var openURL
    @State private var titleOnScreen = true

    /// Extra horizontal inset applied to text, beyond the outer 16pt margin.
    private let textInset: CGFloat = 16

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                titleBlock
                if segment.coordinate != nil { locationSection }
                if !segment.detail.isEmpty { notesSection }
                if !detailRows.isEmpty { detailsSection }
                actions
            }
            .padding(16)
        }
        // Avoid duplicating the in-content title: the nav bar shows it only
        // once the large title has scrolled out of view.
        .navigationTitle(titleOnScreen ? "" : segment.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Title block (with rail + progress dot)

    private var titleBlock: some View {
        HStack(alignment: .top, spacing: 12) {
            Capsule()
                .fill(railStyle)
                .frame(width: 4)
                .overlay { progressDot }

            VStack(alignment: .leading, spacing: 8) {
                Text(segment.title)
                    .font(.title.bold())
                    .onScrollVisibilityChange { titleOnScreen = $0 }
                VStack(alignment: .leading, spacing: 2) {
                    Text(segment.summary).font(.body)
                    Text(segment.timeRange).font(.body).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var railStyle: AnyShapeStyle {
        if segment.isCompleted { return AnyShapeStyle(.quaternary) }
        if isInProgress { return AnyShapeStyle(.red) }
        return AnyShapeStyle(segment.kind.indicatorColor)
    }

    @ViewBuilder
    private var progressDot: some View {
        if let progress {
            GeometryReader { geo in
                ZStack {
                    Circle().fill(Color(.systemBackground)).frame(width: 12, height: 12)
                    Circle().fill(.red).frame(width: 8, height: 8)
                }
                .position(x: geo.size.width / 2, y: geo.size.height * progress)
            }
        }
    }

    // MARK: Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes").font(.headline)
            Text(segment.detail).font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, textInset)
    }

    // MARK: Location (text inset; map runs full width)

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let coordinate = segment.coordinate {
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))) {
                    Marker(segment.pinName ?? segment.title, coordinate: coordinate)
                }
                .frame(height: 168)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .allowsHitTesting(false)
            }
            Group {
                if let address = segment.pinAddress {
                    Text(address).font(.body)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, textInset)
        }
    }

    // MARK: Details table (full width, alternating fills, 16pt inset text)

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details").font(.headline)
                .padding(.horizontal, textInset)

            VStack(spacing: 0) {
                ForEach(Array(detailRows.enumerated()), id: \.element.id) { index, row in
                    detailRow(row)
                        .padding(.horizontal, textInset)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            if index.isMultiple(of: 2) {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(.quaternarySystemFill))
                            }
                        }
                }
            }
        }
    }

    @ViewBuilder
    private func detailRow(_ row: DetailRowModel) -> some View {
        switch row {
        case let .fact(label, value):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label).font(.headline)
                Spacer(minLength: 8)
                Text(value).font(.body).multilineTextAlignment(.trailing)
            }
        case let .document(attachment):
            if let url = BundlePDF.url(for: attachment.name) {
                NavigationLink {
                    PDFScreen(url: url, title: attachment.label)
                } label: {
                    documentRow(attachment.label, pending: false)
                }
                .buttonStyle(.plain)
            } else {
                documentRow(attachment.label, pending: true)
            }
        }
    }

    private func documentRow(_ label: String, pending: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Document").font(.headline)
            Spacer(minLength: 8)
            Label(pending ? "\(label) (pending)" : label, systemImage: "paperclip")
                .font(.body.weight(.medium))
                .foregroundStyle(pending ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
                .labelStyle(TrailingIconLabelStyle())
        }
    }

    // MARK: Actions

    private var actions: some View {
        VStack(spacing: 16) {
            // Primary: navigate (every event has a pin). Liquid Glass, prominent.
            if let coordinate = segment.coordinate {
                Button {
                    openInMaps(coordinate)
                } label: {
                    Text("Open in Maps").fontWeight(.medium).frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
            }

            // Secondary (optional): manage the booking when there's a link.
            if let link = segment.link, let url = URL(string: link) {
                Button {
                    openURL(url)
                } label: {
                    Text("Manage booking").fontWeight(.medium).frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }

            // Tertiary (always): completion toggle, as a quiet text action.
            Button {
                segment.isCompleted.toggle()
            } label: {
                Text(segment.isCompleted ? "Mark as Not Done" : "Mark as Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
            .padding(.top, 4)
        }
        .controlSize(.large)
        .padding(.horizontal, textInset)
        .padding(.top, 16)
    }

    // MARK: Now / progress for this event

    private var now: Date { Date() }

    private var isInProgress: Bool {
        guard let start = DateText.dateTime(day: segment.day?.date ?? "", time: segment.time) else { return false }
        let end = segment.endTime.flatMap { DateText.dateTime(day: segment.day?.date ?? "", time: $0) }
            ?? start.addingTimeInterval(3600)
        return start <= now && now < end
    }

    private var progress: Double? {
        guard isInProgress,
              let start = DateText.dateTime(day: segment.day?.date ?? "", time: segment.time),
              let endText = segment.endTime,
              let end = DateText.dateTime(day: segment.day?.date ?? "", time: endText),
              end > start else { return nil }
        return min(max(now.timeIntervalSince(start) / end.timeIntervalSince(start), 0), 1)
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

/// Puts the icon after the title (the link/attachment style in the design).
private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon
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
