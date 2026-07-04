import SwiftUI
import SwiftData
import UIKit

// MARK: - Edit trip
//
// Replaces the whole itinerary from a pasted / clipboard JSON payload, validated
// before anything changes, or resets to the bundled trip. Reached from the Edit
// action at the bottom of the itinerary list.

struct EditTripView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var validation: Validation = .empty

    /// Result of validating the current editor text against the trip schema.
    private enum Validation {
        case empty
        case valid(days: Int, segments: Int)
        case invalid(String)
    }

    private var isValid: Bool {
        if case .valid = validation { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Paste a trip JSON, or pull it from your clipboard. It's checked before anything changes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    copyToClipboard()
                } label: {
                    Label("Copy to Clipboard", systemImage: "square.on.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)

                Button {
                    pasteFromClipboard()
                } label: {
                    Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)

                TextEditor(text: $text)
                    .font(.system(.footnote, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.quaternarySystemFill)))
                    .onChange(of: text) { validate() }

                validationLabel
                    .frame(maxWidth: .infinity, alignment: .leading)

                actions
            }
            .controlSize(.large)
            .padding(16)
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Label("Close", systemImage: "xmark") }
                }
            }
        }
    }

    // MARK: Actions

    private var actions: some View {
        VStack(spacing: 16) {
            // Primary: apply the validated payload.
            Button {
                apply()
            } label: {
                Text("Update Itinerary").fontWeight(.semibold).frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .disabled(!isValid)

            // Reset back to the bundled trip, as a quiet text action.
            Button(role: .destructive) {
                reset()
            } label: {
                Text("Reset to Original").fontWeight(.semibold).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
            .padding(12)
        }
    }

    @ViewBuilder
    private var validationLabel: some View {
        switch validation {
        case .empty:
            Text(" ").font(.footnote)   // reserve the line so layout doesn't jump
        case let .valid(days, segments):
            Label("Looks good — \(days) days, \(segments) events", systemImage: "checkmark.circle.fill")
                .font(.footnote).foregroundStyle(.green)
        case let .invalid(message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote).foregroundStyle(.orange)
        }
    }

    // MARK: Behavior

    private func copyToClipboard() {
        guard let json = Seeding.exportJSON(from: context) else { return }
        UIPasteboard.general.string = json
        text = json   // load the current trip into the editor too, ready to tweak
    }

    private func pasteFromClipboard() {
        guard let pasted = UIPasteboard.general.string, !pasted.isEmpty else {
            validation = .invalid("Your clipboard is empty.")
            return
        }
        text = pasted   // triggers validate() via onChange
    }

    private func validate() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { validation = .empty; return }
        guard let data = trimmed.data(using: .utf8) else {
            validation = .invalid("That isn’t valid text.")
            return
        }
        do {
            let summary = try Seeding.summary(forValidating: data)
            validation = .valid(days: summary.days, segments: summary.segments)
        } catch {
            validation = .invalid(Seeding.describe(error))
        }
    }

    private func apply() {
        guard isValid, let data = text.data(using: .utf8) else { return }
        do {
            try Seeding.replaceAll(in: context, withJSON: data)
            WidgetSnapshot.publish(from: context)
            dismiss()
        } catch {
            validation = .invalid(Seeding.describe(error))
        }
    }

    private func reset() {
        Seeding.resetToBundled(in: context)
        WidgetSnapshot.publish(from: context)
        dismiss()
    }
}

#Preview {
    EditTripView()
        .modelContainer(PreviewData.container)
}
