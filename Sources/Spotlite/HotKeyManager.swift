import AppKit
import Carbon

@MainActor
final class HotKeyManager {
    private var nextID: UInt32 = 1
    private var hotKeys: [UInt32: () -> Void] = [:]
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var eventHandlerRef: EventHandlerRef?

    init() {
        installEventHandler()
    }

    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) -> UInt32? {
        let id = nextID
        nextID += 1
        hotKeys[id] = action

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: fourCharCode("SPTL"), id: id)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr else {
            NSLog("Spotlite failed to register hotkey id \(id): \(status)")
            hotKeys[id] = nil
            return nil
        }

        if let hotKeyRef {
            hotKeyRefs[id] = hotKeyRef
        }

        return id
    }

    func unregister(id: UInt32) {
        if let hotKeyRef = hotKeyRefs.removeValue(forKey: id) {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeys[id] = nil
    }

    private func handleHotKey(id: UInt32) {
        hotKeys[id]?()
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else {
                return OSStatus(eventNotHandledErr)
            }

            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            guard status == noErr else {
                return status
            }

            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            Task { @MainActor in
                manager.handleHotKey(id: hotKeyID.id)
            }

            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
    }
}

private func fourCharCode(_ string: String) -> OSType {
    precondition(string.utf8.count == 4)

    return string.utf8.reduce(0) { result, character in
        (result << 8) + OSType(character)
    }
}
