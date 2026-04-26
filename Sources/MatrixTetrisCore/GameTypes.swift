import Foundation

public struct GridPoint: Hashable, Codable, Sendable {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

public enum TetrominoKind: String, CaseIterable, Codable, Sendable {
    case i
    case o
    case t
    case s
    case z
    case j
    case l
}

public enum RotationState: Int, CaseIterable, Codable, Sendable {
    case up = 0
    case right
    case down
    case left

    public var clockwise: RotationState {
        RotationState(rawValue: (rawValue + 1) % RotationState.allCases.count) ?? .up
    }

    public var counterclockwise: RotationState {
        RotationState(rawValue: (rawValue + RotationState.allCases.count - 1) % RotationState.allCases.count) ?? .up
    }
}

public struct ActivePiece: Equatable, Codable, Sendable {
    public var kind: TetrominoKind
    public var rotation: RotationState
    public var origin: GridPoint

    public init(kind: TetrominoKind, rotation: RotationState = .up, origin: GridPoint) {
        self.kind = kind
        self.rotation = rotation
        self.origin = origin
    }

    public var blocks: [GridPoint] {
        TetrominoShapes.offsets(for: kind, rotation: rotation).map {
            GridPoint(x: origin.x + $0.x, y: origin.y + $0.y)
        }
    }
}

public enum GameStatus: String, Codable, Equatable, Sendable {
    case running
    case paused
    case gameOver
}

public struct GameSnapshot: Codable, Equatable, Sendable {
    public var width: Int
    public var height: Int
    public var board: [[TetrominoKind?]]
    public var activePiece: ActivePiece?
    public var nextQueue: [TetrominoKind]
    public var bag: [TetrominoKind]
    public var score: Int
    public var level: Int
    public var linesCleared: Int
    public var lineClearEvents: Int
    public var status: GameStatus
    public var spawnSerial: Int
    public var lockTicks: Int
    public var rngState: UInt64
    public var startedAt: Date

    public init(
        width: Int,
        height: Int,
        board: [[TetrominoKind?]],
        activePiece: ActivePiece?,
        nextQueue: [TetrominoKind],
        bag: [TetrominoKind],
        score: Int,
        level: Int,
        linesCleared: Int,
        lineClearEvents: Int,
        status: GameStatus,
        spawnSerial: Int,
        lockTicks: Int,
        rngState: UInt64,
        startedAt: Date
    ) {
        self.width = width
        self.height = height
        self.board = board
        self.activePiece = activePiece
        self.nextQueue = nextQueue
        self.bag = bag
        self.score = score
        self.level = level
        self.linesCleared = linesCleared
        self.lineClearEvents = lineClearEvents
        self.status = status
        self.spawnSerial = spawnSerial
        self.lockTicks = lockTicks
        self.rngState = rngState
        self.startedAt = startedAt
    }

    public var isRestorableSession: Bool {
        status != .gameOver
    }
}

public enum GameAction: String, CaseIterable, Codable, Sendable {
    case moveLeft
    case moveRight
    case rotateClockwise
    case rotateCounterclockwise
    case softDrop
    case hardDrop
    case pause
    case restart

    public var label: String {
        switch self {
        case .moveLeft:
            "Move Left"
        case .moveRight:
            "Move Right"
        case .rotateClockwise:
            "Rotate Clockwise"
        case .rotateCounterclockwise:
            "Rotate Counterclockwise"
        case .softDrop:
            "Soft Drop"
        case .hardDrop:
            "Hard Drop"
        case .pause:
            "Pause"
        case .restart:
            "Restart"
        }
    }
}

public enum ShortcutModifier: String, CaseIterable, Codable, Hashable, Sendable {
    case control
    case option
    case command
    case shift
    case function

    public var display: String {
        switch self {
        case .control:
            "Ctrl"
        case .option:
            "Opt"
        case .command:
            "Cmd"
        case .shift:
            "Shift"
        case .function:
            "Fn"
        }
    }
}

public struct Shortcut: Codable, Equatable, Hashable, Sendable {
    public var keyCode: UInt16
    public var modifiers: Set<ShortcutModifier>

    public init(keyCode: UInt16, modifiers: Set<ShortcutModifier> = []) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

public enum DropdownPosition: String, CaseIterable, Codable, Sendable {
    case rightSide
    case leftSide
    case topCenter
    case mousePosition
    case menuBar

    public var label: String {
        switch self {
        case .rightSide:
            "Right Side"
        case .leftSide:
            "Left Side"
        case .topCenter:
            "Top Center"
        case .mousePosition:
            "Mouse Position"
        case .menuBar:
            "Menu Bar"
        }
    }
}

public enum AnimationMode: String, CaseIterable, Codable, Sendable {
    case off
    case subtle

