import Carbon.HIToolbox

final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let onHotkey: () -> Void

    init(onHotkey: @escaping () -> Void) throws {
        self.onHotkey = onHotkey

        var hotKeyID = EventHotKeyID(signature: OSType(UInt32(truncatingIfNeeded: 0x72777478)), id: 1) // "rwtx"
        let modifiers = UInt32(cmdKey)
        let keyCode = UInt32(kVK_Escape)

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
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
                guard status == noErr else { return status }
                guard hotKeyID.id == 1 else { return noErr }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    manager.onHotkey()
                }
                return noErr
            },
            1,
            &eventType,
            userData,
            &eventHandlerRef
        )
        guard installStatus == noErr else {
            throw NSError(domain: "HotkeyManager", code: Int(installStatus))
        }

        let registerStatus = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard registerStatus == noErr else {
            throw NSError(domain: "HotkeyManager", code: Int(registerStatus))
        }
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }
}
