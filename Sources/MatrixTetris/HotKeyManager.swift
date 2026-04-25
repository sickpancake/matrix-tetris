import Carbon
import Foundation
import MatrixTetrisCore

enum HotKeyError: LocalizedError {
    case couldNotInstallHandler(OSStatus)
    case couldNotRegister(String, OSStatus)
    case duplicateShortcuts

    var errorDescription: String? {
        switch self {
        case .couldNotInstallHandler(let status):
            "Could not install the global hotkey handler. OSStatus: \(status)"
        case .couldNotRegister(let target, let status):
            "Could not register the \(target). OSStatus: \(status)"
        case .duplicateShortcuts:
            "Toggle and hold shortcuts must use different keys."
        }
    }
}

final class HotKeyManager {
    private let onTogglePressed: () -> Void
    private let onHoldPressed: () -> Void
    private let onHoldReleased: () -> Void
    private var eventHandler: EventHandlerRef?
    private var toggleHotKeyRef: EventHotKeyRef?
    private var holdHotKeyRef: EventHotKeyRef?
    private var isHoldPressed = false
    private let toggleHotKeyID = EventHotKeyID(signature: fourCharCode("MTET"), id: 1)
    private let holdHotKeyID = EventHotKeyID(signature: fourCharCode("MTET"), id: 2)

    var isToggleRegistered: Bool {
        toggleHotKeyRef != nil
    }

    var isHoldRegistered: Bool {
        holdHotKeyRef != nil
    }

    init(
        onTogglePressed: @escaping () -> Void,
        onHoldPressed: @escaping () -> Void,
        onHoldReleased: @escaping () -> Void
    ) {
        self.onTogglePressed = onTogglePressed
        self.onHoldPressed = onHoldPressed
        self.onHoldReleased = onHoldReleased
    }

    deinit {
        unregister()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    func register(toggleShortcut: Shortcut, holdShortcut: Shortcut) throws {
        try installHandlerIfNeeded()
        unregister()

        guard toggleShortcut != holdShortcut else {
            throw HotKeyError.duplicateShortcuts
        }

        toggleHotKeyRef = try registerHotKey(
            shortcut: toggleShortcut,
            hotKeyID: toggleHotKeyID,
            targetName: "toggle hotkey"
        )
        holdHotKeyRef = try registerHotKey(
            shortcut: holdShortcut,
            hotKeyID: holdHotKeyID,
            targetName: "hold hotkey"
        )
    }

    func unregister() {
        if let toggleHotKeyRef {
            UnregisterEventHotKey(toggleHotKeyRef)
        }
        if let holdHotKeyRef {
            UnregisterEventHotKey(holdHotKeyRef)
        }
        toggleHotKeyRef = nil
        holdHotKeyRef = nil
        isHoldPressed = false
    }

    private func registerHotKey(
        shortcut: Shortcut,
        hotKeyID: EventHotKeyID,
        targetName: String
    ) throws -> EventHotKeyRef {
        var newHotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            carbonModifiers(for: shortcut.modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &newHotKeyRef
        )

        guard status == noErr else {
            throw HotKeyError.couldNotRegister(targetName, status)
        }
        guard let newHotKeyRef else {
            throw HotKeyError.couldNotRegister(targetName, OSStatus(eventNotHandledErr))
        }
        return newHotKeyRef
    }

    private func installHandlerIfNeeded() throws {
        guard eventHandler == nil else { return }

        var eventSpecs = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            ),
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyReleased)
            )
        ]

        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let status = eventSpecs.withUnsafeMutableBufferPointer { buffer in
            InstallEventHandler(
                GetApplicationEventTarget(),
                hotKeyEventHandler,
                buffer.count,
                buffer.baseAddress,
                userData,
                &eventHandler
            )
        }

        guard status == noErr else {
            throw HotKeyError.couldNotInstallHandler(status)
        }
    }

    fileprivate func handleHotKey(id: UInt32, eventKind: UInt32) -> OSStatus {
        if id == toggleHotKeyID.id && eventKind == UInt32(kEventHotKeyPressed) {
            DispatchQueue.main.async { [onTogglePressed] in
                onTogglePressed()
            }
            return noErr
        }

        if id == holdHotKeyID.id {
            switch eventKind {
            case UInt32(kEventHotKeyPressed):
                guard !isHoldPressed else { return noErr }
                isHoldPressed = true
                DispatchQueue.main.async { [onHoldPressed] in
                    onHoldPressed()
                }
                return noErr
            case UInt32(kEventHotKeyReleased):
                guard isHoldPressed else { return noErr }
                isHoldPressed = false
                DispatchQueue.main.async { [onHoldReleased] in
                    onHoldReleased()
                }
                return noErr
            default:
                return OSStatus(eventNotHandledErr)
            }
        }

        return OSStatus(eventNotHandledErr)
    }
}

private let hotKeyEventHandler: EventHandlerUPP = { _, event, userData in
    guard let userData, let event else { return OSStatus(eventNotHandledErr) }
    let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
    var hotKeyID = EventHotKeyID(signature: 0, id: 0)
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
    return manager.handleHotKey(id: hotKeyID.id, eventKind: GetEventKind(event))
}

private func carbonModifiers(for modifiers: Set<ShortcutModifier>) -> UInt32 {
    var result: UInt32 = 0
    if modifiers.contains(.command) {
        result |= UInt32(cmdKey)
    }
    if modifiers.contains(.option) {
        result |= UInt32(optionKey)
    }
    if modifiers.contains(.control) {
        result |= UInt32(controlKey)
    }
    if modifiers.contains(.shift) {
        result |= UInt32(shiftKey)
    }
    if modifiers.contains(.function) {
        result |= UInt32(kEventKeyModifierFnMask)
    }
    return result
}

private func fourCharCode(_ string: String) -> OSType {
    string.utf8.reduce(0) { result, character in
        (result << 8) + OSType(character)
    }
}
