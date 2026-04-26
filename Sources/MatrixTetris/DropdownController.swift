import AppKit
import MatrixTetrisCore

enum DropdownSource {
    case hotKey
    case statusItem
}

final class DropdownController {
    private let panelSize = NSSize(width: 500, height: 580)
    private let toggleDebounce: TimeInterval = 0.18
    private let settingsStore: SettingsStore
    private let soundManager: SoundManager
    private let onSettingsChanged: (SettingsState) -> Void
    private let onQuit: () -> Void
    private var localHotKeyMonitor: Any?
    private var lastToggleTime: TimeInterval = 0
    private var openedByHoldHotKey = false
    private var isHiding = false
    private var rootView: MatrixRootView?
    private lazy var panel: GamePanel = makePanel()

    init(
        settingsStore: SettingsStore,
        soundManager: SoundManager,
        onSettingsChanged: @escaping (SettingsState) -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.settingsStore = settingsStore
        self.soundManager = soundManager
        self.onSettingsChanged = onSettingsChanged
        self.onQuit = onQuit
    }

    func toggle(anchor: NSStatusBarButton?, source: DropdownSource) {
        guard acceptToggleEvent() else { return }
        if panel.isVisible {
            hide()
        } else {
            show(anchor: anchor, source: source)
        }
    }

    func openForHold(anchor: NSStatusBarButton?) {
        guard !panel.isVisible else {
            openedByHoldHotKey = false
            rootView?.setHoldShortcutActive(false)
            return
        }
        openedByHoldHotKey = true
        gameView().setHoldShortcutActive(true)
        show(anchor: anchor, source: .hotKey)
    }

    func closeForHoldRelease() {
        guard openedByHoldHotKey else { return }
        hide()
    }

    func repositionIfVisible(anchor: NSStatusBarButton?) {
        guard panel.isVisible, let rootView else { return }
        panel.setFrame(frame(for: rootView.settings.dropdownPosition, anchor: anchor), display: true, animate: true)
    }

    func saveBeforeTerminate() {
        rootView?.saveBeforeTerminate()
    }

    func setShortcutStatus(_ text: String) {
        rootView?.setSettingsStatus(text)
    }

    private func show(anchor: NSStatusBarButton?, source: DropdownSource) {
        let rootView = gameView()
        panel.setFrame(frame(for: effectivePosition(source: source), anchor: anchor), display: false)
        panel.contentView = rootView
        rootView.resumeRendering()
        installLocalHotKeyMonitor()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        soundManager.play(.dropdownOpen)
        rootView.focusGame()
    }

    private func hide() {
        guard panel.isVisible else { return }
        openedByHoldHotKey = false
        rootView?.setHoldShortcutActive(false)
        rootView?.suspendRendering()
        removeLocalHotKeyMonitor()
        isHiding = true
        panel.orderOut(nil)
        isHiding = false
        soundManager.play(.dropdownClose)
    }

    private func gameView() -> MatrixRootView {
        if let rootView {
            return rootView
        }
        let view = MatrixRootView(
            settingsStore: settingsStore,
            soundManager: soundManager,
            onSettingsChanged: onSettingsChanged,
            onClose: { [weak self] in
                self?.hide()
            },
            onQuit: onQuit
        )
        rootView = view
        return view
    }

    private func acceptToggleEvent() -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastToggleTime >= toggleDebounce else { return false }
        lastToggleTime = now
        return true
    }

    private func installLocalHotKeyMonitor() {
        guard localHotKeyMonitor == nil else { return }
        localHotKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard let rootView = self.rootView else { return event }
            guard !rootView.isCapturingSettingsInput else { return event }
            guard Shortcut(event: event) == rootView.settings.hotKey else { return event }
            guard self.acceptToggleEvent() else { return nil }
            self.hide()
            return nil
        }
    }

    private func removeLocalHotKeyMonitor() {
        guard let localHotKeyMonitor else { return }
        NSEvent.removeMonitor(localHotKeyMonitor)
        self.localHotKeyMonitor = nil
    }

    private func effectivePosition(source: DropdownSource) -> DropdownPosition {
        let configured = gameView().settings.dropdownPosition
        if source == .statusItem && configured == .menuBar {
            return .menuBar
        }
        return configured
    }

    private func makePanel() -> GamePanel {
        let panel = GamePanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .transient, .fullScreenAuxiliary]
        panel.onResignKey = { [weak self] in
            self?.hideAfterFocusLoss()
        }
        return panel
    }

    private func hideAfterFocusLoss() {
        guard panel.isVisible, !isHiding else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.panel.isVisible, !self.isHiding else { return }
            self.hide()
        }
    }

    private func frame(for position: DropdownPosition, anchor: NSStatusBarButton?) -> NSRect {
        let screen = activeScreen()
        let visible = screen.visibleFrame
        var origin: NSPoint

        switch position {
        case .rightSide:
            origin = NSPoint(x: visible.maxX - panelSize.width - 24, y: visible.maxY - panelSize.height - 18)
        case .leftSide:
            origin = NSPoint(x: visible.minX + 24, y: visible.maxY - panelSize.height - 18)
        case .topCenter:
            origin = NSPoint(x: visible.midX - panelSize.width / 2, y: visible.maxY - panelSize.height - 18)
        case .mousePosition:
            let mouse = NSEvent.mouseLocation
            origin = NSPoint(x: mouse.x - panelSize.width + 32, y: mouse.y - 24 - panelSize.height)
        case .menuBar:
            origin = menuBarOrigin(anchor: anchor, visibleFrame: visible)
        }

        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - panelSize.width - 8)
        origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - panelSize.height - 8)
        return NSRect(origin: origin, size: panelSize)
    }

    private func menuBarOrigin(anchor: NSStatusBarButton?, visibleFrame: NSRect) -> NSPoint {
        guard
            let anchor,
            let window = anchor.window
        else {
            return NSPoint(x: visibleFrame.maxX - panelSize.width - 24, y: visibleFrame.maxY - panelSize.height - 18)
        }

        let localFrame = anchor.convert(anchor.bounds, to: nil)
        let screenFrame = window.convertToScreen(localFrame)
        return NSPoint(
            x: screenFrame.midX - panelSize.width + 30,
            y: screenFrame.minY - panelSize.height - 8
        )
    }

    private func activeScreen() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { screen in
            screen.frame.contains(mouse)
        } ?? NSScreen.main ?? NSScreen.screens[0]
    }
}

final class GamePanel: NSPanel {
    var onResignKey: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }

    override func resignMain() {
        super.resignMain()
        onResignKey?()
    }
}
