import AppKit
import MatrixTetrisCore

final class TetrisBoardView: NSView {
    private let engine: GameEngine
    private var rainTick = 0
    private var lineClearFrames = 0
    private var clearedRows: [Int] = []
    private var hardDropTrailFrames = 0
    private var hardDropTrail: [TrailSegment] = []
    private var spawnPulseFrames = 0
    private let matrixCharacters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    private let outlineColor = NSColor(calibratedRed: 0.23, green: 1, blue: 0.38, alpha: 1)
    var animationMode: AnimationMode = .subtle {
        didSet {
            if animationMode == .off {
                lineClearFrames = 0
                hardDropTrailFrames = 0
                spawnPulseFrames = 0
                clearedRows = []
                hardDropTrail = []
                needsDisplay = true
            }
        }
    }

    init(engine: GameEngine) {
        self.engine = engine
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    func advanceRain() {
        rainTick = (rainTick + 1) % 10_000
        needsDisplay = true
    }

    func advanceAnimations() -> Bool {
        guard animationMode == .subtle else { return false }
        let wasAnimating = lineClearFrames > 0 || hardDropTrailFrames > 0 || spawnPulseFrames > 0
        lineClearFrames = max(0, lineClearFrames - 1)
        hardDropTrailFrames = max(0, hardDropTrailFrames - 1)
        spawnPulseFrames = max(0, spawnPulseFrames - 1)
        if lineClearFrames == 0 {
            clearedRows = []
        }
        if hardDropTrailFrames == 0 {
            hardDropTrail = []
        }
        return wasAnimating
    }

    func triggerLineClear(rows: [Int], count: Int) {
        guard animationMode == .subtle else { return }
        clearedRows = rows.isEmpty ? Array(max(0, engine.height - count)..<engine.height) : rows
        lineClearFrames = 14
        needsDisplay = true
    }

    func triggerHardDropTrail(from start: ActivePiece, to end: ActivePiece) {
        guard animationMode == .subtle else { return }
        let startBlocks = start.blocks.sorted { left, right in
            left.x == right.x ? left.y < right.y : left.x < right.x
        }
        let endBlocks = end.blocks.sorted { left, right in
            left.x == right.x ? left.y < right.y : left.x < right.x
        }
        hardDropTrail = zip(startBlocks, endBlocks).map { start, end in
            TrailSegment(x: end.x, startY: min(start.y, end.y), endY: max(start.y, end.y))
        }.filter { $0.endY > $0.startY }
        hardDropTrailFrames = hardDropTrail.isEmpty ? 0 : 10
        needsDisplay = true
    }

    func triggerSpawnPulse() {
        guard animationMode == .subtle else { return }
        spawnPulseFrames = 9
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        drawBackground()
        let boardRect = fittedBoardRect()
        drawRain(in: boardRect)
        drawGrid(in: boardRect)
        drawHardDropTrail(in: boardRect)
        drawLockedCells(in: boardRect)
        drawGhostPiece(in: boardRect)
        drawActivePiece(in: boardRect)
        drawLineClearFlash(in: boardRect)
        drawGameOverOverlay(in: boardRect)
    }

    private func drawBackground() {
        NSColor(calibratedRed: 0, green: 0.015, blue: 0.008, alpha: 1).setFill()
        bounds.fill()
    }

    private func fittedBoardRect() -> NSRect {
        let cellSize = floor(min(bounds.width / CGFloat(engine.width), bounds.height / CGFloat(engine.height)))
        let width = cellSize * CGFloat(engine.width)
        let height = cellSize * CGFloat(engine.height)
        return NSRect(
            x: bounds.midX - width / 2,
            y: bounds.midY - height / 2,
            width: width,
            height: height
        )
    }

    private func drawRain(in rect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: rect).addClip()
        let font = NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(calibratedRed: 0.1, green: 0.8, blue: 0.22, alpha: 0.12)
        ]

        let columnWidth: CGFloat = 24
        let rowHeight: CGFloat = 22
        let columns = Int(rect.width / columnWidth) + 2
        let rows = Int(rect.height / rowHeight) + 4

