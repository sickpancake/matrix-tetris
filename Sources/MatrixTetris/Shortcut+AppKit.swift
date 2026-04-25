import AppKit
import MatrixTetrisCore

extension Shortcut {
    init(event: NSEvent, includeFunctionModifier: Bool = true) {
        self.init(
            keyCode: event.keyCode,
            modifiers: ShortcutModifier.from(
                event.modifierFlags,
                includeFunctionModifier: includeFunctionModifier
            )
        )
    }

    func matchesInputEvent(
        _ event: NSEvent,
        ignoringModifiers ignoredModifiers: Set<ShortcutModifier> = []
    ) -> Bool {
        guard keyCode == event.keyCode else { return false }
        var eventModifiers = ShortcutModifier.from(event.modifierFlags)
        if !modifiers.contains(.function) {
            eventModifiers.remove(.function)
        }
        eventModifiers.subtract(ignoredModifiers.subtracting(modifiers))
        return modifiers == eventModifiers
    }

    var displayName: String {
        let modifierText = modifiers
            .sorted { $0.display < $1.display }
            .map(\.display)
            .joined(separator: "+")
        let keyText = KeyCodeFormatter.name(for: keyCode)
        return modifierText.isEmpty ? keyText : "\(modifierText)+\(keyText)"
    }
}

extension ShortcutModifier {
    static func from(
        _ flags: NSEvent.ModifierFlags,
        includeFunctionModifier: Bool = true
    ) -> Set<ShortcutModifier> {
        var relevantFlags: NSEvent.ModifierFlags = [.control, .option, .command, .shift]
        if includeFunctionModifier {
            relevantFlags.insert(.function)
        }
        let filteredFlags = flags.intersection(relevantFlags)
        var modifiers: Set<ShortcutModifier> = []
        if filteredFlags.contains(.control) {
            modifiers.insert(.control)
        }
        if filteredFlags.contains(.option) {
            modifiers.insert(.option)
        }
        if filteredFlags.contains(.command) {
            modifiers.insert(.command)
        }
        if filteredFlags.contains(.shift) {
            modifiers.insert(.shift)
        }
        if filteredFlags.contains(.function) {
            modifiers.insert(.function)
        }
        return modifiers
    }
}

enum KeyCodeFormatter {
    static func name(for keyCode: UInt16) -> String {
        switch keyCode {
        case MacKeyCode.leftArrow:
            "Left"
        case MacKeyCode.rightArrow:
            "Right"
        case MacKeyCode.downArrow:
            "Down"
        case MacKeyCode.upArrow:
            "Up"
        case MacKeyCode.space:
            "Space"
        case MacKeyCode.grave:
            "~"
        case MacKeyCode.z:
            "Z"
        case MacKeyCode.r:
            "R"
        case MacKeyCode.t:
            "T"
        case MacKeyCode.p:
            "P"
        case MacKeyCode.a:
            "A"
        case MacKeyCode.s:
            "S"
        case MacKeyCode.d:
            "D"
        default:
            "#\(keyCode)"
        }
    }
}
