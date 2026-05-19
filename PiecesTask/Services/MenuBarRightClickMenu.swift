import AppKit

/// Installs a real right-click `NSMenu` on the menu bar status item (SwiftUI `contextMenu` does not work here).
@MainActor
final class MenuBarRightClickMenuInstaller: NSObject {
    private weak var statusItem: NSStatusItem?
    private var eventMonitor: Any?
    private var installTask: Task<Void, Never>?

    func start() {
        guard installTask == nil else { return }
        installTask = Task { @MainActor in
            let deadline = Date().addingTimeInterval(3)
            while !Task.isCancelled, Date() < deadline {
                if let item = MenuBarStatusItemFinder.statusItem(at: 0) {
                    install(on: item)
                    return
                }
                try? await Task.sleep(for: .milliseconds(150))
            }
        }
    }

    func stop() {
        installTask?.cancel()
        installTask = nil
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
        statusItem = nil
    }

    private func install(on item: NSStatusItem) {
        guard statusItem == nil, let button = item.button else { return }
        statusItem = item

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown]) { [weak self] event in
            guard let self, let button = self.statusItem?.button else { return event }
            guard event.window === button.window else { return event }

            let point = button.convert(event.locationInWindow, from: nil)
            guard button.bounds.contains(point) else { return event }

            self.showMenu(relativeTo: point, in: button)
            return nil
        }
    }

    private func showMenu(relativeTo point: NSPoint, in button: NSStatusBarButton) {
        let menu = NSMenu()

        let settings = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Close App",
            action: #selector(closeApp),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        menu.popUp(
            positioning: nil,
            at: NSPoint(x: point.x, y: button.bounds.height + 4),
            in: button
        )
    }

    @objc private func openSettings() {
        SettingsWindowPresenter.shared.open()
    }

    @objc private func closeApp() {
        NSApp.terminate(nil)
    }
}
