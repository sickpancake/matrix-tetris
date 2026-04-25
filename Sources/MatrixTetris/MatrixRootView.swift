import AppKit
import MatrixTetrisCore

final class MatrixRootView: NSView {
    private let engine = GameEngine()
    private let settingsStore: SettingsStore
    private let savedGameStore = SavedGameStore()
    private let statsStore = StatsStore()
    private let appMetaStore = AppMetaStore()
    private let onSettingsChanged: (SettingsState) -> Void
    private let onClose: () -> Void
    private let onQuit: () -> Void

    private let boardView: TetrisBoardView
    private let nextPieceView: NextPieceView
    private let scoreLabel = NSTextField(labelWithString: "")
    private let highScoreLabel = NSTextField(labelWithString: "")
    private let levelLabel = NSTextField(labelWithString: "")
    private let linesLabel = NSTextField(labelWithString: "")
    private let stateLabel = NSTextField(labelWithString: "")
    private let detailScrollView = NSScrollView()
    private let gameOverSlot = NSStackView()
    private lazy var settingsView = SettingsView(
        settings: settings,
        onChange: { [weak self] settings in
            self?.applySettings(settings)
        },
        onResetSavedGame: { [weak self] in
            self?.resetSavedGameFromSettings()
        }
    )

    private var timer: Timer?
    private var lastFrameTime = Date()
    private var gravityAccumulator: TimeInterval = 0
    private var renderTick = 0
    private var heldActions: Set<GameAction> = []
    private var repeatStates: [GameAction: RepeatState] = [:]
    private var resumeAfterSettingsClose = false
    private var holdShortcutIsActive = false
    private var lastSpawnSerial = 0
    private var statsRecordedForGame = false
    private var detailMode: DetailMode?
    private var stats = StatsState.defaultState()
    private var meta = AppMetaState.defaultState()
    private var gameOverPanel: MatrixInfoPanel?

    private(set) var settings: SettingsState
    var isCapturingSettingsInput: Bool { settingsView.isCapturing }

    init(
        settingsStore: SettingsStore,
        onSettingsChanged: @escaping (SettingsState) -> Void,
        onClose: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.settingsStore = settingsStore
        self.onSettingsChanged = onSettingsChanged
        self.onClose = onClose
        self.onQuit = onQuit
        settings = settingsStore.load()
        stats = statsStore.load()
        meta = appMetaStore.load()
        boardView = TetrisBoardView(engine: engine)
        nextPieceView = NextPieceView(engine: engine)
        super.init(frame: .zero)
        if let snapshot = savedGameStore.load(), !engine.restore(from: snapshot) {
            savedGameStore.clear()
        }
        buildInterface()
        boardView.animationMode = settings.animationMode
        boardView.ghostOpacity = settings.ghostOpacity
        boardView.animationIntensities = settings.animationIntensities
        lastSpawnSerial = engine.spawnSerial
        updateLabels()
        showStartupPanelsIfNeeded()
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        timer?.invalidate()
    }

    override var acceptsFirstResponder: Bool { true }

    func focusGame() {
        window?.makeFirstResponder(self)
    }

    func resumeRendering() {
        lastFrameTime = Date()
        startTimer()
        updateLabels()
        boardView.needsDisplay = true
        nextPieceView.needsDisplay = true
    }

    func suspendRendering() {
        persistSessionIfNeeded()
        timer?.invalidate()
        timer = nil
        heldActions.removeAll()
        repeatStates.removeAll()
        lastFrameTime = Date()
    }

    func saveBeforeTerminate() {
        persistSessionIfNeeded()
    }

    func setSettingsStatus(_ text: String) {
        settingsView.showStatus(text)
    }

    func setHoldShortcutActive(_ active: Bool) {
        holdShortcutIsActive = active
        if !active {
            clearHeldInput()
        }
    }

    override func keyDown(with event: NSEvent) {
        if settingsView.isCapturing {
            settingsView.capture(event: event)
            return
        }

        guard detailMode == nil else {
            super.keyDown(with: event)
            return
        }

        if holdShortcutIsActive && event.keyCode == settings.holdHotKey.keyCode {
            return
        }

        let ignoredModifiers = holdShortcutIsActive ? settings.holdHotKey.modifiers : []
        guard let action = settings.keyBindings.first(where: { $0.value.matchesInputEvent(event, ignoringModifiers: ignoredModifiers) })?.key else {
            super.keyDown(with: event)
            return
        }

        guard !event.isARepeat else { return }
        perform(action)
        if action.repeatsWhileHeld {
            heldActions.insert(action)
            repeatStates[action] = RepeatState(elapsed: 0, hasRepeated: false)
        }
    }

