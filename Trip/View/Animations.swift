import SwiftUI

// MARK: - Shared animation curves
//
// One easing vocabulary for the whole app so motion feels consistent. Both are
// springs (no abrupt linear stops); `smooth` has no bounce for content and
// filtering, `snappy` is a touch quicker for direct, interactive gestures.

extension Animation {
    /// Content changes: filtering, completion, the progress dot.
    static let trip: Animation = .smooth(duration: 0.35)

    /// Direct manipulation: the pinch-to-collapse gesture.
    static let tripInteractive: Animation = .snappy(duration: 0.28, extraBounce: 0.05)
}
