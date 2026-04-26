import AppKit
import MatrixTetrisCore

final class SettingsView: NSView {
    enum CaptureTarget {
        case hotKey
        case holdHotKey
        case action(GameAction)
    }

    var settings: SettingsState {
        didSet {
            refresh()
        }
    }

    var isCapturing: Bool {
        captureTarget != nil
    }

    private let onChange: (SettingsState) -> Void
    private let statusLabel = NSTextField(labelWithString: "")
    private let positionPopup = NSPopUpButton()
    private let sensitivitySlider = NSSlider(value: 5, minValue: 1, maxValue: 10, target: nil, action: nil)
    private let sensitivityValueLabel = NSTextField(labelWithString: "")
    private let softDropSlider = NSSlider(value: 7, minValue: 1, maxValue: 10, target: nil, action: nil)
    private let softDropValueLabel = NSTextField(labelWithString: "")
    private let speedScalingCheckbox = NSButton(checkboxWithTitle: "Keep speeding up by level", target: nil, action: nil)
    private let soundEnabledCheckbox = NSButton(checkboxWithTitle: "Enable sound", target: nil, action: nil)
    private let soundVolumeSlider = NSSlider(value: 6, minValue: 0, maxValue: 10, target: nil, action: nil)
    private let soundVolumeValueLabel = NSTextField(labelWithString: "")
    private let soundThemePopup = NSPopUpButton()
    private let ghostOpacitySlider = NSSlider(value: 4, minValue: 1, maxValue: 10, target: nil, action: nil)
    private let ghostOpacityValueLabel = NSTextField(labelWithString: "")
    private let animationPopup = NSPopUpButton()
    private lazy var hotKeyButton = MatrixButton(target: self, action: #selector(captureHotKey))
    private lazy var holdHotKeyButton = MatrixButton(target: self, action: #selector(captureHoldHotKey))
    private var actionButtons: [GameAction: NSButton] = [:]
    private var animationSliders: [AnimationEffect: NSSlider] = [:]
    private var animationValueLabels: [AnimationEffect: NSTextField] = [:]
    private var captureTarget: CaptureTarget?

    private let onResetSavedGame: () -> Void
    private let onTestSounds: () -> Void

    init(
        settings: SettingsState,
        onChange: @escaping (SettingsState) -> Void,
        onResetSavedGame: @escaping () -> Void,
        onTestSounds: @escaping () -> Void
    ) {
        self.settings = settings
        self.onChange = onChange
        self.onResetSavedGame = onResetSavedGame
        self.onTestSounds = onTestSounds
        super.init(frame: .zero)
        buildInterface()
        refresh()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        capture(event: event)
    }

    func showStatus(_ text: String) {
        statusLabel.stringValue = text
    }

    func capture(event: NSEvent) {
        guard let captureTarget else { return }
        if event.keyCode == 53 {
            self.captureTarget = nil
            statusLabel.stringValue = "Capture cancelled."
            refresh()
            return
        }

        let savedShortcut: Shortcut
        let statusText: String
        switch captureTarget {
        case .hotKey:
            let shortcut = Shortcut(event: event)
            guard !shortcut.modifiers.isEmpty else {
                statusLabel.stringValue = "Hotkey needs Ctrl, Opt, Cmd, Shift, or Fn."
                return
            }
            guard shortcut != settings.holdHotKey else {
                statusLabel.stringValue = "Toggle and hold keys must be different."
                return
            }
            settings.hotKey = shortcut
            savedShortcut = shortcut
            statusText = "Saved \(savedShortcut.displayName). Global shortcut refreshed."
        case .holdHotKey:
            let shortcut = Shortcut(event: event)
            guard !shortcut.modifiers.isEmpty else {
                statusLabel.stringValue = "Hold key needs Ctrl, Opt, Cmd, Shift, or Fn."
                return
            }
            guard shortcut != settings.hotKey else {
                statusLabel.stringValue = "Toggle and hold keys must be different."
                return
            }
            settings.holdHotKey = shortcut
            savedShortcut = shortcut
            statusText = "Saved \(savedShortcut.displayName). Global shortcut refreshed."
        case .action(let action):
            let shortcut = Shortcut(event: event, includeFunctionModifier: false)
            let duplicate = settings.keyBindings.first { entry in
                entry.key != action && entry.value == shortcut
            }?.key
            settings.keyBindings[action] = shortcut
            savedShortcut = shortcut
            if let duplicate {
                statusText = "Saved \(savedShortcut.displayName). Also used by \(duplicate.label)."
            } else {
                statusText = "Saved \(savedShortcut.displayName)."
            }
        }

        self.captureTarget = nil
        onChange(settings)
        statusLabel.stringValue = statusText
        refresh()
    }

    private func buildInterface() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.backgroundColor = NSColor(calibratedRed: 0, green: 0.04, blue: 0.018, alpha: 0.82).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor(calibratedRed: 0.12, green: 0.8, blue: 0.28, alpha: 0.55).cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])

