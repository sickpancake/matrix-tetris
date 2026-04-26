import Foundation
import MatrixTetrisCore

public enum CoreLogicTests {
    public static func runAll() throws {
        try testMoveBounds()
        try testNewPiecesSpawnAboveVisibleGrid()
        try testSpawnedPiecesFallIntoVisibleGrid()
        try testGhostPieceFallsToLandingPoint()
        try testHardDropLocksPieceAndScores()
        try testLineClearScoring()
        try testPauseAndResume()
        try testSnapshotRestorePreservesGameState()
        try testSnapshotRestorePreservesGameOverStatus()
        try testShortcutDefaults()
        try testGameplayBindingsDropFunctionModifier()
        try testOldDefaultShortcutsMigrate()
        try testSettingsNormalizeNewSliders()
        try testSettingsDecodeV120Defaults()
        try testSettingsPersistence()
        try testSavedGamePersistenceClearsGameOver()
        try testStatsPersistenceAndRecording()
        try testAppMetaPersistence()
    }

    private static func testMoveBounds() throws {
        let engine = GameEngine(seed: 1, autoStart: false)
        engine.setActivePiece(ActivePiece(kind: .i, origin: GridPoint(x: -1, y: 0)))

        try expect(engine.moveLeft() == false, "piece outside left wall should not move farther left")

        engine.setActivePiece(ActivePiece(kind: .i, origin: GridPoint(x: 0, y: 0)))
        try expect(engine.moveLeft() == false, "piece at left wall should not move left")
        try expect(engine.moveRight() == true, "piece at left wall should move right")
    }

    private static func testNewPiecesSpawnAboveVisibleGrid() throws {
        let engine = GameEngine(seed: 11)

        guard let piece = engine.activePiece else {
            throw TestFailure("new game should spawn an active piece")
        }

        try expect(piece.blocks.allSatisfy { $0.y < 0 }, "new pieces should spawn above the visible grid")
        try expect(piece.blocks.contains { $0.y == -1 }, "new pieces should occupy the hidden spawn lane")
    }