    public var label: String {
        switch self {
        case .off:
            "Off"
        case .subtle:
            "Subtle"
        }
    }
}

public enum AnimationEffect: String, CaseIterable, Codable, Sendable {
    case lineClear
    case hardDrop
    case softDrop
    case spawn
    case move
    case landing

    public var label: String {
        switch self {
        case .lineClear:
            "Line Clear FX"
        case .hardDrop:
            "Hard Drop FX"
        case .softDrop:
            "Soft Drop FX"
        case .spawn:
            "Spawn FX"
        case .move:
            "Move FX"
        case .landing:
            "Landing FX"
        }
    }
}

public enum SoundTheme: String, CaseIterable, Codable, Sendable {
    case matrixMinimal
    case arcadePunchy

    public var label: String {
        switch self {
        case .matrixMinimal:
            "Matrix Minimal"
        case .arcadePunchy:
            "Arcade Punchy"
        }
    }
}

public enum SoundEffect: String, CaseIterable, Codable, Sendable {
    case move
    case rotate
    case softDrop
    case hardDrop
    case lock
    case lineClearSingle
    case lineClearDouble
    case lineClearTriple
    case lineClearTetris
    case gameOver
    case pause
    case resume
    case highScore
    case dropdownOpen
    case dropdownClose
    case button

    public static func lineClear(for clearedLines: Int) -> SoundEffect {
        switch clearedLines {
        case 1:
            .lineClearSingle
        case 2:
            .lineClearDouble
        case 3:
            .lineClearTriple
        default:
            .lineClearTetris
        }
    }
}

public enum MacKeyCode {
    public static let a: UInt16 = 0
    public static let s: UInt16 = 1
    public static let d: UInt16 = 2
    public static let z: UInt16 = 6
    public static let r: UInt16 = 15
    public static let t: UInt16 = 17
    public static let p: UInt16 = 35
    public static let space: UInt16 = 49
    public static let grave: UInt16 = 50
    public static let leftArrow: UInt16 = 123
    public static let rightArrow: UInt16 = 124
    public static let downArrow: UInt16 = 125
    public static let upArrow: UInt16 = 126
}

public enum TetrominoShapes {
    public static func offsets(for kind: TetrominoKind, rotation: RotationState) -> [GridPoint] {
        switch kind {
        case .i:
            switch rotation {
            case .up:
                return points((0, 1), (1, 1), (2, 1), (3, 1))
            case .right:
                return points((2, 0), (2, 1), (2, 2), (2, 3))
            case .down:
                return points((0, 2), (1, 2), (2, 2), (3, 2))
            case .left:
                return points((1, 0), (1, 1), (1, 2), (1, 3))
            }
        case .o:
            return points((1, 0), (2, 0), (1, 1), (2, 1))
        case .t:
            switch rotation {
            case .up:
                return points((1, 0), (0, 1), (1, 1), (2, 1))
            case .right:
                return points((1, 0), (1, 1), (2, 1), (1, 2))
            case .down:
                return points((0, 1), (1, 1), (2, 1), (1, 2))
            case .left:
                return points((1, 0), (0, 1), (1, 1), (1, 2))
            }
        case .s:
            switch rotation {
            case .up:
                return points((1, 0), (2, 0), (0, 1), (1, 1))
            case .right:
                return points((1, 0), (1, 1), (2, 1), (2, 2))
            case .down:
                return points((1, 1), (2, 1), (0, 2), (1, 2))
            case .left:
                return points((0, 0), (0, 1), (1, 1), (1, 2))
            }
        case .z:
            switch rotation {
            case .up:
                return points((0, 0), (1, 0), (1, 1), (2, 1))
            case .right:
                return points((2, 0), (1, 1), (2, 1), (1, 2))
            case .down:
                return points((0, 1), (1, 1), (1, 2), (2, 2))
            case .left:
                return points((1, 0), (0, 1), (1, 1), (0, 2))
            }
        case .j:
            switch rotation {
            case .up:
                return points((0, 0), (0, 1), (1, 1), (2, 1))
            case .right:
                return points((1, 0), (2, 0), (1, 1), (1, 2))
            case .down:
                return points((0, 1), (1, 1), (2, 1), (2, 2))
            case .left:
                return points((1, 0), (1, 1), (0, 2), (1, 2))
            }
        case .l:
            switch rotation {
            case .up:
                return points((2, 0), (0, 1), (1, 1), (2, 1))
            case .right:
                return points((1, 0), (1, 1), (1, 2), (2, 2))
            case .down:
                return points((0, 1), (1, 1), (2, 1), (0, 2))
            case .left:
                return points((0, 0), (1, 0), (1, 1), (1, 2))
            }
        }
    }

    private static func points(_ values: (Int, Int)...) -> [GridPoint] {
        values.map { GridPoint(x: $0.0, y: $0.1) }
    }
}
