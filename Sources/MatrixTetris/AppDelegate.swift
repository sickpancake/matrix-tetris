import AppKit
import MatrixTetrisCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settingsStore = SettingsStore()
    private var dropdownController: DropdownController?
    private var hotKeyManager: HotKeyManager?
    private var statusItem: NSStatusItem?
    private var registeredHotKey: Shortcut?
    private var registeredHoldHotKey: Shortcut?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()

        let dropdown = DropdownController(
            settingsStore: settingsStore,
            onSettingsChanged: { [weak self] settings in
                self?.applySettings(settings)
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
        dropdownController = dropdown

        hotKeyManager = HotKeyManager(
            onTogglePressed: { [weak self] in
                self?.dropdownController?.toggle(anchor: self?.statusItem?.button, source: .hotKey)
            },
            onHoldPressed: { [weak self] in
                self?.dropdownController?.openForHold(anchor: self?.statusItem?.button)
            },
            onHoldReleased: { [weak self] in
                self?.dropdownController?.closeForHoldRelease()
            }
        )

        applySettings(settingsStore.load())
    }

    func applicationWillTerminate(_ notification: Notification) {
        dropdownController?.saveBeforeTerminate()
        hotKeyManager?.unregister()
    }

    @objc private func toggleFromStatusItem() {
        dropdownController?.toggle(anchor: statusItem?.button, source: .statusItem)
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = makeStatusImage()
        item.button?.imagePosition = .imageOnly
        item.button?.target = self
        item.button?.action = #selector(toggleFromStatusItem)
        statusItem = item
    }

    private func applySettings(_ settings: SettingsState) {
        guard registeredHotKey != settings.hotKey || registeredHoldHotKey != settings.holdHotKey else {
            dropdownController?.repositionIfVisible(anchor: statusItem?.button)
            return
        }

        do {
            try hotKeyManager?.register(toggleShortcut: settings.hotKey, holdShortcut: settings.holdHotKey)
            registeredHotKey = settings.hotKey
            registeredHoldHotKey = settings.holdHotKey
            dropdownController?.setShortcutStatus("Shortcuts registered globally.")
        } catch {
            if hotKeyManager?.isToggleRegistered == true {
                registeredHotKey = settings.hotKey
                registeredHoldHotKey = settings.holdHotKey
            } else {
                registeredHotKey = nil
                registeredHoldHotKey = nil
            }
            dropdownController?.setShortcutStatus("Shortcut registration failed. Try a different combo.")
            NSAlert(error: error).runModal()
        }
        dropdownController?.repositionIfVisible(anchor: statusItem?.button)
    }

    private func makeStatusImage() -> NSImage {
        NSImage(size: NSSize(width: 25, height: 18), flipped: false) { rect in
            NSColor.clear.setFill()
            rect.fill()

            let stroke = NSBezierPath(rect: rect.insetBy(dx: 3, dy: 2))
            stroke.lineWidth = 1
            NSColor(calibratedRed: 0.18, green: 1, blue: 0.38, alpha: 0.9).setStroke()
            stroke.stroke()

            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .bold),
                .foregroundColor: NSColor(calibratedRed: 0.25, green: 1, blue: 0.45, alpha: 1)
            ]
            "MT".draw(at: NSPoint(x: 6, y: 3), withAttributes: attributes)
            return true
        }
    }
}