    private static func testSpawnedPiecesFallIntoVisibleGrid() throws {
        let engine = GameEngine(seed: 12)
        let startingOrigin = engine.activePiece?.origin

        _ = engine.tick()

        guard let piece = engine.activePiece, let startingOrigin else {
            throw TestFailure("active piece should still exist after first gravity tick")
        }
        try expect(piece.origin.y == startingOrigin.y + 1, "first gravity tick should move the spawned piece down")
        try expect(piece.blocks.contains { $0.y >= 0 }, "spawned piece should enter the visible grid after falling")
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

    private static func testSnapshotRestorePreservesGameState() throws {
        let engine = GameEngine(seed: 6)
        _ = engine.moveRight()
        engine.hardDrop()
        engine.pause()

        let snapshot = engine.snapshot()
        let restored = GameEngine(seed: 99, autoStart: false)

        try expect(restored.restore(from: snapshot), "valid snapshot should restore")
        try expect(restored.board == snapshot.board, "board should restore")
        try expect(restored.activePiece == snapshot.activePiece, "active piece should restore")
        try expect(restored.nextQueue == snapshot.nextQueue, "next queue should restore")
        try expect(restored.score == snapshot.score, "score should restore")
        try expect(restored.level == snapshot.level, "level should restore")
        try expect(restored.linesCleared == snapshot.linesCleared, "lines should restore")
        try expect(restored.status == .paused, "paused status should restore")
    }

    private static func testSnapshotRestorePreservesGameOverStatus() throws {
        let board = Array(repeating: Array(repeating: Optional<TetrominoKind>.none, count: 10), count: 20)
        let snapshot = GameSnapshot(
            width: 10,
            height: 20,
            board: board,
            activePiece: nil,
            nextQueue: [.i, .o, .t],
            bag: [.s, .z, .j, .l],
            score: 50,
            level: 2,
            linesCleared: 10,
            lineClearEvents: 3,
            status: .gameOver,
            spawnSerial: 4,
            lockTicks: 1,
            rngState: 123,
            startedAt: Date(timeIntervalSince1970: 1_000)
        )
        let restored = GameEngine(autoStart: false)

        try expect(restored.restore(from: snapshot), "game over snapshot should restore")
        try expect(restored.status == .gameOver, "game over status should restore")
        try expect(restored.score == 50, "game over score should restore")
        try expect(restored.linesCleared == 10, "game over lines should restore")
    }

    private static func testShortcutDefaults() throws {
        let defaults = SettingsState.defaultState()

        try expect(defaults.hotKey == Shortcut(keyCode: MacKeyCode.grave, modifiers: [.option, .shift]), "toggle shortcut should default to Opt+Shift+~")
        try expect(defaults.holdHotKey == Shortcut(keyCode: MacKeyCode.grave, modifiers: [.option]), "hold shortcut should default to Opt+~")
        try expect(defaults.softDropSpeed == 7, "soft drop speed should default to 7")
        try expect(defaults.speedScalingEnabled == false, "speed scaling should default off")
        try expect(defaults.ghostOpacity == 4, "ghost opacity should default to 4")
        try expect(defaults.animationMode == .subtle, "animations should default to subtle")
        try expect(defaults.animationIntensities.softDrop == 4, "soft drop animation should default to a restrained intensity")
        try expect(defaults.animationIntensities.lineClear == 6, "line clear animation should have a visible default")
        try expect(defaults.soundEnabled == true, "sound should default on")
        try expect(defaults.soundVolume == 6, "sound volume should default to 6")
        try expect(defaults.soundTheme == .matrixMinimal, "sound theme should default to Matrix Minimal")
        try expect(SoundTheme.arcadePunchy.label == "Arcade Punchy", "arcade sound theme should format cleanly")
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
        settings.ghostOpacity = 50
        settings.soundVolume = 50
        settings.animationIntensities = AnimationIntensityState(lineClear: -2, hardDrop: 11, softDrop: 50, spawn: 5, move: -8, landing: 3)

        let normalized = settings.normalized()
        try expect(normalized.inputSensitivity == 10, "movement sensitivity should clamp to 10")
        try expect(normalized.softDropSpeed == 1, "soft drop speed should clamp to 1")
        try expect(normalized.ghostOpacity == 10, "ghost opacity should clamp to 10")
        try expect(normalized.soundVolume == 10, "sound volume should clamp to 10")
        try expect(normalized.animationIntensities.lineClear == 0, "animation intensities should clamp to 0")
        try expect(normalized.animationIntensities.hardDrop == 10, "animation intensities should clamp to 10")
        try expect(normalized.animationIntensities.softDrop == 10, "soft drop animation intensity should clamp to 10")
    }

    private static func testSettingsDecodeV120Defaults() throws {
        let data = try JSONEncoder().encode(SettingsState.defaultState())
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TestFailure("settings should encode as a JSON object")
        }
        object.removeValue(forKey: "speedScalingEnabled")
        object.removeValue(forKey: "ghostOpacity")
        object.removeValue(forKey: "animationIntensities")
        object.removeValue(forKey: "soundEnabled")
        object.removeValue(forKey: "soundVolume")
        object.removeValue(forKey: "soundTheme")

        let oldData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(SettingsState.self, from: oldData).normalized()

        try expect(decoded.speedScalingEnabled == false, "missing speed scaling should default off")
        try expect(decoded.ghostOpacity == 4, "missing ghost opacity should use the v1.1 default")
        try expect(decoded.animationIntensities == .defaultState(), "missing animation intensities should use defaults")
        try expect(decoded.soundEnabled == true, "missing sound enabled should default on")
        try expect(decoded.soundVolume == 6, "missing sound volume should use the v1.2 default")
        try expect(decoded.soundTheme == .matrixMinimal, "missing sound theme should use the v1.2 default")
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
        settings.speedScalingEnabled = true
        settings.ghostOpacity = 6
        settings.animationMode = .off
        settings.animationIntensities = AnimationIntensityState(lineClear: 2, hardDrop: 3, softDrop: 4, spawn: 5, move: 6, landing: 7)
        settings.soundEnabled = false
        settings.soundVolume = 3
        settings.soundTheme = .arcadePunchy
        settings.hotKey = Shortcut(keyCode: MacKeyCode.t, modifiers: [.command, .shift])
        settings.holdHotKey = Shortcut(keyCode: MacKeyCode.grave, modifiers: [.control, .option])
        settings.keyBindings[.hardDrop] = Shortcut(keyCode: MacKeyCode.d, modifiers: [.option])
        store.save(settings)

        let reloaded = store.load()
        try expect(reloaded.highScore == 12_345, "high score should persist")
        try expect(reloaded.dropdownPosition == .leftSide, "dropdown position should persist")
        try expect(reloaded.inputSensitivity == 9, "input sensitivity should persist")
        try expect(reloaded.softDropSpeed == 8, "soft drop speed should persist")
        try expect(reloaded.speedScalingEnabled, "speed scaling should persist")
        try expect(reloaded.ghostOpacity == 6, "ghost opacity should persist")
        try expect(reloaded.animationMode == .off, "animation mode should persist")
        try expect(reloaded.animationIntensities == settings.animationIntensities, "animation intensities should persist")
        try expect(reloaded.soundEnabled == false, "sound enabled should persist")
        try expect(reloaded.soundVolume == 3, "sound volume should persist")
        try expect(reloaded.soundTheme == .arcadePunchy, "sound theme should persist")
        try expect(reloaded.hotKey == settings.hotKey, "hotkey should persist")
        try expect(reloaded.holdHotKey == Shortcut(keyCode: MacKeyCode.grave, modifiers: [.option]), "old default hold hotkey should migrate on reload")
        try expect(reloaded.keyBindings[.hardDrop] == settings.keyBindings[.hardDrop], "control binding should persist")
    }

