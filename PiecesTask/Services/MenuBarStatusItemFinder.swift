import AppKit

/// Locates the `NSStatusItem` created by SwiftUI `MenuBarExtra`.
@MainActor
enum MenuBarStatusItemFinder {
    static func statusItem(at index: Int = 0) -> NSStatusItem? {
        let items = statusItems
        guard items.indices.contains(index) else { return nil }
        return items[index]
    }

    static var statusItems: [NSStatusItem] {
        NSApp.windows
            .filter { $0.className.contains("NSStatusBarWindow") }
            .compactMap { window -> NSStatusItem? in
                guard let item = window.fetchMenuBarStatusItem() else { return nil }
                let mainClass = if #available(macOS 26.0, *) {
                    "NSSceneStatusItem"
                } else {
                    "NSStatusItem"
                }
                return item.className == mainClass ? item : nil
            }
    }
}

private extension NSWindow {
    func fetchMenuBarStatusItem() -> NSStatusItem? {
        value(forKey: "statusItem") as? NSStatusItem
            ?? Mirror(reflecting: self).descendant("statusItem") as? NSStatusItem
    }
}
