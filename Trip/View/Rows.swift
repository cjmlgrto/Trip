import SwiftUI

// MARK: - Rows
//
// Plain list rows in the Notes/Reminders idiom: a type glyph, a title, and a
// secondary time · summary line. Completed entries dim and strike through.

struct SegmentRow: View {
    let segment: TripSegment

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(segment.title)
                    .font(.body)
                    .strikethrough(segment.isCompleted, color: .secondary)
                Text("\(segment.displayTime) · \(segment.summary)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: segment.isCompleted ? "checkmark.circle.fill" : segment.kind.symbol)
                .foregroundStyle(segment.isCompleted ? AnyShapeStyle(.green) : AnyShapeStyle(.tint))
        }
        .opacity(segment.isCompleted ? 0.5 : 1)
    }
}