        for column in 0..<columns {
            let offset = CGFloat((rainTick + column * 7) % rows) * rowHeight
            for row in 0..<rows {
                let index = abs((column * 29 + row * 17 + rainTick) % matrixCharacters.count)
                let char = String(matrixCharacters[index])
                let x = rect.minX + CGFloat(column) * columnWidth
                let y = rect.maxY - CGFloat(row) * rowHeight + offset.truncatingRemainder(dividingBy: rect.height + rowHeight) - rect.height
                char.draw(at: NSPoint(x: x, y: y), withAttributes: attributes)
            }
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawGrid(in rect: NSRect) {
        let path = NSBezierPath()
        path.lineWidth = 0.5
        NSColor(calibratedRed: 0.07, green: 0.45, blue: 0.15, alpha: 0.45).setStroke()

        let cell = rect.width / CGFloat(engine.width)
        for x in 0...engine.width {
            let px = rect.minX + CGFloat(x) * cell
            path.move(to: NSPoint(x: px, y: rect.minY))
            path.line(to: NSPoint(x: px, y: rect.maxY))
        }
        for y in 0...engine.height {
            let py = rect.minY + CGFloat(y) * cell
            path.move(to: NSPoint(x: rect.minX, y: py))
            path.line(to: NSPoint(x: rect.maxX, y: py))
        }
        path.stroke()

        let border = NSBezierPath(rect: rect)
        border.lineWidth = 2
        NSColor(calibratedRed: 0.15, green: 1, blue: 0.34, alpha: 0.75).setStroke()
        border.stroke()
    }

    private func drawLockedCells(in rect: NSRect) {
        for y in 0..<engine.height {
            for x in 0..<engine.width {
                guard let kind = engine.board[y][x] else { continue }
                drawCell(kind: kind, point: GridPoint(x: x, y: y), in: rect, alpha: 0.95)
            }
        }
    }

    private func drawGhostPiece(in rect: NSRect) {
        guard let ghost = engine.ghostPiece(), ghost != engine.activePiece else { return }
        for block in ghost.blocks where block.y >= 0 {
            drawCell(kind: ghost.kind, point: block, in: rect, alpha: 0.22, strokeOnly: true)
        }
    }

    private func drawActivePiece(in rect: NSRect) {
        guard let piece = engine.activePiece else { return }
        for block in piece.blocks where block.y >= 0 {
            drawCell(kind: piece.kind, point: block, in: rect, alpha: 1, pulse: spawnPulseAlpha)
        }
    }

    private var spawnPulseAlpha: CGFloat {
        guard animationMode == .subtle, spawnPulseFrames > 0 else { return 0 }
        return CGFloat(spawnPulseFrames) / 9.0
    }

    private func drawHardDropTrail(in rect: NSRect) {
        guard animationMode == .subtle, hardDropTrailFrames > 0 else { return }
        let cell = rect.width / CGFloat(engine.width)
        let alpha = CGFloat(hardDropTrailFrames) / 10.0
        outlineColor.withAlphaComponent(0.12 + 0.18 * alpha).setStroke()
        for segment in hardDropTrail {
            guard segment.endY >= 0 else { continue }
            let x = rect.minX + CGFloat(segment.x) * cell + cell / 2
            let y1 = rect.maxY - CGFloat(max(segment.startY, 0)) * cell - cell / 2
            let y2 = rect.maxY - CGFloat(segment.endY + 1) * cell + cell / 2
            let path = NSBezierPath()
            path.lineWidth = 1.2
            path.move(to: NSPoint(x: x, y: y1))
            path.line(to: NSPoint(x: x, y: y2))
            path.stroke()
        }
    }

    private func drawLineClearFlash(in rect: NSRect) {
        guard animationMode == .subtle, lineClearFrames > 0 else { return }
        let cell = rect.width / CGFloat(engine.width)
        let alpha = CGFloat(lineClearFrames) / 14.0
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: rect).addClip()
        for row in clearedRows {
            let y = rect.maxY - CGFloat(row + 1) * cell
            let rowRect = NSRect(x: rect.minX, y: y, width: rect.width, height: cell)
            NSColor(calibratedRed: 0.24, green: 1, blue: 0.42, alpha: 0.08 + 0.16 * alpha).setFill()
            rowRect.fill()

            let glitch = NSBezierPath()
            glitch.lineWidth = 1
            outlineColor.withAlphaComponent(0.28 + 0.42 * alpha).setStroke()
            let offset = CGFloat((rainTick + row * 5) % 11) - 5
            glitch.move(to: NSPoint(x: rect.minX + 12 + offset, y: rowRect.midY))
            glitch.line(to: NSPoint(x: rect.maxX - 16 + offset, y: rowRect.midY))
            glitch.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawGameOverOverlay(in rect: NSRect) {
        guard engine.status == .gameOver else { return }
        NSColor(calibratedWhite: 0, alpha: 0.7).setFill()
        rect.fill()

        let text = "GAME OVER\nPress R"
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 24, weight: .bold),
            .foregroundColor: NSColor(calibratedRed: 0.65, green: 1, blue: 0.72, alpha: 1),
            .paragraphStyle: paragraph
        ]
        text.draw(in: NSRect(x: rect.minX, y: rect.midY - 38, width: rect.width, height: 76), withAttributes: attributes)
    }

