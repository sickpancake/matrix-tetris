import Foundation

public enum AppInfo {
    public static let version = "1.2.0"
    public static let build = "120"
    public static let displayVersion = "Matrix Tetris v\(version)"
    public static let latestReleaseURL = URL(string: "https://github.com/sickpancake/matrix-tetris/releases/latest")!

    public static let v120Changelog = [
        "Added original Matrix Minimal and Arcade Punchy sound themes.",
        "Added sound settings for mute, master volume, theme, and test playback.",
        "Added gameplay and UI sound cues for movement, drops, line clears, game over, buttons, and dropdown open/close.",
        "Pieces now spawn above the visible grid and fall into play through a Matrix-styled spawn lane.",
        "Updated app packaging and release metadata for v1.2.0."
    ]

    public static let v110Changelog = [
        "Clicking outside the dropdown now auto-hides it without breaking shortcuts.",
        "Added soft-drop trails, landing feedback, and smoother Matrix movement pulses.",
        "Speed Scaling is now optional and defaults off for steadier falling speed.",
        "Added per-animation intensity sliders, ghost opacity, reset saved game, duplicate-control warnings, and clearer settings.",
        "Refreshed About, install/update text, and app packaging for v1.1.0."
    ]

    public static let v100Changelog = [
        "Saved games now resume automatically.",
        "Added first-run setup, About, version display, and in-app changelog.",
        "Added local stats for games, best lines, total lines, clears, play time, and last played.",
        "Improved game-over and restart flow with Matrix-styled result controls.",
        "Updated install and update flow around GitHub Releases."
    ]
}

public struct SettingsState: Codable, Equatable, Sendable {
    public var highScore: Int
    public var hotKey: Shortcut
    public var holdHotKey: Shortcut
    public var dropdownPosition: DropdownPosition
    public var inputSensitivity: Int
    public var softDropSpeed: Int
    public var speedScalingEnabled: Bool
    public var ghostOpacity: Int
    public var animationMode: AnimationMode
    public var animationIntensities: AnimationIntensityState
    public var soundEnabled: Bool
    public var soundVolume: Int
    public var soundTheme: SoundTheme
    public var keyBindings: [GameAction: Shortcut]

    public init(
        highScore: Int,
        hotKey: Shortcut,
        holdHotKey: Shortcut,
        dropdownPosition: DropdownPosition,
        inputSensitivity: Int = 5,
        softDropSpeed: Int = 7,
        speedScalingEnabled: Bool = false,
        ghostOpacity: Int = 4,
        animationMode: AnimationMode = .subtle,
        animationIntensities: AnimationIntensityState = .defaultState(),
        soundEnabled: Bool = true,
        soundVolume: Int = 6,
        soundTheme: SoundTheme = .matrixMinimal,
        keyBindings: [GameAction: Shortcut]
    ) {
        self.highScore = highScore
        self.hotKey = hotKey
        self.holdHotKey = holdHotKey
        self.dropdownPosition = dropdownPosition
        self.inputSensitivity = inputSensitivity
        self.softDropSpeed = softDropSpeed
        self.speedScalingEnabled = speedScalingEnabled
        self.ghostOpacity = ghostOpacity
        self.animationMode = animationMode
        self.animationIntensities = animationIntensities
        self.soundEnabled = soundEnabled
        self.soundVolume = soundVolume
        self.soundTheme = soundTheme
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
            speedScalingEnabled: false,
            ghostOpacity: 4,
            animationMode: .subtle,
            animationIntensities: .defaultState(),
            soundEnabled: true,
            soundVolume: 6,
            soundTheme: .matrixMinimal,
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
        copy.ghostOpacity = min(max(copy.ghostOpacity, 1), 10)
        copy.animationIntensities = copy.animationIntensities.normalized()
        copy.soundVolume = min(max(copy.soundVolume, 0), 10)
        return copy
    }

