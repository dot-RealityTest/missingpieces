import AppKit
import Carbon.HIToolbox

private let globalHotKeySignature: OSType = 0x5054_736B // "PTsk"
private let globalHotKeyCommandID: UInt32 = 1

private func globalHotKeyEventCallback(
    _ nextHandler: EventHandlerCallRef?,
    theEvent: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData, let theEvent else { return OSStatus(eventNotHandledErr) }

    var pressedID = EventHotKeyID()
    let status = GetEventParameter(
        theEvent,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &pressedID
    )
    guard status == noErr,
          pressedID.signature == globalHotKeySignature,
          pressedID.id == globalHotKeyCommandID else {
        return OSStatus(eventNotHandledErr)
    }

    let service = Unmanaged<GlobalHotKeyService>.fromOpaque(userData).takeUnretainedValue()
    Task { @MainActor in
        service.togglePopover()
    }
    return noErr
}

/// Toggles the menu bar popover with ⌃⌥P (control + option + P).
@MainActor
final class GlobalHotKeyService {
    static let shared = GlobalHotKeyService()

    static let shortcutLabel = "⌃⌥P"

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private init() {}

    func start(enabled: Bool) {
        stop()
        guard enabled else { return }
        installHandler()
        registerHotKey()
    }

    func stop() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    func togglePopover() {
        guard let button = MenuBarStatusItemFinder.statusItem()?.button else { return }
        button.performClick(nil)
    }

    private func installHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            globalHotKeyEventCallback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        if status != noErr {
            eventHandler = nil
        }
    }

    private func registerHotKey() {
        var registrationID = EventHotKeyID(signature: globalHotKeySignature, id: globalHotKeyCommandID)
        let modifiers = UInt32(controlKey | optionKey)
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_P),
            modifiers,
            registrationID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            hotKeyRef = nil
        }
    }
}
