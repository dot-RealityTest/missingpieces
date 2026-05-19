import SwiftUI

/// Subtle, purposeful motion for the menu bar popover (respects Reduce Motion).
enum PopoverMotion {
    static let spring = Animation.snappy(duration: 0.38, extraBounce: 0.14)
    static let gentle = Animation.smooth(duration: 0.32, extraBounce: 0)
    static let quick = Animation.smooth(duration: 0.22, extraBounce: 0)

    static func perform(
        reduceMotion: Bool,
        _ animation: Animation = spring,
        _ changes: () -> Void
    ) {
        if reduceMotion {
            changes()
        } else {
            withAnimation(animation, changes)
        }
    }

    static func animation(reduceMotion: Bool, _ preferred: Animation = spring) -> Animation? {
        reduceMotion ? nil : preferred
    }
}