    private enum CodingKeys: String, CodingKey {
        case highScore
        case hotKey
        case holdHotKey
        case dropdownPosition
        case inputSensitivity
        case softDropSpeed
        case speedScalingEnabled
        case ghostOpacity
        case animationMode
        case animationIntensities
        case soundEnabled
        case soundVolume
        case soundTheme
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
        speedScalingEnabled = try container.decodeIfPresent(Bool.self, forKey: .speedScalingEnabled) ?? defaults.speedScalingEnabled
        ghostOpacity = try container.decodeIfPresent(Int.self, forKey: .ghostOpacity) ?? defaults.ghostOpacity
        animationMode = try container.decodeIfPresent(AnimationMode.self, forKey: .animationMode) ?? defaults.animationMode
        animationIntensities = try container.decodeIfPresent(AnimationIntensityState.self, forKey: .animationIntensities) ?? defaults.animationIntensities
        soundEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? defaults.soundEnabled
        soundVolume = try container.decodeIfPresent(Int.self, forKey: .soundVolume) ?? defaults.soundVolume
        soundTheme = try container.decodeIfPresent(SoundTheme.self, forKey: .soundTheme) ?? defaults.soundTheme
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
        try container.encode(speedScalingEnabled, forKey: .speedScalingEnabled)
        try container.encode(ghostOpacity, forKey: .ghostOpacity)
        try container.encode(animationMode, forKey: .animationMode)
        try container.encode(animationIntensities, forKey: .animationIntensities)
        try container.encode(soundEnabled, forKey: .soundEnabled)
        try container.encode(soundVolume, forKey: .soundVolume)
        try container.encode(soundTheme, forKey: .soundTheme)
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
        defaults.synchronize()
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

public struct AnimationIntensityState: Codable, Equatable, Sendable {
    public var lineClear: Int
    public var hardDrop: Int
    public var softDrop: Int
    public var spawn: Int
    public var move: Int
    public var landing: Int

    public init(
        lineClear: Int = 6,
        hardDrop: Int = 5,
        softDrop: Int = 4,
        spawn: Int = 5,
        move: Int = 4,
        landing: Int = 5
    ) {
        self.lineClear = lineClear
        self.hardDrop = hardDrop
        self.softDrop = softDrop
        self.spawn = spawn
        self.move = move
        self.landing = landing
    }

    public static func defaultState() -> AnimationIntensityState {
        AnimationIntensityState()
    }

    private enum CodingKeys: String, CodingKey {
        case lineClear
        case hardDrop
        case softDrop
        case spawn
        case move
        case landing
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AnimationIntensityState.defaultState()
        lineClear = try container.decodeIfPresent(Int.self, forKey: .lineClear) ?? defaults.lineClear
        hardDrop = try container.decodeIfPresent(Int.self, forKey: .hardDrop) ?? defaults.hardDrop
        softDrop = try container.decodeIfPresent(Int.self, forKey: .softDrop) ?? defaults.softDrop
        spawn = try container.decodeIfPresent(Int.self, forKey: .spawn) ?? defaults.spawn
        move = try container.decodeIfPresent(Int.self, forKey: .move) ?? defaults.move
        landing = try container.decodeIfPresent(Int.self, forKey: .landing) ?? defaults.landing
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lineClear, forKey: .lineClear)
        try container.encode(hardDrop, forKey: .hardDrop)
        try container.encode(softDrop, forKey: .softDrop)
        try container.encode(spawn, forKey: .spawn)
        try container.encode(move, forKey: .move)
        try container.encode(landing, forKey: .landing)
    }

    public func normalized() -> AnimationIntensityState {
        AnimationIntensityState(
            lineClear: Self.clamped(lineClear),
            hardDrop: Self.clamped(hardDrop),
            softDrop: Self.clamped(softDrop),
            spawn: Self.clamped(spawn),
            move: Self.clamped(move),
            landing: Self.clamped(landing)
        )
    }

    public func value(for effect: AnimationEffect) -> Int {
        switch effect {
        case .lineClear:
            lineClear
        case .hardDrop:
            hardDrop
        case .softDrop:
            softDrop
        case .spawn:
            spawn
        case .move:
            move
        case .landing:
            landing
        }
    }

    public mutating func setValue(_ value: Int, for effect: AnimationEffect) {
        let clamped = Self.clamped(value)
        switch effect {
        case .lineClear:
            lineClear = clamped
        case .hardDrop:
            hardDrop = clamped
        case .softDrop:
            softDrop = clamped
        case .spawn:
            spawn = clamped
        case .move:
            move = clamped
        case .landing:
            landing = clamped
        }
    }

    private static func clamped(_ value: Int) -> Int {
        min(max(value, 0), 10)
    }
}

public struct StatsState: Codable, Equatable, Sendable {
    public var gamesPlayed: Int
    public var bestScore: Int
    public var bestLines: Int
    public var totalLines: Int
    public var totalLineClears: Int
    public var totalPlayTime: TimeInterval
    public var lastPlayed: Date?