    private func drawCell(
        kind _: TetrominoKind,
        point: GridPoint,
        in rect: NSRect,
        alpha: CGFloat,
        strokeOnly: Bool = false,
        pulse: CGFloat = 0
    ) {
        let cell = rect.width / CGFloat(engine.width)
        var cellRect = NSRect(
            x: rect.minX + CGFloat(point.x) * cell + 2,
            y: rect.maxY - CGFloat(point.y + 1) * cell + 2,
            width: cell - 4,
            height: cell - 4
        )
        if pulse > 0 {
            cellRect = cellRect.insetBy(dx: -1.2 * pulse, dy: -1.2 * pulse)
        }
        let path = NSBezierPath(roundedRect: cellRect, xRadius: 2, yRadius: 2)
        outlineColor.withAlphaComponent(alpha).setStroke()
        path.lineWidth = strokeOnly ? 1.4 : 1.8 + 0.8 * pulse
        path.stroke()

        if !strokeOnly {
            let inner = cellRect.insetBy(dx: cell * 0.2, dy: cell * 0.2)
            NSBezierPath(roundedRect: inner, xRadius: 1, yRadius: 1).stroke()
        }
        drawGlitchEdges(for: point, in: cellRect, alpha: alpha * (strokeOnly ? 0.55 : 1))
    }

    private func drawGlitchEdges(for point: GridPoint, in rect: NSRect, alpha: CGFloat) {
        let seed = abs(point.x * 37 + point.y * 53 + rainTick * 3)
        let path = NSBezierPath()
        path.lineWidth = 1.2
        outlineColor.withAlphaComponent(max(0.12, alpha * 0.78)).setStroke()

        let topOffset = CGFloat((seed % 5) - 2)
        path.move(to: NSPoint(x: rect.minX + 2 + topOffset, y: rect.maxY + 1))
        path.line(to: NSPoint(x: rect.midX + topOffset, y: rect.maxY + 1))

        let sideOffset = CGFloat(((seed / 5) % 5) - 2)
        path.move(to: NSPoint(x: rect.maxX + 1, y: rect.midY + sideOffset))
        path.line(to: NSPoint(x: rect.maxX + 1, y: rect.minY + 3 + sideOffset))

        if seed % 3 == 0 {
            path.move(to: NSPoint(x: rect.minX - 1, y: rect.minY + 5))
            path.line(to: NSPoint(x: rect.minX + rect.width * 0.45, y: rect.minY + 5))
        }
        path.stroke()
    }
}

final class NextPieceView: NSView {
    private let engine: GameEngine
    private let outlineColor = NSColor(calibratedRed: 0.23, green: 1, blue: 0.38, alpha: 1)

    init(engine: GameEngine) {
        self.engine = engine
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        layer?.borderColor = NSColor(calibratedRed: 0.11, green: 0.7, blue: 0.25, alpha: 0.55).cgColor
        layer?.backgroundColor = NSColor(calibratedRed: 0, green: 0.05, blue: 0.018, alpha: 0.75).cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let next = engine.nextQueue.first else { return }
        let offsets = TetrominoShapes.offsets(for: next, rotation: .up)
        let cell: CGFloat = 18
        let minX = offsets.map(\.x).min() ?? 0
        let maxX = offsets.map(\.x).max() ?? 0
        let minY = offsets.map(\.y).min() ?? 0
        let maxY = offsets.map(\.y).max() ?? 0
        let pieceWidth = CGFloat(maxX - minX + 1) * cell
        let pieceHeight = CGFloat(maxY - minY + 1) * cell
        let origin = NSPoint(x: bounds.midX - pieceWidth / 2, y: bounds.midY - pieceHeight / 2)

        for block in offsets {
            let rect = NSRect(
                x: origin.x + CGFloat(block.x - minX) * cell,
                y: origin.y + CGFloat(maxY - block.y) * cell,
                width: cell - 3,
                height: cell - 3
            )
            let path = NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)
            outlineColor.setStroke()
            path.lineWidth = 1.5
            path.stroke()

            let glitch = NSBezierPath()
            glitch.lineWidth = 1
            outlineColor.withAlphaComponent(0.75).setStroke()
            glitch.move(to: NSPoint(x: rect.minX + 2, y: rect.maxY + 1))
            glitch.line(to: NSPoint(x: rect.midX + CGFloat(block.x), y: rect.maxY + 1))
            glitch.stroke()
        }
    }
}

private struct TrailSegment {
    var x: Int
    var startY: Int
    var endY: Int
}
