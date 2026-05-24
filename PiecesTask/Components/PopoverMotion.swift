import SwiftUI

/// Subtle, purposeful motion for the menu bar popover (respects Reduce Motion).
enum PopoverMotion {
    /// Short acknowledgment — copy flash, mark done.
    static let feedback = Animation.snappy(duration: 0.26, extraBounce: 0.05)
    /// Layout change — row expand/collapse, banner, list phase.
    static let expand = Animation.smooth(duration: 0.28, extraBounce: 0)
    static let gentle = Animation.smooth(duration: 0.30, extraBounce: 0)
    static let quick = Animation.smooth(duration: 0.18, extraBounce: 0)
    static let spring = Animation.snappy(duration: 0.34, extraBounce: 0.08)

    static func perform(
        reduceMotion: Bool,
        _ animation: Animation = expand,
        _ changes: () -> Void
    ) {
        if reduceMotion {
            changes()
        } else {
            withAnimation(animation, changes)
        }
    }

    static func animation(reduceMotion: Bool, _ preferred: Animation = expand) -> Animation? {
        reduceMotion ? nil : preferred
    }

    /// Insert/remove transitions that stay calm when Reduce Motion is on.
    static func revealTransition(reduceMotion: Bool) -> AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity
        )
    }
}
