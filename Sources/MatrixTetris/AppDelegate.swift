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
        item.button?.title = "MT"
        item.button?.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
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
        } catch {
            if hotKeyManager?.isToggleRegistered == true {
                registeredHotKey = settings.hotKey
                registeredHoldHotKey = settings.holdHotKey
            } else {
                registeredHotKey = nil
                registeredHoldHotKey = nil
            }
            NSAlert(error: error).runModal()
        }
        dropdownController?.repositionIfVisible(anchor: statusItem?.button)
    }
}
