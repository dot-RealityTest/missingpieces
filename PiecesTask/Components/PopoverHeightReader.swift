import SwiftUI

private struct TopChromeHeightKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct BottomBarHeightKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    func reportTopChromeHeight(to binding: Binding<CGFloat>) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(key: TopChromeHeightKey.self, value: proxy.size.height)
            }
        }
        .onPreferenceChange(TopChromeHeightKey.self) { binding.wrappedValue = $0 }
    }

    func reportBottomBarHeight(to binding: Binding<CGFloat>) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(key: BottomBarHeightKey.self, value: proxy.size.height)
            }
        }
        .onPreferenceChange(BottomBarHeightKey.self) { binding.wrappedValue = $0 }
    }
}