        stack.addArrangedSubview(header("SETTINGS"))
        stack.addArrangedSubview(settingLabel("Dropdown"))
        positionPopup.removeAllItems()
        DropdownPosition.allCases.forEach { positionPopup.addItem(withTitle: $0.label) }
        positionPopup.target = self
        positionPopup.action = #selector(positionChanged)
        stack.addArrangedSubview(positionPopup)

        stack.addArrangedSubview(settingLabel("Movement Sensitivity"))
        let sensitivityRow = sliderRow(
            slider: sensitivitySlider,
            valueLabel: sensitivityValueLabel,
            action: #selector(sensitivityChanged)
        )
        stack.addArrangedSubview(sensitivityRow)

        stack.addArrangedSubview(settingLabel("Soft Drop Speed"))
        let softDropRow = sliderRow(
            slider: softDropSlider,
            valueLabel: softDropValueLabel,
            action: #selector(softDropSpeedChanged)
        )
        stack.addArrangedSubview(softDropRow)

        stack.addArrangedSubview(settingLabel("Speed Scaling"))
        stack.addArrangedSubview(subtitleLabel("Off keeps falling speed steady. On speeds up as your level rises."))
        speedScalingCheckbox.target = self
        speedScalingCheckbox.action = #selector(speedScalingChanged)
        configureCheckbox(speedScalingCheckbox)
        stack.addArrangedSubview(speedScalingCheckbox)

        stack.addArrangedSubview(settingLabel("Sound"))
        soundEnabledCheckbox.target = self
        soundEnabledCheckbox.action = #selector(soundEnabledChanged)
        configureCheckbox(soundEnabledCheckbox)
        stack.addArrangedSubview(soundEnabledCheckbox)

        stack.addArrangedSubview(settingLabel("Sound Theme"))
        soundThemePopup.removeAllItems()
        SoundTheme.allCases.forEach { soundThemePopup.addItem(withTitle: $0.label) }
        soundThemePopup.target = self
        soundThemePopup.action = #selector(soundThemeChanged)
        stack.addArrangedSubview(soundThemePopup)

        stack.addArrangedSubview(settingLabel("Sound Volume"))
        let soundVolumeRow = sliderRow(
            slider: soundVolumeSlider,
            valueLabel: soundVolumeValueLabel,
            action: #selector(soundVolumeChanged),
            tickMarks: 11
        )
        stack.addArrangedSubview(soundVolumeRow)