    public init(
        gamesPlayed: Int = 0,
        bestScore: Int = 0,
        bestLines: Int = 0,
        totalLines: Int = 0,
        totalLineClears: Int = 0,
        totalPlayTime: TimeInterval = 0,
        lastPlayed: Date? = nil
    ) {
        self.gamesPlayed = gamesPlayed
        self.bestScore = bestScore
        self.bestLines = bestLines
        self.totalLines = totalLines
        self.totalLineClears = totalLineClears
        self.totalPlayTime = totalPlayTime
        self.lastPlayed = lastPlayed
    }

    public static func defaultState() -> StatsState {
        StatsState()
    }

    public func normalized() -> StatsState {
        StatsState(
            gamesPlayed: max(0, gamesPlayed),
            bestScore: max(0, bestScore),
            bestLines: max(0, bestLines),
            totalLines: max(0, totalLines),
            totalLineClears: max(0, totalLineClears),
            totalPlayTime: max(0, totalPlayTime),
            lastPlayed: lastPlayed
        )
    }

    public mutating func recordGame(
        score: Int,
        lines: Int,
        lineClearEvents: Int,
        duration: TimeInterval,
        endedAt: Date = Date()
    ) {
        gamesPlayed += 1
        bestScore = max(bestScore, score)
        bestLines = max(bestLines, lines)
        totalLines += max(0, lines)
        totalLineClears += max(0, lineClearEvents)
        totalPlayTime += max(0, duration)
        lastPlayed = endedAt
    }
}

public final class StatsStore {
    private let defaults: UserDefaults
    private let key = "matrix-tetris-stats-v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> StatsState {
        guard let data = defaults.data(forKey: key) else {
            return .defaultState()
        }
        do {
            return try JSONDecoder().decode(StatsState.self, from: data).normalized()
        } catch {
            return .defaultState()
        }
    }

    public func save(_ state: StatsState) {
        guard let data = try? JSONEncoder().encode(state.normalized()) else { return }
        defaults.set(data, forKey: key)
        defaults.synchronize()
    }

    public func recordGame(
        score: Int,
        lines: Int,
        lineClearEvents: Int,
        duration: TimeInterval,
        endedAt: Date = Date()
    ) -> StatsState {
        var state = load()
        state.recordGame(
            score: score,
            lines: lines,
            lineClearEvents: lineClearEvents,
            duration: duration,
            endedAt: endedAt
        )
        save(state)
        return state
    }
}

public final class SavedGameStore {
    private let defaults: UserDefaults
    private let key = "matrix-tetris-saved-game-v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> GameSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        guard let snapshot = try? JSONDecoder().decode(GameSnapshot.self, from: data) else {
            clear()
            return nil
        }
        guard snapshot.isRestorableSession else {
            clear()
            return nil
        }
        return snapshot
    }

    public func save(_ snapshot: GameSnapshot) {
        guard snapshot.isRestorableSession else {
            clear()
            return
        }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
        defaults.synchronize()
    }

    public func clear() {
        defaults.removeObject(forKey: key)
        defaults.synchronize()
    }
}

public struct AppMetaState: Codable, Equatable, Sendable {
    public var firstRunCompleted: Bool
    public var lastChangelogVersionShown: String?

    public init(
        firstRunCompleted: Bool = false,
        lastChangelogVersionShown: String? = nil
    ) {
        self.firstRunCompleted = firstRunCompleted
        self.lastChangelogVersionShown = lastChangelogVersionShown
    }

    public static func defaultState() -> AppMetaState {
        AppMetaState()
    }
}

public final class AppMetaStore {
    private let defaults: UserDefaults
    private let key = "matrix-tetris-app-meta-v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> AppMetaState {
        guard let data = defaults.data(forKey: key) else {
            return .defaultState()
        }
        return (try? JSONDecoder().decode(AppMetaState.self, from: data)) ?? .defaultState()
    }

    public func save(_ state: AppMetaState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: key)
        defaults.synchronize()
    }

    public func completeFirstRun() -> AppMetaState {
        var state = load()
        state.firstRunCompleted = true
        save(state)
        return state
    }

    public func markChangelogShown(version: String = AppInfo.version) -> AppMetaState {
        var state = load()
        state.lastChangelogVersionShown = version
        save(state)
        return state
    }
}
