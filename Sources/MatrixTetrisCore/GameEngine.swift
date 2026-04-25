import Foundation

public final class GameEngine {
    public let width: Int
    public let height: Int
    public let lockDelayTicks: Int

    public private(set) var board: [[TetrominoKind?]]
    public private(set) var activePiece: ActivePiece?
    public private(set) var nextQueue: [TetrominoKind] = []
    public private(set) var score = 0
    public private(set) var level = 1
    public private(set) var linesCleared = 0
    public private(set) var lineClearEvents = 0
    public private(set) var status: GameStatus = .running
    public private(set) var spawnSerial = 0
    public private(set) var lastClearedRows: [Int] = []
    public private(set) var startedAt = Date()

    private var rng: SeededGenerator
    private var bag: [TetrominoKind] = []
    private var lockTicks = 0

    public init(
        width: Int = 10,
        height: Int = 20,
        seed: UInt64? = nil,
        lockDelayTicks: Int = 2,
        autoStart: Bool = true
    ) {
        self.width = width
        self.height = height
        self.lockDelayTicks = lockDelayTicks
        rng = SeededGenerator(seed: seed ?? UInt64(Date().timeIntervalSince1970 * 1_000_000))
        board = Array(repeating: Array(repeating: nil, count: width), count: height)

        if autoStart {
            reset(seed: seed)
        } else {
            status = .running
        }
    }

    public func reset(seed: UInt64? = nil) {
        if let seed {
            rng = SeededGenerator(seed: seed)
        }
        board = Array(repeating: Array(repeating: nil, count: width), count: height)
        activePiece = nil
        nextQueue = []
        bag = []
        score = 0
        level = 1
        linesCleared = 0
        lineClearEvents = 0
        lockTicks = 0
        spawnSerial = 0
        lastClearedRows = []
        startedAt = Date()
        status = .running
        refillQueueIfNeeded()
        spawnPiece()
    }

    public func startNewGame(seed: UInt64? = nil) {
        reset(seed: seed)
    }

    public func snapshot() -> GameSnapshot {
        GameSnapshot(
            width: width,
            height: height,
            board: board,
            activePiece: activePiece,
            nextQueue: nextQueue,
            bag: bag,
            score: score,
            level: level,
            linesCleared: linesCleared,
            lineClearEvents: lineClearEvents,
            status: status,
            spawnSerial: spawnSerial,
            lockTicks: lockTicks,
            rngState: rng.currentState,
            startedAt: startedAt
        )
    }

    @discardableResult
    public func restore(from snapshot: GameSnapshot) -> Bool {
        guard snapshot.width == width, snapshot.height == height else { return false }
        guard snapshot.board.count == height else { return false }
        guard snapshot.board.allSatisfy({ $0.count == width }) else { return false }

        board = snapshot.board
        activePiece = snapshot.activePiece
        nextQueue = snapshot.nextQueue
        bag = snapshot.bag
        score = max(0, snapshot.score)
        level = max(1, snapshot.level)
        linesCleared = max(0, snapshot.linesCleared)
        lineClearEvents = max(0, snapshot.lineClearEvents)
        status = snapshot.status
        spawnSerial = max(0, snapshot.spawnSerial)
        lockTicks = min(max(0, snapshot.lockTicks), lockDelayTicks)
        rng = SeededGenerator(restoringState: snapshot.rngState)
        startedAt = snapshot.startedAt
        lastClearedRows = []
        return true
    }

    public func togglePause() {
        switch status {
        case .running:
            status = .paused
        case .paused:
            status = .running
        case .gameOver:
            break
        }
    }

    public func pause() {
        guard status == .running else { return }
        status = .paused
    }

    public func resume() {
        guard status == .paused else { return }
        status = .running
    }

    @discardableResult
    public func tick() -> Bool {
        guard status == .running else { return false }
        guard activePiece != nil else {
            spawnPiece()
            return false
        }

        if moveActivePiece(dx: 0, dy: 1) {
            lockTicks = 0
            return true
        }

        lockTicks += 1
        if lockTicks >= lockDelayTicks {
            lockPiece()
        }
        return false
    }

    @discardableResult
    public func moveLeft() -> Bool {
        moveActivePiece(dx: -1, dy: 0)
    }

    @discardableResult
    public func moveRight() -> Bool {
        moveActivePiece(dx: 1, dy: 0)
    }

    @discardableResult
    public func softDrop() -> Bool {
        guard status == .running else { return false }
        if moveActivePiece(dx: 0, dy: 1) {
            score += 1
            lockTicks = 0
            return true
        }
        lockTicks += 1
        if lockTicks >= lockDelayTicks {
            lockPiece()
        }
        return false
    }

    public func hardDrop() {
        guard status == .running, var piece = activePiece else { return }
        let distance = dropDistance(for: piece)
        piece.origin.y += distance
        activePiece = piece
        score += distance * 2
        lockPiece()
    }

