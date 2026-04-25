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
    private let animationPopup = NSPopUpButton()
    private lazy var hotKeyButton = MatrixButton(target: self, action: #selector(captureHotKey))
    private lazy var holdHotKeyButton = MatrixButton(target: self, action: #selector(captureHoldHotKey))
    private var actionButtons: [GameAction: NSButton] = [:]
    private var captureTarget: CaptureTarget?

    init(settings: SettingsState, onChange: @escaping (SettingsState) -> Void) {
        self.settings = settings
        self.onChange = onChange
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

    func capture(event: NSEvent) {
        guard let captureTarget else { return }
        if event.keyCode == 53 {
            self.captureTarget = nil
            statusLabel.stringValue = "Capture cancelled."
            refresh()
            return
        }

        let savedShortcut: Shortcut
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
        case .action(let action):
            let shortcut = Shortcut(event: event, includeFunctionModifier: false)
            settings.keyBindings[action] = shortcut
            savedShortcut = shortcut
        }

        self.captureTarget = nil
        onChange(settings)
        statusLabel.stringValue = "Saved \(savedShortcut.displayName)."
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

        stack.addArrangedSubview(settingLabel("Animations"))
        animationPopup.removeAllItems()
        AnimationMode.allCases.forEach { animationPopup.addItem(withTitle: $0.label) }
        animationPopup.target = self
        animationPopup.action = #selector(animationChanged)
        stack.addArrangedSubview(animationPopup)

        stack.addArrangedSubview(settingLabel("Toggle Hotkey"))
        stack.addArrangedSubview(hotKeyButton)

        stack.addArrangedSubview(settingLabel("Hold Key"))
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
        action: Selector
    ) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        slider.target = self
        slider.action = action
        slider.numberOfTickMarks = 10
        slider.allowsTickMarkValuesOnly = true
        slider.widthAnchor.constraint(equalToConstant: 128).isActive = true
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        valueLabel.textColor = NSColor(calibratedRed: 0.54, green: 1, blue: 0.65, alpha: 1)
        valueLabel.widthAnchor.constraint(equalToConstant: 24).isActive = true
        row.addArrangedSubview(slider)
        row.addArrangedSubview(valueLabel)
        return row
    }

    private func refresh() {
        if let index = DropdownPosition.allCases.firstIndex(of: settings.dropdownPosition) {
            positionPopup.selectItem(at: index)
        }
        sensitivitySlider.integerValue = settings.inputSensitivity
        sensitivityValueLabel.stringValue = "\(settings.inputSensitivity)"
        softDropSlider.integerValue = settings.softDropSpeed
        softDropValueLabel.stringValue = "\(settings.softDropSpeed)"
        if let animationIndex = AnimationMode.allCases.firstIndex(of: settings.animationMode) {
            animationPopup.selectItem(at: animationIndex)
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

    @objc private func animationChanged() {
        let index = animationPopup.indexOfSelectedItem
        guard AnimationMode.allCases.indices.contains(index) else { return }
        settings.animationMode = AnimationMode.allCases[index]
        onChange(settings)
        statusLabel.stringValue = "Animation setting saved."
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
