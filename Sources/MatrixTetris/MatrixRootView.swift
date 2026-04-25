import AppKit
import MatrixTetrisCore

final class MatrixRootView: NSView {
    private let engine = GameEngine()
    private let settingsStore: SettingsStore
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
    private let settingsScrollView = NSScrollView()
    private lazy var settingsView = SettingsView(settings: settings) { [weak self] settings in
        self?.applySettings(settings)
    }

    private var timer: Timer?
    private var lastFrameTime = Date()
    private var gravityAccumulator: TimeInterval = 0
    private var renderTick = 0
    private var heldActions: Set<GameAction> = []
    private var repeatStates: [GameAction: RepeatState] = [:]
    private var resumeAfterSettingsClose = false
    private var holdShortcutIsActive = false
    private var lastSpawnSerial = 0

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
        boardView = TetrisBoardView(engine: engine)
        nextPieceView = NextPieceView(engine: engine)
        super.init(frame: .zero)
        buildInterface()
        boardView.animationMode = settings.animationMode
        lastSpawnSerial = engine.spawnSerial
        updateLabels()
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
        timer?.invalidate()
        timer = nil
        heldActions.removeAll()
        repeatStates.removeAll()
        lastFrameTime = Date()
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

        let closeControls = NSStackView()
        closeControls.orientation = .horizontal
        closeControls.spacing = 8
        closeControls.addArrangedSubview(button("Close", action: #selector(closePressed)))
        closeControls.addArrangedSubview(button("Quit", action: #selector(quitPressed)))
        sidebar.addArrangedSubview(closeControls)

        settingsView.frame = NSRect(x: 0, y: 0, width: 188, height: 560)
        settingsScrollView.documentView = settingsView
        settingsScrollView.drawsBackground = false
        settingsScrollView.hasVerticalScroller = true
        settingsScrollView.borderType = .noBorder
        settingsScrollView.translatesAutoresizingMaskIntoConstraints = false
        settingsScrollView.isHidden = true
        sidebar.addArrangedSubview(settingsScrollView)
        settingsScrollView.widthAnchor.constraint(equalToConstant: 196).isActive = true
        settingsScrollView.heightAnchor.constraint(equalToConstant: 216).isActive = true

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
                gravitySteps += 1
            }
        }

        gameChanged = updateHighScoreIfNeeded() || gameChanged
        if gameChanged {
            updateLabels()
            boardView.needsDisplay = true
            nextPieceView.needsDisplay = true
        }

        renderTick += 1
        if renderTick % 3 == 0 {
            boardView.advanceRain()
        }
        if boardView.advanceAnimations() {
            boardView.needsDisplay = true
        }
    }

    private var gravityInterval: TimeInterval {
        max(0.08, 0.62 - TimeInterval(engine.level - 1) * 0.045)
    }

    @discardableResult
    private func perform(_ action: GameAction, refresh: Bool = true) -> Bool {
        var changed = false
        let previousLines = engine.linesCleared
        let previousSpawnSerial = engine.spawnSerial
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
            engine.reset()
            gravityAccumulator = 0
            changed = true
        }

        triggerAnimations(
            previousLines: previousLines,
            previousSpawnSerial: previousSpawnSerial,
            hardDropStart: hardDropStart,
            hardDropTarget: hardDropTarget
        )

        guard refresh else { return changed }
        if updateHighScoreIfNeeded() || changed {
            updateLabels()
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
        onSettingsChanged(settings)
        if settingsScrollView.isHidden && !settingsView.isCapturing {
            focusGame()
        }
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

    @objc private func restartPressed() {
        perform(.restart)
        focusGame()
    }

    @objc private func settingsPressed() {
        let willOpen = settingsScrollView.isHidden
        settingsScrollView.isHidden = !willOpen

        if willOpen {
            resumeAfterSettingsClose = engine.status == .running
            engine.pause()
            clearHeldInput()
            updateLabels()
            boardView.needsDisplay = true
            nextPieceView.needsDisplay = true
            window?.makeFirstResponder(settingsView)
        } else {
            if resumeAfterSettingsClose {
                engine.resume()
            }
            resumeAfterSettingsClose = false
            updateLabels()
            focusGame()
        }
    }

    @objc private func closePressed() {
        onClose()
    }

    @objc private func quitPressed() {
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

private extension GameAction {
    static let repeatingActions: [GameAction] = [.moveLeft, .moveRight, .softDrop]

    var repeatsWhileHeld: Bool {
        Self.repeatingActions.contains(self)
    }
}
