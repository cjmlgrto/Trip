import SwiftUI
import PDFKit

// MARK: - PDF screen
//
// Renders a bundled ticket/confirmation with PDFKit — zoomable and shareable,
// 100% offline. Pushed onto the navigation stack.

struct PDFScreen: View {
    let url: URL
    let title: String

    var body: some View {
        PDFKitView(url: url)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ShareLink(item: url)
            }
    }
}

private struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {}
}