    override func keyUp(with event: NSEvent) {
        let releasedActions = settings.keyBindings.compactMap { action, shortcut in
            shortcut.keyCode == event.keyCode ? action : nil
        }
        for action in releasedActions {
            heldActions.remove(action)
            repeatStates[action] = nil
        }
    }

    private func buildInterface() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor(calibratedRed: 0.01, green: 0.02, blue: 0.015, alpha: 0.96).cgColor
        layer?.borderColor = NSColor(calibratedRed: 0.08, green: 0.95, blue: 0.39, alpha: 0.85).cgColor
        layer?.borderWidth = 1

        boardView.translatesAutoresizingMaskIntoConstraints = false
        boardView.widthAnchor.constraint(equalToConstant: 250).isActive = true
        boardView.heightAnchor.constraint(equalToConstant: 500).isActive = true

        let sidebar = NSStackView()
        sidebar.orientation = .vertical
        sidebar.alignment = .leading
        sidebar.spacing = 9
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        sidebar.widthAnchor.constraint(equalToConstant: 196).isActive = true

        let title = label("MATRIX TETRIS", size: 16, weight: .bold)
        title.textColor = NSColor(calibratedRed: 0.52, green: 1, blue: 0.65, alpha: 1)
        sidebar.addArrangedSubview(title)
        sidebar.addArrangedSubview(stateLabel)
        sidebar.addArrangedSubview(separator())
        sidebar.addArrangedSubview(scoreLabel)
        sidebar.addArrangedSubview(highScoreLabel)
        sidebar.addArrangedSubview(levelLabel)
        sidebar.addArrangedSubview(linesLabel)
        sidebar.addArrangedSubview(separator())
        sidebar.addArrangedSubview(label("NEXT", size: 12, weight: .semibold))
        sidebar.addArrangedSubview(nextPieceView)
        nextPieceView.translatesAutoresizingMaskIntoConstraints = false
        nextPieceView.widthAnchor.constraint(equalToConstant: 108).isActive = true
        nextPieceView.heightAnchor.constraint(equalToConstant: 72).isActive = true
        sidebar.addArrangedSubview(separator())