        let testSounds = MatrixButton(title: "Test Sounds", target: self, action: #selector(testSoundsPressed))
        stack.addArrangedSubview(testSounds)

        stack.addArrangedSubview(settingLabel("Animations"))
        animationPopup.removeAllItems()
        AnimationMode.allCases.forEach { animationPopup.addItem(withTitle: $0.label) }
        animationPopup.target = self
        animationPopup.action = #selector(animationChanged)
        stack.addArrangedSubview(animationPopup)

        stack.addArrangedSubview(subtitleLabel("Set an effect to 0 to hide only that animation."))
        for effect in AnimationEffect.allCases {
            stack.addArrangedSubview(settingLabel(effect.label))
            let slider = NSSlider(value: Double(settings.animationIntensities.value(for: effect)), minValue: 0, maxValue: 10, target: nil, action: nil)
            slider.tag = AnimationEffect.allCases.firstIndex(of: effect) ?? 0
            let valueLabel = NSTextField(labelWithString: "")
            animationSliders[effect] = slider
            animationValueLabels[effect] = valueLabel
            stack.addArrangedSubview(sliderRow(
                slider: slider,
                valueLabel: valueLabel,
                action: #selector(animationIntensityChanged(_:)),
                tickMarks: 11
            ))
        }

        stack.addArrangedSubview(settingLabel("Ghost Opacity"))
        let ghostOpacityRow = sliderRow(
            slider: ghostOpacitySlider,
            valueLabel: ghostOpacityValueLabel,
            action: #selector(ghostOpacityChanged)
        )
        stack.addArrangedSubview(ghostOpacityRow)

        stack.addArrangedSubview(settingLabel("Toggle Open / Close"))
        stack.addArrangedSubview(hotKeyButton)

        stack.addArrangedSubview(settingLabel("Hold To Open"))
        stack.addArrangedSubview(holdHotKeyButton)

        stack.addArrangedSubview(settingLabel("Controls"))
        for action in GameAction.allCases {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 8

            let label = settingLabel(action.label)
            label.widthAnchor.constraint(equalToConstant: 92).isActive = true

            let button = MatrixButton(target: self, action: #selector(captureAction(_:)))
            button.tag = GameAction.allCases.firstIndex(of: action) ?? 0
            button.widthAnchor.constraint(equalToConstant: 90).isActive = true
            actionButtons[action] = button

            row.addArrangedSubview(label)
            row.addArrangedSubview(button)
            stack.addArrangedSubview(row)
        }

        let reset = MatrixButton(title: "Reset Settings", target: self, action: #selector(resetPressed))
        stack.addArrangedSubview(reset)

        let resetSavedGame = MatrixButton(title: "Reset Saved Game", target: self, action: #selector(resetSavedGamePressed))
        stack.addArrangedSubview(resetSavedGame)

        let version = settingLabel(AppInfo.displayVersion)
        version.textColor = NSColor(calibratedRed: 0.5, green: 1, blue: 0.62, alpha: 0.85)
        stack.addArrangedSubview(version)

        statusLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        statusLabel.textColor = NSColor(calibratedRed: 0.5, green: 1, blue: 0.62, alpha: 0.9)
        statusLabel.maximumNumberOfLines = 2
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.widthAnchor.constraint(equalToConstant: 168).isActive = true
        stack.addArrangedSubview(statusLabel)
    }

    private func sliderRow(
        slider: NSSlider,
        valueLabel: NSTextField,
        action: Selector,
        tickMarks: Int = 10
    ) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        slider.target = self
        slider.action = action
        slider.numberOfTickMarks = tickMarks
        slider.allowsTickMarkValuesOnly = true
        slider.widthAnchor.constraint(equalToConstant: 128).isActive = true
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        valueLabel.textColor = NSColor(calibratedRed: 0.54, green: 1, blue: 0.65, alpha: 1)
        valueLabel.widthAnchor.constraint(equalToConstant: 24).isActive = true
        row.addArrangedSubview(slider)
        row.addArrangedSubview(valueLabel)
        return row
    }

    private func configureCheckbox(_ checkbox: NSButton) {
        checkbox.font = .monospacedSystemFont(ofSize: 10.5, weight: .medium)
        checkbox.contentTintColor = NSColor(calibratedRed: 0.32, green: 1, blue: 0.5, alpha: 0.92)
    }

    private func refresh() {
        if let index = DropdownPosition.allCases.firstIndex(of: settings.dropdownPosition) {
            positionPopup.selectItem(at: index)
        }
        sensitivitySlider.integerValue = settings.inputSensitivity
        sensitivityValueLabel.stringValue = "\(settings.inputSensitivity)"
        softDropSlider.integerValue = settings.softDropSpeed
        softDropValueLabel.stringValue = "\(settings.softDropSpeed)"
        speedScalingCheckbox.state = settings.speedScalingEnabled ? .on : .off
        ghostOpacitySlider.integerValue = settings.ghostOpacity
        ghostOpacityValueLabel.stringValue = "\(settings.ghostOpacity)"
        soundEnabledCheckbox.state = settings.soundEnabled ? .on : .off
        soundVolumeSlider.integerValue = settings.soundVolume
        soundVolumeValueLabel.stringValue = "\(settings.soundVolume)"
        if let soundThemeIndex = SoundTheme.allCases.firstIndex(of: settings.soundTheme) {
            soundThemePopup.selectItem(at: soundThemeIndex)
        }
        if let animationIndex = AnimationMode.allCases.firstIndex(of: settings.animationMode) {
            animationPopup.selectItem(at: animationIndex)
        }
        for effect in AnimationEffect.allCases {
            let value = settings.animationIntensities.value(for: effect)
            animationSliders[effect]?.integerValue = value
            animationValueLabels[effect]?.stringValue = "\(value)"
        }
        hotKeyButton.title = captureTargetText(.hotKey) ?? settings.hotKey.displayName
        holdHotKeyButton.title = captureTargetText(.holdHotKey) ?? settings.holdHotKey.displayName
        for action in GameAction.allCases {
            actionButtons[action]?.title = captureTargetText(.action(action)) ?? settings.keyBindings[action]?.displayName ?? "Unset"
        }
    }

    private func captureTargetText(_ target: CaptureTarget) -> String? {
        guard let captureTarget, captureTarget == target else { return nil }
        return "Press key"
    }

    @objc private func positionChanged() {
        let index = positionPopup.indexOfSelectedItem
        guard DropdownPosition.allCases.indices.contains(index) else { return }
        settings.dropdownPosition = DropdownPosition.allCases[index]
        onChange(settings)
        statusLabel.stringValue = "Dropdown location saved."
    }

    @objc private func sensitivityChanged() {
        settings.inputSensitivity = min(max(sensitivitySlider.integerValue, 1), 10)
        sensitivityValueLabel.stringValue = "\(settings.inputSensitivity)"
        onChange(settings)
        statusLabel.stringValue = "Movement sensitivity saved."
    }

    @objc private func softDropSpeedChanged() {
        settings.softDropSpeed = min(max(softDropSlider.integerValue, 1), 10)
        softDropValueLabel.stringValue = "\(settings.softDropSpeed)"
        onChange(settings)
        statusLabel.stringValue = "Soft drop speed saved."
    }

    @objc private func speedScalingChanged() {
        settings.speedScalingEnabled = speedScalingCheckbox.state == .on
        onChange(settings)
        statusLabel.stringValue = settings.speedScalingEnabled ? "Speed scaling enabled." : "Speed scaling disabled."
    }

    @objc private func soundEnabledChanged() {
        settings.soundEnabled = soundEnabledCheckbox.state == .on
        onChange(settings)
        statusLabel.stringValue = settings.soundEnabled ? "Sound enabled." : "Sound muted."
    }

    @objc private func soundVolumeChanged() {
        settings.soundVolume = min(max(soundVolumeSlider.integerValue, 0), 10)
        soundVolumeValueLabel.stringValue = "\(settings.soundVolume)"
        onChange(settings)
        statusLabel.stringValue = "Sound volume saved."
    }

    @objc private func soundThemeChanged() {
        let index = soundThemePopup.indexOfSelectedItem
        guard SoundTheme.allCases.indices.contains(index) else { return }
        settings.soundTheme = SoundTheme.allCases[index]
        onChange(settings)
        statusLabel.stringValue = "\(settings.soundTheme.label) selected."
    }

    @objc private func testSoundsPressed() {
        onTestSounds()
        statusLabel.stringValue = "Playing sound test."
    }

    @objc private func animationChanged() {
        let index = animationPopup.indexOfSelectedItem
        guard AnimationMode.allCases.indices.contains(index) else { return }
        settings.animationMode = AnimationMode.allCases[index]
        onChange(settings)
        statusLabel.stringValue = "Animation setting saved."
    }

    @objc private func animationIntensityChanged(_ sender: NSSlider) {
        let effects = AnimationEffect.allCases
        guard effects.indices.contains(sender.tag) else { return }
        let effect = effects[sender.tag]
        settings.animationIntensities.setValue(sender.integerValue, for: effect)
        animationValueLabels[effect]?.stringValue = "\(settings.animationIntensities.value(for: effect))"
        onChange(settings)
        statusLabel.stringValue = "\(effect.label) saved."
    }

    @objc private func ghostOpacityChanged() {
        settings.ghostOpacity = min(max(ghostOpacitySlider.integerValue, 1), 10)
        ghostOpacityValueLabel.stringValue = "\(settings.ghostOpacity)"
        onChange(settings)
        statusLabel.stringValue = "Ghost opacity saved."
    }

    @objc private func captureHotKey() {
        beginCapture(.hotKey)
    }

    @objc private func captureHoldHotKey() {
        beginCapture(.holdHotKey)
    }

    @objc private func captureAction(_ sender: NSButton) {
        let actions = GameAction.allCases
        guard actions.indices.contains(sender.tag) else { return }
        beginCapture(.action(actions[sender.tag]))
    }

    @objc private func resetPressed() {
        settings = .defaultState(highScore: settings.highScore)
        captureTarget = nil
        onChange(settings)
        statusLabel.stringValue = "Settings reset."
    }

    @objc private func resetSavedGamePressed() {
        captureTarget = nil
        onResetSavedGame()
        statusLabel.stringValue = "Saved game reset. Stats and high score kept."
        refresh()
    }

    private func beginCapture(_ target: CaptureTarget) {
        captureTarget = target
        statusLabel.stringValue = "Press a key. Esc cancels."
        window?.makeFirstResponder(self)
        refresh()
    }

    private func header(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .monospacedSystemFont(ofSize: 13, weight: .bold)
        field.textColor = NSColor(calibratedRed: 0.55, green: 1, blue: 0.68, alpha: 1)
        return field
    }

    private func settingLabel(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .monospacedSystemFont(ofSize: 10.5, weight: .medium)
        field.textColor = NSColor(calibratedRed: 0.32, green: 1, blue: 0.5, alpha: 0.92)
        field.maximumNumberOfLines = 1
        field.lineBreakMode = .byTruncatingTail
        return field
    }

    private func subtitleLabel(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .monospacedSystemFont(ofSize: 9.5, weight: .regular)
        field.textColor = NSColor(calibratedRed: 0.48, green: 1, blue: 0.62, alpha: 0.82)
        field.maximumNumberOfLines = 2
        field.lineBreakMode = .byWordWrapping
        field.widthAnchor.constraint(equalToConstant: 168).isActive = true
        return field
    }
}

extension SettingsView.CaptureTarget: Equatable {
    static func == (lhs: SettingsView.CaptureTarget, rhs: SettingsView.CaptureTarget) -> Bool {
        switch (lhs, rhs) {
        case (.hotKey, .hotKey):
            true
        case (.holdHotKey, .holdHotKey):
            true
        case (.action(let left), .action(let right)):
            left == right
        default:
            false
        }
    }
}
