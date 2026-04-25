import Foundation
import MatrixTetrisCore

public enum CoreLogicTests {
    public static func runAll() throws {
        try testMoveBounds()
        try testGhostPieceFallsToLandingPoint()
        try testHardDropLocksPieceAndScores()
        try testLineClearScoring()
        try testPauseAndResume()
        try testShortcutDefaults()
        try testGameplayBindingsDropFunctionModifier()
        try testOldDefaultShortcutsMigrate()
        try testSettingsNormalizeNewSliders()
        try testSettingsPersistence()
    }

    private static func testMoveBounds() throws {
        let engine = GameEngine(seed: 1, autoStart: false)
        engine.setActivePiece(ActivePiece(kind: .i, origin: GridPoint(x: -1, y: 0)))

        try expect(engine.moveLeft() == false, "piece outside left wall should not move farther left")

        engine.setActivePiece(ActivePiece(kind: .i, origin: GridPoint(x: 0, y: 0)))
        try expect(engine.moveLeft() == false, "piece at left wall should not move left")
        try expect(engine.moveRight() == true, "piece at left wall should move right")
    }

    private static func testGhostPieceFallsToLandingPoint() throws {
        let engine = GameEngine(seed: 2, autoStart: false)
        let piece = ActivePiece(kind: .o, origin: GridPoint(x: 3, y: 0))
        engine.setActivePiece(piece)

        guard let ghost = engine.ghostPiece() else {
            throw TestFailure("ghost piece should exist while active piece exists")
        }

        try expect(ghost.origin.y > piece.origin.y, "ghost should be below the active piece")

        var belowGhost = ghost
        belowGhost.origin.y += 1
        try expect(engine.isValidPosition(ghost), "ghost landing position should be valid")
        try expect(!engine.isValidPosition(belowGhost), "one row below ghost should collide")
    }

    private static func testHardDropLocksPieceAndScores() throws {
        let engine = GameEngine(seed: 3, autoStart: false)
        engine.setActivePiece(ActivePiece(kind: .o, origin: GridPoint(x: 3, y: 0)))
        engine.hardDrop()

        let occupiedCount = engine.board.flatMap { $0 }.compactMap { $0 }.count
        try expect(occupiedCount == 4, "hard drop should lock four cells")
        try expect(engine.score > 0, "hard drop should award drop score")
        try expect(engine.status == .running, "hard drop should spawn the next piece")
    }

    private static func testLineClearScoring() throws {
        let engine = GameEngine(seed: 4, autoStart: false)
        for x in 0..<engine.width where x != 4 && x != 5 {
            engine.setCell(x: x, y: engine.height - 1, kind: .i)
        }
        engine.setActivePiece(ActivePiece(kind: .o, origin: GridPoint(x: 3, y: engine.height - 2)))

        engine.hardDrop()

        try expect(engine.linesCleared == 1, "locking piece should clear one completed line")
        try expect(engine.score == 40, "single line clear at level 1 should score 40")
        try expect(engine.level == 1, "level should remain 1 before ten cleared lines")
    }

    private static func testPauseAndResume() throws {
        let engine = GameEngine(seed: 5)

        engine.pause()
        try expect(engine.status == .paused, "pause should stop a running game")
        try expect(engine.tick() == false, "paused game should not tick")

        engine.resume()
        try expect(engine.status == .running, "resume should restart a paused game")
    }

    private static func testShortcutDefaults() throws {
        let defaults = SettingsState.defaultState()

        try expect(defaults.hotKey == Shortcut(keyCode: MacKeyCode.grave, modifiers: [.option, .shift]), "toggle shortcut should default to Opt+Shift+~")
        try expect(defaults.holdHotKey == Shortcut(keyCode: MacKeyCode.grave, modifiers: [.option]), "hold shortcut should default to Opt+~")
        try expect(defaults.softDropSpeed == 7, "soft drop speed should default to 7")
        try expect(defaults.animationMode == .subtle, "animations should default to subtle")
        try expect(ShortcutModifier.function.display == "Fn", "function modifier should display as Fn")
    }

    private static func testGameplayBindingsDropFunctionModifier() throws {
        var settings = SettingsState.defaultState()
        settings.keyBindings[.moveLeft] = Shortcut(keyCode: MacKeyCode.leftArrow, modifiers: [.function])

        let normalized = settings.normalized()
        try expect(normalized.keyBindings[.moveLeft] == Shortcut(keyCode: MacKeyCode.leftArrow), "gameplay controls should ignore function modifier")
    }

    private static func testOldDefaultShortcutsMigrate() throws {
        var settings = SettingsState.defaultState()
        settings.hotKey = Shortcut(keyCode: MacKeyCode.t, modifiers: [.control, .option])
        settings.holdHotKey = Shortcut(keyCode: MacKeyCode.grave, modifiers: [.function])

        let normalized = settings.normalized()
        try expect(normalized.hotKey == Shortcut(keyCode: MacKeyCode.grave, modifiers: [.option, .shift]), "old Ctrl+Opt+T toggle should migrate to Opt+Shift+~")
        try expect(normalized.holdHotKey == Shortcut(keyCode: MacKeyCode.grave, modifiers: [.option]), "old hold shortcut should migrate to Opt+~")
    }

    private static func testSettingsNormalizeNewSliders() throws {
        var settings = SettingsState.defaultState()
        settings.inputSensitivity = 40
        settings.softDropSpeed = -2

        let normalized = settings.normalized()
        try expect(normalized.inputSensitivity == 10, "movement sensitivity should clamp to 10")
        try expect(normalized.softDropSpeed == 1, "soft drop speed should clamp to 1")
    }

    private static func testSettingsPersistence() throws {
        let suiteName = "MatrixTetrisTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw TestFailure("could not create test defaults")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = SettingsStore(defaults: defaults)
        var settings = SettingsState.defaultState()
        settings.highScore = 12_345
        settings.dropdownPosition = .leftSide
        settings.inputSensitivity = 9
        settings.softDropSpeed = 8
        settings.animationMode = .off
        settings.hotKey = Shortcut(keyCode: MacKeyCode.t, modifiers: [.command, .shift])
        settings.holdHotKey = Shortcut(keyCode: MacKeyCode.grave, modifiers: [.control, .option])
        settings.keyBindings[.hardDrop] = Shortcut(keyCode: MacKeyCode.d, modifiers: [.option])
        store.save(settings)

        let reloaded = store.load()
        try expect(reloaded.highScore == 12_345, "high score should persist")
        try expect(reloaded.dropdownPosition == .leftSide, "dropdown position should persist")
        try expect(reloaded.inputSensitivity == 9, "input sensitivity should persist")
        try expect(reloaded.softDropSpeed == 8, "soft drop speed should persist")
        try expect(reloaded.animationMode == .off, "animation mode should persist")
        try expect(reloaded.hotKey == settings.hotKey, "hotkey should persist")
        try expect(reloaded.holdHotKey == Shortcut(keyCode: MacKeyCode.grave, modifiers: [.option]), "old default hold hotkey should migrate on reload")
        try expect(reloaded.keyBindings[.hardDrop] == settings.keyBindings[.hardDrop], "control binding should persist")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() {
            throw TestFailure(message)
        }
    }
}

public struct TestFailure: Error, CustomStringConvertible {
    public let description: String

    public init(_ description: String) {
        self.description = description
    }
}
