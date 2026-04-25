import Foundation

public struct SettingsState: Codable, Equatable, Sendable {
    public var highScore: Int
    public var hotKey: Shortcut
    public var holdHotKey: Shortcut
    public var dropdownPosition: DropdownPosition
    public var inputSensitivity: Int
    public var softDropSpeed: Int
    public var animationMode: AnimationMode
    public var keyBindings: [GameAction: Shortcut]

    public init(
        highScore: Int,
        hotKey: Shortcut,
        holdHotKey: Shortcut,
        dropdownPosition: DropdownPosition,
        inputSensitivity: Int = 5,
        softDropSpeed: Int = 7,
        animationMode: AnimationMode = .subtle,
        keyBindings: [GameAction: Shortcut]
    ) {
        self.highScore = highScore
        self.hotKey = hotKey
        self.holdHotKey = holdHotKey
        self.dropdownPosition = dropdownPosition
        self.inputSensitivity = inputSensitivity
        self.softDropSpeed = softDropSpeed
        self.animationMode = animationMode
        self.keyBindings = keyBindings
    }

    public static func defaultState(highScore: Int = 0) -> SettingsState {
        SettingsState(
            highScore: highScore,
            hotKey: Shortcut(keyCode: MacKeyCode.grave, modifiers: [.option, .shift]),
            holdHotKey: Shortcut(keyCode: MacKeyCode.grave, modifiers: [.option]),
            dropdownPosition: .rightSide,
            inputSensitivity: 5,
            softDropSpeed: 7,
            animationMode: .subtle,
            keyBindings: defaultKeyBindings
        )
    }

    public func normalized() -> SettingsState {
        var copy = self
        let defaults = Self.defaultState(highScore: copy.highScore)
        if Self.oldToggleDefaults.contains(copy.hotKey) {
            copy.hotKey = defaults.hotKey
        }
        if Self.oldHoldDefaults.contains(copy.holdHotKey) {
            copy.holdHotKey = defaults.holdHotKey
        }
        for (action, shortcut) in Self.defaultKeyBindings where copy.keyBindings[action] == nil {
            copy.keyBindings[action] = shortcut
        }
        for action in GameAction.allCases {
            guard var shortcut = copy.keyBindings[action] else { continue }
            shortcut.modifiers.remove(.function)
            copy.keyBindings[action] = shortcut
        }
        copy.inputSensitivity = min(max(copy.inputSensitivity, 1), 10)
        copy.softDropSpeed = min(max(copy.softDropSpeed, 1), 10)
        return copy
    }

    private enum CodingKeys: String, CodingKey {
        case highScore
        case hotKey
        case holdHotKey
        case dropdownPosition
        case inputSensitivity
        case softDropSpeed
        case animationMode
        case keyBindings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = SettingsState.defaultState()
        highScore = try container.decodeIfPresent(Int.self, forKey: .highScore) ?? defaults.highScore
        hotKey = try container.decodeIfPresent(Shortcut.self, forKey: .hotKey) ?? defaults.hotKey
        holdHotKey = try container.decodeIfPresent(Shortcut.self, forKey: .holdHotKey) ?? defaults.holdHotKey
        dropdownPosition = try container.decodeIfPresent(DropdownPosition.self, forKey: .dropdownPosition) ?? defaults.dropdownPosition
        inputSensitivity = try container.decodeIfPresent(Int.self, forKey: .inputSensitivity) ?? defaults.inputSensitivity
        softDropSpeed = try container.decodeIfPresent(Int.self, forKey: .softDropSpeed) ?? defaults.softDropSpeed
        animationMode = try container.decodeIfPresent(AnimationMode.self, forKey: .animationMode) ?? defaults.animationMode
        keyBindings = try container.decodeIfPresent([GameAction: Shortcut].self, forKey: .keyBindings) ?? defaults.keyBindings
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(highScore, forKey: .highScore)
        try container.encode(hotKey, forKey: .hotKey)
        try container.encode(holdHotKey, forKey: .holdHotKey)
        try container.encode(dropdownPosition, forKey: .dropdownPosition)
        try container.encode(inputSensitivity, forKey: .inputSensitivity)
        try container.encode(softDropSpeed, forKey: .softDropSpeed)
        try container.encode(animationMode, forKey: .animationMode)
        try container.encode(keyBindings, forKey: .keyBindings)
    }

    public static let defaultKeyBindings: [GameAction: Shortcut] = [
        .moveLeft: Shortcut(keyCode: MacKeyCode.leftArrow),
        .moveRight: Shortcut(keyCode: MacKeyCode.rightArrow),
        .rotateClockwise: Shortcut(keyCode: MacKeyCode.upArrow),
        .rotateCounterclockwise: Shortcut(keyCode: MacKeyCode.z),
        .softDrop: Shortcut(keyCode: MacKeyCode.downArrow),
        .hardDrop: Shortcut(keyCode: MacKeyCode.space),
        .pause: Shortcut(keyCode: MacKeyCode.p),
        .restart: Shortcut(keyCode: MacKeyCode.r)
    ]

    private static let oldToggleDefaults: Set<Shortcut> = [
        Shortcut(keyCode: MacKeyCode.t, modifiers: [.control, .option]),
        Shortcut(keyCode: MacKeyCode.grave, modifiers: [.option])
    ]

    private static let oldHoldDefaults: Set<Shortcut> = [
        Shortcut(keyCode: MacKeyCode.grave, modifiers: [.function]),
        Shortcut(keyCode: MacKeyCode.grave, modifiers: [.control, .option]),
        Shortcut(keyCode: MacKeyCode.grave, modifiers: [.option, .shift])
    ]
}

public final class SettingsStore {
    private let defaults: UserDefaults
    private let key = "matrix-tetris-settings-v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> SettingsState {
        guard let data = defaults.data(forKey: key) else {
            return .defaultState()
        }

        do {
            return try JSONDecoder().decode(SettingsState.self, from: data).normalized()
        } catch {
            return .defaultState()
        }
    }

    public func save(_ state: SettingsState) {
        guard let data = try? JSONEncoder().encode(state.normalized()) else { return }
        defaults.set(data, forKey: key)
    }

    public func updateHighScore(_ score: Int) -> SettingsState {
        var state = load()
        if score > state.highScore {
            state.highScore = score
            save(state)
        }
        return state
    }

    public func resetPreservingHighScore() -> SettingsState {
        let highScore = load().highScore
        let state = SettingsState.defaultState(highScore: highScore)
        save(state)
        return state
    }
}