    @discardableResult
    public func rotateClockwise() -> Bool {
        rotate(clockwise: true)
    }

    @discardableResult
    public func rotateCounterclockwise() -> Bool {
        rotate(clockwise: false)
    }

    public func ghostPiece() -> ActivePiece? {
        guard var piece = activePiece else { return nil }
        piece.origin.y += dropDistance(for: piece)
        return piece
    }

    public func cell(at point: GridPoint) -> TetrominoKind? {
        guard isInsideBoard(point) else { return nil }
        return board[point.y][point.x]
    }

    public func setCell(x: Int, y: Int, kind: TetrominoKind?) {
        guard x >= 0, x < width, y >= 0, y < height else { return }
        board[y][x] = kind
    }

    public func setActivePiece(_ piece: ActivePiece?) {
        activePiece = piece
        lockTicks = 0
    }

    public func isValidPosition(_ piece: ActivePiece) -> Bool {
        piece.blocks.allSatisfy { block in
            guard block.x >= 0, block.x < width, block.y < height else {
                return false
            }
            if block.y < 0 {
                return true
            }
            return board[block.y][block.x] == nil
        }
    }

    private func moveActivePiece(dx: Int, dy: Int) -> Bool {
        guard status == .running, var piece = activePiece else { return false }
        piece.origin.x += dx
        piece.origin.y += dy
        guard isValidPosition(piece) else { return false }
        activePiece = piece
        if dx != 0 {
            lockTicks = 0
        }
        return true
    }

    private func rotate(clockwise: Bool) -> Bool {
        guard status == .running, var rotated = activePiece else { return false }
        rotated.rotation = clockwise ? rotated.rotation.clockwise : rotated.rotation.counterclockwise

        let kicks = [
            GridPoint(x: 0, y: 0),
            GridPoint(x: -1, y: 0),
            GridPoint(x: 1, y: 0),
            GridPoint(x: -2, y: 0),
            GridPoint(x: 2, y: 0),
            GridPoint(x: 0, y: -1)
        ]

        for kick in kicks {
            var candidate = rotated
            candidate.origin.x += kick.x
            candidate.origin.y += kick.y
            if isValidPosition(candidate) {
                activePiece = candidate
                lockTicks = 0
                return true
            }
        }
        return false
    }

    private func dropDistance(for piece: ActivePiece) -> Int {
        var distance = 0
        var candidate = piece
        while true {
            candidate.origin.y += 1
            if isValidPosition(candidate) {
                distance += 1
            } else {
                return distance
            }
        }
    }

    private func lockPiece() {
        guard let piece = activePiece else { return }
        for block in piece.blocks {
            if block.y < 0 {
                status = .gameOver
                return
            }
            if isInsideBoard(block) {
                board[block.y][block.x] = piece.kind
            }
        }

        activePiece = nil
        lockTicks = 0
        lastClearedRows = []
        let cleared = clearCompleteLines()
        if cleared > 0 {
            lineClearEvents += 1
        }
        applyScore(forClearedLineCount: cleared)
        spawnPiece()
    }

    private func clearCompleteLines() -> Int {
        lastClearedRows = board.enumerated().compactMap { index, row in
            row.contains { $0 == nil } ? nil : index
        }
        let remainingRows = board.filter { row in
            row.contains { $0 == nil }
        }
        let cleared = height - remainingRows.count
        guard cleared > 0 else { return 0 }

        let emptyRows = Array(repeating: Array(repeating: Optional<TetrominoKind>.none, count: width), count: cleared)
        board = emptyRows + remainingRows
        return cleared
    }

    private func applyScore(forClearedLineCount cleared: Int) {
        guard cleared > 0 else { return }
        let table = [0, 40, 100, 300, 1_200]
        score += table[min(cleared, 4)] * level
        linesCleared += cleared
        level = max(1, linesCleared / 10 + 1)
    }

    private func spawnPiece() {
        refillQueueIfNeeded()
        guard !nextQueue.isEmpty else { return }
        let kind = nextQueue.removeFirst()
        refillQueueIfNeeded()

        let origin = GridPoint(x: width / 2 - 2, y: 0)
        let piece = ActivePiece(kind: kind, origin: origin)
        activePiece = piece
        spawnSerial += 1

        if !isValidPosition(piece) {
            status = .gameOver
        }
    }

    private func refillQueueIfNeeded() {
        while nextQueue.count < 3 {
            if bag.isEmpty {
                bag = TetrominoKind.allCases
                bag.shuffle(using: &rng)
            }
            nextQueue.append(bag.removeFirst())
        }
    }

    private func isInsideBoard(_ point: GridPoint) -> Bool {
        point.x >= 0 && point.x < width && point.y >= 0 && point.y < height
    }
}