        let controls = NSStackView()
        controls.orientation = .horizontal
        controls.spacing = 8
        controls.addArrangedSubview(button("Restart", action: #selector(restartPressed)))
        controls.addArrangedSubview(button("Settings", action: #selector(settingsPressed)))
        sidebar.addArrangedSubview(controls)

        let infoControls = NSStackView()
        infoControls.orientation = .horizontal
        infoControls.spacing = 8
        infoControls.addArrangedSubview(button("Stats", action: #selector(statsPressed)))
        infoControls.addArrangedSubview(button("About", action: #selector(aboutPressed)))
        sidebar.addArrangedSubview(infoControls)

        sidebar.addArrangedSubview(button("What's New", action: #selector(changelogPressed)))

        let closeControls = NSStackView()
        closeControls.orientation = .horizontal
        closeControls.spacing = 8
        closeControls.addArrangedSubview(button("Close", action: #selector(closePressed)))
        closeControls.addArrangedSubview(button("Quit", action: #selector(quitPressed)))
        sidebar.addArrangedSubview(closeControls)

        gameOverSlot.orientation = .vertical
        gameOverSlot.alignment = .leading
        gameOverSlot.spacing = 0
        gameOverSlot.isHidden = true
        sidebar.addArrangedSubview(gameOverSlot)

        settingsView.frame = NSRect(x: 0, y: 0, width: 188, height: 560)
        detailScrollView.documentView = settingsView
        detailScrollView.drawsBackground = false
        detailScrollView.hasVerticalScroller = true
        detailScrollView.borderType = .noBorder
        detailScrollView.translatesAutoresizingMaskIntoConstraints = false
        detailScrollView.isHidden = true
        sidebar.addArrangedSubview(detailScrollView)
        detailScrollView.widthAnchor.constraint(equalToConstant: 196).isActive = true
        detailScrollView.heightAnchor.constraint(equalToConstant: 216).isActive = true

        let mainStack = NSStackView(views: [boardView, sidebar])
        mainStack.orientation = .horizontal
        mainStack.alignment = .top
        mainStack.spacing = 14
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            mainStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12)
        ])

        [scoreLabel, highScoreLabel, levelLabel, linesLabel, stateLabel].forEach(configureInfoLabel)
    }

    private func startTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.frameTick()
        }
        timer?.tolerance = 0.004
    }

    private func frameTick() {
        let now = Date()
        let delta = now.timeIntervalSince(lastFrameTime)
        lastFrameTime = now
        var gameChanged = false

        if engine.status == .running {
            gameChanged = processHeldActions(delta) || gameChanged
            gravityAccumulator += delta
            var gravitySteps = 0
            while gravityAccumulator >= gravityInterval && gravitySteps < 4 {
                let previousLines = engine.linesCleared
                let previousSpawnSerial = engine.spawnSerial
                let tickChanged = engine.tick()
                gravityAccumulator -= gravityInterval
                gameChanged = tickChanged || gameChanged
                triggerAnimations(
                    previousLines: previousLines,
                    previousSpawnSerial: previousSpawnSerial
                )
                gameChanged = finalizeGameIfNeeded() || gameChanged
                gravitySteps += 1
            }
        }

        gameChanged = updateHighScoreIfNeeded() || gameChanged
        gameChanged = finalizeGameIfNeeded() || gameChanged
        if gameChanged {
            persistSessionIfNeeded()
            updateLabels()
            refreshStatsDetailIfVisible()
            boardView.needsDisplay = true
            nextPieceView.needsDisplay = true
        }

        renderTick += 1
        if detailMode == .stats && renderTick % 30 == 0 {
            refreshStatsDetailIfVisible()
        }
        if renderTick % 3 == 0 {
            boardView.advanceRain()
        }
        if boardView.advanceAnimations() {
            boardView.needsDisplay = true
        }
    }

    private var gravityInterval: TimeInterval {
        let baseInterval: TimeInterval = 0.62
        guard settings.speedScalingEnabled else { return baseInterval }
        return max(0.08, baseInterval - TimeInterval(engine.level - 1) * 0.045)
    }

    @discardableResult
    private func perform(_ action: GameAction, refresh: Bool = true) -> Bool {
        var changed = false
        let previousLines = engine.linesCleared
        let previousSpawnSerial = engine.spawnSerial
        let softDropStart = action == .softDrop ? engine.activePiece : nil
        let hardDropStart = action == .hardDrop ? engine.activePiece : nil
        let hardDropTarget = action == .hardDrop ? engine.ghostPiece() : nil
        switch action {
        case .moveLeft:
            changed = engine.moveLeft()
        case .moveRight:
            changed = engine.moveRight()
        case .rotateClockwise:
            changed = engine.rotateClockwise()
        case .rotateCounterclockwise:
            changed = engine.rotateCounterclockwise()
        case .softDrop:
            changed = engine.softDrop()
        case .hardDrop:
            engine.hardDrop()
            changed = true
        case .pause:
            engine.togglePause()
            changed = true
        case .restart:
            startNewGame()
            changed = true
        }

        triggerAnimations(
            previousLines: previousLines,
            previousSpawnSerial: previousSpawnSerial,
            hardDropStart: hardDropStart,
            hardDropTarget: hardDropTarget
        )
        if changed, action == .softDrop, let softDropStart, let softDropEnd = engine.activePiece {
            boardView.triggerSoftDropTrail(from: softDropStart, to: softDropEnd)
        }
        if changed && (action == .moveLeft || action == .moveRight) {
            boardView.triggerMovePulse()
        }

        guard refresh else { return changed }
        let scoreChanged = updateHighScoreIfNeeded()
        let gameEnded = finalizeGameIfNeeded()
        if scoreChanged || gameEnded || changed {
            persistSessionIfNeeded()
            updateLabels()
            refreshStatsDetailIfVisible()
            boardView.needsDisplay = true
            nextPieceView.needsDisplay = true
        }
        return changed
    }

    private func applySettings(_ newSettings: SettingsState) {
        settings = newSettings.normalized()
        settingsStore.save(settings)
        settingsView.settings = settings
        boardView.animationMode = settings.animationMode
        boardView.ghostOpacity = settings.ghostOpacity
        boardView.animationIntensities = settings.animationIntensities
        onSettingsChanged(settings)
        if detailScrollView.isHidden && !settingsView.isCapturing {
            focusGame()
        }
    }

    private func startNewGame() {
        _ = finalizeGameIfNeeded()
        engine.startNewGame()
        gravityAccumulator = 0
        statsRecordedForGame = false
        savedGameStore.clear()
        persistSessionIfNeeded()
        rebuildGameOverPanel()
    }

    private func resetSavedGameFromSettings() {
        savedGameStore.clear()
        engine.startNewGame()
        if detailMode != nil {
            engine.pause()
        }
        gravityAccumulator = 0
        statsRecordedForGame = false
        updateLabels()
        persistSessionIfNeeded()
        refreshStatsDetailIfVisible()
        boardView.triggerSpawnPulse()
        boardView.needsDisplay = true
        nextPieceView.needsDisplay = true
    }

    private func persistSessionIfNeeded() {
        if engine.status == .gameOver {
            _ = finalizeGameIfNeeded()
            savedGameStore.clear()
        } else {
            var snapshot = engine.snapshot()
            if detailMode != nil && resumeAfterSettingsClose {
                snapshot.status = .running
            }
            savedGameStore.save(snapshot)
        }
    }

    @discardableResult
    private func finalizeGameIfNeeded() -> Bool {
        guard engine.status == .gameOver, !statsRecordedForGame else { return false }
        stats = statsStore.recordGame(
            score: engine.score,
            lines: engine.linesCleared,
            lineClearEvents: engine.lineClearEvents,
            duration: Date().timeIntervalSince(engine.startedAt)
        )
        savedGameStore.clear()
        statsRecordedForGame = true
        rebuildGameOverPanel()
        return true
    }

    private func clearHeldInput() {
        heldActions.removeAll()
        repeatStates.removeAll()
    }

    private func updateHighScoreIfNeeded() -> Bool {
        guard engine.score > settings.highScore else { return false }
        settings.highScore = engine.score
        settingsStore.save(settings)
        onSettingsChanged(settings)
        return true
    }

    private func processHeldActions(_ delta: TimeInterval) -> Bool {
        var changed = false
        for action in GameAction.repeatingActions where heldActions.contains(action) {
            var state = repeatStates[action, default: RepeatState(elapsed: 0, hasRepeated: false)]
            state.elapsed += delta
            let interval = repeatInterval(for: action)
            let threshold = state.hasRepeated ? interval : firstRepeatDelay(for: action)
            var repeats = 0

            if state.elapsed >= threshold {
                state.elapsed -= threshold
                state.hasRepeated = true
                changed = perform(action, refresh: false) || changed
                repeats += 1
            }

            while state.hasRepeated && state.elapsed >= interval && repeats < 5 {
                state.elapsed -= interval
                changed = perform(action, refresh: false) || changed
                repeats += 1
            }
            repeatStates[action] = state
        }
        return changed
    }

    private func repeatInterval(for action: GameAction) -> TimeInterval {
        if action == .softDrop {
            let speed = min(max(settings.softDropSpeed, 1), 10)
            return 0.115 - TimeInterval(speed - 1) * 0.0105
        }
        let sensitivity = min(max(settings.inputSensitivity, 1), 10)
        return 0.19 - TimeInterval(sensitivity - 1) * 0.016
    }

    private func firstRepeatDelay(for action: GameAction) -> TimeInterval {
        action == .softDrop ? 0.035 : 0.105
    }

    private func triggerAnimations(
        previousLines: Int,
        previousSpawnSerial: Int,
        hardDropStart: ActivePiece? = nil,
        hardDropTarget: ActivePiece? = nil
    ) {
        guard settings.animationMode == .subtle else { return }
        let cleared = engine.linesCleared - previousLines
        if cleared > 0 {
            boardView.triggerLineClear(rows: engine.lastClearedRows, count: cleared)
        }
        if let hardDropStart, let hardDropTarget {
            boardView.triggerHardDropTrail(from: hardDropStart, to: hardDropTarget)
        }
        if engine.spawnSerial != previousSpawnSerial {
            boardView.triggerSpawnPulse()
        }
        lastSpawnSerial = engine.spawnSerial
    }

    private func updateLabels() {
        scoreLabel.stringValue = "Score: \(engine.score)"
        highScoreLabel.stringValue = "High: \(settings.highScore)"
        levelLabel.stringValue = "Level: \(engine.level)"
        linesLabel.stringValue = "Lines: \(engine.linesCleared)"
        stateLabel.stringValue = stateText
        rebuildGameOverPanel()
    }

    private func refreshStatsDetailIfVisible() {
        guard detailMode == .stats else { return }
        setDetailDocumentView(detailView(for: .stats), scrollToTop: false)
    }

    private func setDetailDocumentView(_ view: NSView, scrollToTop: Bool) {
        detailScrollView.documentView = view
        guard scrollToTop else { return }

        DispatchQueue.main.async { [weak self, weak view] in
            guard let self, let view, self.detailScrollView.documentView === view else { return }
            let clipHeight = self.detailScrollView.contentView.bounds.height
            let topY = view.isFlipped ? 0 : max(0, view.bounds.height - clipHeight)
            self.detailScrollView.contentView.scroll(to: NSPoint(x: 0, y: topY))
            self.detailScrollView.reflectScrolledClipView(self.detailScrollView.contentView)
        }
    }

    private var stateText: String {
        switch engine.status {
        case .running:
            "Status: Running"
        case .paused:
            "Status: Paused"
        case .gameOver:
            "Status: Game Over"
        }
    }

    private func rebuildGameOverPanel() {
        guard engine.status == .gameOver else {
            gameOverSlot.isHidden = true
            if let gameOverPanel {
                gameOverSlot.removeArrangedSubview(gameOverPanel)
                gameOverPanel.removeFromSuperview()
            }
            gameOverPanel = nil
            return
        }

        if let gameOverPanel {
            gameOverSlot.removeArrangedSubview(gameOverPanel)
            gameOverPanel.removeFromSuperview()
        }
        let panel = MatrixInfoPanel(
            title: "GAME OVER",
            lines: [
                "Score: \(engine.score)",
                "High: \(max(settings.highScore, engine.score))",
                "Lines: \(engine.linesCleared)",
                "Level: \(engine.level)"
            ],
            buttons: [
                ("Restart", { [weak self] in self?.restartPressed() }),
                ("Stats", { [weak self] in self?.showDetail(.stats) }),
                ("Settings", { [weak self] in self?.showDetail(.settings) }),
                ("Close", { [weak self] in self?.closePressed() })
            ]
        )
        gameOverPanel = panel
        gameOverSlot.addArrangedSubview(panel)
        gameOverSlot.isHidden = false
    }

    private func showStartupPanelsIfNeeded() {
        if !meta.firstRunCompleted {
            meta = appMetaStore.completeFirstRun()
            showDetail(.firstRun)
            return
        }
        if meta.lastChangelogVersionShown != AppInfo.version {
            meta = appMetaStore.markChangelogShown()
            showDetail(.changelog)
        }
    }

    private func showDetail(_ mode: DetailMode) {
        if detailMode == nil {
            resumeAfterSettingsClose = engine.status == .running
            engine.pause()
            clearHeldInput()
        }

        detailMode = mode
        setDetailDocumentView(detailView(for: mode), scrollToTop: true)
        detailScrollView.isHidden = false
        updateLabels()
        boardView.needsDisplay = true
        nextPieceView.needsDisplay = true

        if mode == .settings {
            window?.makeFirstResponder(settingsView)
        }
    }

    private func hideDetail(markChangelogSeen: Bool = false) {
        if markChangelogSeen {
            meta = appMetaStore.markChangelogShown()
        }

        detailMode = nil
        detailScrollView.isHidden = true
        setDetailDocumentView(settingsView, scrollToTop: true)

        if resumeAfterSettingsClose {
            engine.resume()
        }
        resumeAfterSettingsClose = false
        updateLabels()
        focusGame()
    }

    private func detailView(for mode: DetailMode) -> NSView {
        switch mode {
        case .settings:
            settingsView.frame = NSRect(x: 0, y: 0, width: 188, height: 1_120)
            return settingsView
        case .firstRun:
            return MatrixInfoPanel(
                title: "FIRST RUN",
                lines: [
                    "Toggle: \(settings.hotKey.displayName)",
                    "Hold: \(settings.holdHotKey.displayName)",
                    "Dropdown: \(settings.dropdownPosition.label)",
                    "Move with arrows, rotate with Up/Z, hard drop with Space, pause with P."
                ],
                buttons: [
                    ("Get Started", { [weak self] in self?.completeFirstRun() }),
                    ("Settings", { [weak self] in self?.showDetail(.settings) })
                ]
            )
        case .stats:
            let summary = liveStatsSummary()
            return MatrixInfoPanel(
                title: "STATS",
                lines: summary,
                buttons: [
                    ("Close", { [weak self] in self?.hideDetail() })
                ]
            )
        case .about:
            return MatrixInfoPanel(
                title: "ABOUT",
                lines: [
                    AppInfo.displayVersion,
                    "Build \(AppInfo.build)",
                    "Native Swift/AppKit menu-bar Tetris.",
                    "GitHub release zip for Apple Silicon Macs.",
                    "No third-party runtime dependencies.",
                    "macOS 13+"
                ],
                buttons: [
                    ("Check Updates", { [weak self] in self?.openUpdates() }),
                    ("Close", { [weak self] in self?.hideDetail() })
                ]
            )
        case .changelog:
            return MatrixInfoPanel(
                title: "WHAT'S NEW",
                lines: AppInfo.v110Changelog,
                buttons: [
                    ("Continue", { [weak self] in self?.hideDetail() }),
                    ("Check Updates", { [weak self] in self?.openUpdates() })
                ]
            )
        }
    }

    private func completeFirstRun() {
        meta = appMetaStore.completeFirstRun()
        if meta.lastChangelogVersionShown != AppInfo.version {
            meta = appMetaStore.markChangelogShown()
            showDetail(.changelog)
        } else {
            hideDetail()
        }
    }

    private func openUpdates() {
        NSWorkspace.shared.open(AppInfo.latestReleaseURL)
    }

    private func liveStatsSummary() -> [String] {
        stats = statsStore.load()
        let includeCurrentRun = engine.status != .gameOver || !statsRecordedForGame
        let liveBestScore = max(stats.bestScore, settings.highScore, engine.score)
        let liveBestLines = max(stats.bestLines, engine.linesCleared)
        let liveTotalLines = stats.totalLines + (includeCurrentRun ? engine.linesCleared : 0)
        let liveTotalClears = stats.totalLineClears + (includeCurrentRun ? engine.lineClearEvents : 0)
        let livePlayTime = stats.totalPlayTime + (includeCurrentRun ? Date().timeIntervalSince(engine.startedAt) : 0)

        return [
            "Current Score: \(engine.score)",
            "Current Lines: \(engine.linesCleared)",
            "Games Finished: \(stats.gamesPlayed)",
            "Best Score: \(liveBestScore)",
            "Best Lines: \(liveBestLines)",
            "Total Lines: \(liveTotalLines)",
            "Clear Events: \(liveTotalClears)",
            "Play Time: \(formatDuration(livePlayTime))",
            "Last Finished: \(formatDate(stats.lastPlayed))"
        ]
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "Never" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    @objc private func restartPressed() {
        perform(.restart)
        focusGame()
    }

    @objc private func settingsPressed() {
        if detailMode == .settings {
            hideDetail()
        } else {
            showDetail(.settings)
        }
    }

    @objc private func statsPressed() {
        if detailMode == .stats {
            hideDetail()
        } else {
            showDetail(.stats)
        }
    }

    @objc private func aboutPressed() {
        if detailMode == .about {
            hideDetail()
        } else {
            showDetail(.about)
        }
    }

    @objc private func changelogPressed() {
        if detailMode == .changelog {
            hideDetail(markChangelogSeen: true)
        } else {
            showDetail(.changelog)
        }
    }

    @objc private func closePressed() {
        persistSessionIfNeeded()
        onClose()
    }

    @objc private func quitPressed() {
        persistSessionIfNeeded()
        onQuit()
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .monospacedSystemFont(ofSize: size, weight: weight)
        field.textColor = NSColor(calibratedRed: 0.28, green: 1, blue: 0.45, alpha: 1)
        field.maximumNumberOfLines = 1
        return field
    }

    private func configureInfoLabel(_ field: NSTextField) {
        field.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        field.textColor = NSColor(calibratedRed: 0.45, green: 1, blue: 0.58, alpha: 1)
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalToConstant: 184).isActive = true
        return box
    }

    private func button(_ title: String, action: Selector) -> NSButton {
        MatrixButton(title: title, target: self, action: action)
    }
}

private struct RepeatState {
    var elapsed: TimeInterval
    var hasRepeated: Bool
}

private enum DetailMode {
    case settings
    case stats
    case about
    case changelog
    case firstRun
}

private extension GameAction {
    static let repeatingActions: [GameAction] = [.moveLeft, .moveRight, .softDrop]

    var repeatsWhileHeld: Bool {
        Self.repeatingActions.contains(self)
    }
}