    private static func testSavedGamePersistenceClearsGameOver() throws {
        let suiteName = "MatrixTetrisTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw TestFailure("could not create test defaults")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = SavedGameStore(defaults: defaults)
        let engine = GameEngine(seed: 7)
        store.save(engine.snapshot())
        try expect(store.load() != nil, "running game should persist")

        var snapshot = engine.snapshot()
        snapshot.status = .gameOver
        store.save(snapshot)
        try expect(store.load() == nil, "game over session should clear instead of restore")
    }

    private static func testStatsPersistenceAndRecording() throws {
        let suiteName = "MatrixTetrisTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw TestFailure("could not create test defaults")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = StatsStore(defaults: defaults)
        let endedAt = Date(timeIntervalSince1970: 2_000)
        _ = store.recordGame(score: 900, lines: 12, lineClearEvents: 5, duration: 75, endedAt: endedAt)
        let stats = store.recordGame(score: 400, lines: 4, lineClearEvents: 2, duration: 25, endedAt: endedAt)

        try expect(stats.gamesPlayed == 2, "games played should increment")
        try expect(stats.bestScore == 900, "best score should persist")
        try expect(stats.bestLines == 12, "best lines should persist")
        try expect(stats.totalLines == 16, "total lines should accumulate")
        try expect(stats.totalLineClears == 7, "line clear events should accumulate")
        try expect(stats.totalPlayTime == 100, "play time should accumulate")
        try expect(stats.lastPlayed == endedAt, "last played should update")
    }

    private static func testAppMetaPersistence() throws {
        let suiteName = "MatrixTetrisTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw TestFailure("could not create test defaults")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = AppMetaStore(defaults: defaults)
        var meta = store.completeFirstRun()
        try expect(meta.firstRunCompleted, "first run flag should persist")

        meta = store.markChangelogShown(version: AppInfo.version)
        try expect(meta.lastChangelogVersionShown == AppInfo.version, "changelog version should persist")
        try expect(store.load() == meta, "app meta should reload")
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
