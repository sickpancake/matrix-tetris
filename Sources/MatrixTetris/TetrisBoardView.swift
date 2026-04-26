import AppKit
import MatrixTetrisCore

final class TetrisBoardView: NSView {
    private let engine: GameEngine
    private let spawnLaneRows = 2
    private var rainTick = 0
    private var lineClearFrames = 0
    private var clearedRows: [Int] = []
    private var hardDropTrailFrames = 0
    private var hardDropTrail: [TrailSegment] = []
    private var softDropTrailFrames = 0
    private var softDropTrail: [TrailSegment] = []
    private var spawnPulseFrames = 0
    private var movePulseFrames = 0
    private var clampedGhostOpacity = 4
    private var currentAnimationIntensities = AnimationIntensityState.defaultState()
    private let matrixCharacters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    private let outlineColor = NSColor(calibratedRed: 0.23, green: 1, blue: 0.38, alpha: 1)
    var ghostOpacity: Int {
        get {
            clampedGhostOpacity
        }
        set {
            clampedGhostOpacity = min(max(newValue, 1), 10)
            needsDisplay = true
        }
    }
    var animationIntensities: AnimationIntensityState {
        get {
            currentAnimationIntensities
        }
        set {
            currentAnimationIntensities = newValue.normalized()
            clearDisabledAnimations()
            needsDisplay = true
        }
    }
    var animationMode: AnimationMode = .subtle {
        didSet {
            if animationMode == .off {
                clearAllAnimations()
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
        let wasAnimating = lineClearFrames > 0 || hardDropTrailFrames > 0 || softDropTrailFrames > 0 || spawnPulseFrames > 0 || movePulseFrames > 0
        lineClearFrames = max(0, lineClearFrames - 1)
        hardDropTrailFrames = max(0, hardDropTrailFrames - 1)
        softDropTrailFrames = max(0, softDropTrailFrames - 1)
        spawnPulseFrames = max(0, spawnPulseFrames - 1)
        movePulseFrames = max(0, movePulseFrames - 1)
        if lineClearFrames == 0 {
            clearedRows = []
        }
        if hardDropTrailFrames == 0 {
            hardDropTrail = []
        }
        if softDropTrailFrames == 0 {
            softDropTrail = []
        }
        return wasAnimating
    }

    func triggerLineClear(rows: [Int], count: Int) {
        let scale = animationScale(for: .lineClear)
        guard scale > 0 else { return }
        clearedRows = rows.isEmpty ? Array(max(0, engine.height - count)..<engine.height) : rows
        lineClearFrames = max(5, Int((14.0 * scale).rounded()))
        needsDisplay = true
    }

    func triggerHardDropTrail(from start: ActivePiece, to end: ActivePiece) {
        let scale = animationScale(for: .hardDrop)
        guard scale > 0 else { return }
        hardDropTrail = trailSegments(from: start, to: end)
        hardDropTrailFrames = hardDropTrail.isEmpty ? 0 : max(4, Int((10.0 * scale).rounded()))
        needsDisplay = true
    }

    func triggerSoftDropTrail(from start: ActivePiece, to end: ActivePiece) {
        let scale = animationScale(for: .softDrop)
        guard scale > 0 else { return }
        softDropTrail = trailSegments(from: start, to: end)
        softDropTrailFrames = softDropTrail.isEmpty ? 0 : max(4, Int((12.0 * scale).rounded()))
        needsDisplay = true
    }

    func triggerMovePulse() {
        let scale = animationScale(for: .move)
        guard scale > 0 else { return }
        movePulseFrames = max(3, Int((5.0 * scale).rounded()))
        needsDisplay = true
    }

    func triggerSpawnPulse() {
        let scale = animationScale(for: .spawn)
        guard scale > 0 else { return }
        spawnPulseFrames = max(4, Int((9.0 * scale).rounded()))
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        drawBackground()
        let boardRect = fittedBoardRect()
        drawRain(in: boardRect)
        drawGrid(in: boardRect)
        drawHardDropTrail(in: boardRect)
        drawSoftDropTrail(in: boardRect)
        drawLockedCells(in: boardRect)
        drawGhostPiece(in: boardRect)
        drawActivePiece(in: boardRect)
        drawLandingPulse(in: boardRect)
        drawLineClearFlash(in: boardRect)
        drawGameOverOverlay(in: boardRect)
    }

    private func drawBackground() {
        NSColor(calibratedRed: 0, green: 0.015, blue: 0.008, alpha: 1).setFill()
        bounds.fill()
    }

    private func fittedBoardRect() -> NSRect {
        let cellSize = floor(min(bounds.width / CGFloat(engine.width), bounds.height / CGFloat(totalRenderedRows)))
        let width = cellSize * CGFloat(engine.width)
        let height = cellSize * CGFloat(totalRenderedRows)
        return NSRect(
            x: bounds.midX - width / 2,
            y: bounds.midY - height / 2,
            width: width,
            height: height
        )
    }

    private var totalRenderedRows: Int {
        engine.height + spawnLaneRows
    }

    private func cellSize(in rect: NSRect) -> CGFloat {
        rect.width / CGFloat(engine.width)
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

        let cell = cellSize(in: rect)
        for x in 0...engine.width {
            let px = rect.minX + CGFloat(x) * cell
            path.move(to: NSPoint(x: px, y: rect.minY))
            path.line(to: NSPoint(x: px, y: rect.maxY))
        }
        for y in 0...totalRenderedRows {
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
        let alpha = 0.06 + CGFloat(clampedGhostOpacity) * 0.038
        for block in ghost.blocks where isRenderable(block) {
            drawCell(kind: ghost.kind, point: block, in: rect, alpha: alpha, strokeOnly: true)
        }
    }

    private func drawActivePiece(in rect: NSRect) {
        guard let piece = engine.activePiece else { return }
        let pulse = max(spawnPulseAlpha, movePulseAlpha)
        for block in piece.blocks where isRenderable(block) {
            drawCell(kind: piece.kind, point: block, in: rect, alpha: 1, pulse: pulse)
        }
    }

    private var spawnPulseAlpha: CGFloat {
        guard animationMode == .subtle, spawnPulseFrames > 0 else { return 0 }
        return CGFloat(spawnPulseFrames) / 9.0 * animationScale(for: .spawn)
    }

    private var movePulseAlpha: CGFloat {
        guard animationMode == .subtle, movePulseFrames > 0 else { return 0 }
        return CGFloat(movePulseFrames) / 12.0 * animationScale(for: .move)
    }

    private func drawHardDropTrail(in rect: NSRect) {
        let scale = animationScale(for: .hardDrop)
        guard scale > 0, hardDropTrailFrames > 0 else { return }
        let cell = cellSize(in: rect)
        let alpha = CGFloat(hardDropTrailFrames) / 10.0
        outlineColor.withAlphaComponent((0.08 + 0.22 * alpha) * scale).setStroke()
        for segment in hardDropTrail {
            let startY = min(max(segment.startY, -spawnLaneRows), engine.height - 1)
            let endY = min(max(segment.endY, -spawnLaneRows), engine.height - 1)
            guard endY >= -spawnLaneRows, startY < engine.height else { continue }
            let x = rect.minX + CGFloat(segment.x) * cell + cell / 2
            let y1 = centerY(forRow: startY, in: rect)
            let y2 = centerY(forRow: endY, in: rect)
            let path = NSBezierPath()
            path.lineWidth = 1.2
            path.move(to: NSPoint(x: x, y: y1))
            path.line(to: NSPoint(x: x, y: y2))
            path.stroke()
        }
    }

    private func drawSoftDropTrail(in rect: NSRect) {
        let scale = animationScale(for: .softDrop)
        guard scale > 0, softDropTrailFrames > 0 else { return }
        let cell = cellSize(in: rect)
        let alpha = CGFloat(softDropTrailFrames) / 12.0
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: rect).addClip()
        for segment in softDropTrail {
            let topY = min(max(min(segment.startY, segment.endY), -spawnLaneRows), engine.height - 1)
            let bottomY = min(max(max(segment.startY, segment.endY), -spawnLaneRows), engine.height - 1)
            guard bottomY >= topY else { continue }
            let topVisualY = topY + spawnLaneRows
            let bottomVisualY = bottomY + spawnLaneRows
            let trailRect = NSRect(
                x: rect.minX + CGFloat(segment.x) * cell + 3,
                y: rect.maxY - CGFloat(bottomVisualY + 1) * cell + 3,
                width: cell - 6,
                height: CGFloat(bottomVisualY - topVisualY + 1) * cell - 6
            )

            NSColor(calibratedRed: 0.16, green: 1, blue: 0.34, alpha: 0.03 * scale + 0.15 * alpha * scale).setFill()
            trailRect.fill()

            let box = NSBezierPath(roundedRect: trailRect, xRadius: 2, yRadius: 2)
            box.lineWidth = 1.7
            outlineColor.withAlphaComponent(0.18 * scale + 0.50 * alpha * scale).setStroke()
            box.stroke()

            let x = trailRect.midX
            let y1 = trailRect.maxY
            let y2 = trailRect.minY
            let path = NSBezierPath()
            path.lineWidth = 1.4
            outlineColor.withAlphaComponent(0.22 * scale + 0.46 * alpha * scale).setStroke()
            path.move(to: NSPoint(x: x - 4, y: y1))
            path.line(to: NSPoint(x: x + 4, y: y2))
            path.move(to: NSPoint(x: trailRect.minX + 3, y: trailRect.midY))
            path.line(to: NSPoint(x: trailRect.maxX - 3, y: trailRect.midY))
            path.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawLandingPulse(in rect: NSRect) {
        let scale = animationScale(for: .landing)
        guard scale > 0, engine.activePieceIsGrounded, let piece = engine.activePiece else { return }
        let progress = CGFloat(engine.lockProgress)
        let alpha = (0.10 + 0.32 * progress) * scale
        outlineColor.withAlphaComponent(alpha).setStroke()

        for block in piece.blocks where isRenderable(block) {
            let blockRect = cellRect(for: block, in: rect, inset: 2)
            let y = blockRect.minY + 1
            let x = blockRect.minX + 2
            let path = NSBezierPath()
            path.lineWidth = 1.1
            path.move(to: NSPoint(x: x, y: y - 1))
            path.line(to: NSPoint(x: blockRect.maxX - 2, y: y - 1))
            path.stroke()
        }
    }

    private func drawLineClearFlash(in rect: NSRect) {
        let scale = animationScale(for: .lineClear)
        guard scale > 0, lineClearFrames > 0 else { return }
        let cell = cellSize(in: rect)
        let alpha = CGFloat(lineClearFrames) / 14.0
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: rect).addClip()
        for row in clearedRows {
            let y = rect.maxY - CGFloat(row + spawnLaneRows + 1) * cell
            let rowRect = NSRect(x: rect.minX, y: y, width: rect.width, height: cell)
            NSColor(calibratedRed: 0.24, green: 1, blue: 0.42, alpha: (0.04 + 0.14 * alpha) * scale).setFill()
            rowRect.fill()

            let glitch = NSBezierPath()
            glitch.lineWidth = 1
            outlineColor.withAlphaComponent((0.20 + 0.35 * alpha) * scale).setStroke()
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

        let text = "GAME OVER"
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 24, weight: .bold),
            .foregroundColor: NSColor(calibratedRed: 0.65, green: 1, blue: 0.72, alpha: 1),
            .paragraphStyle: paragraph
        ]
        text.draw(in: NSRect(x: rect.minX, y: rect.midY - 18, width: rect.width, height: 44), withAttributes: attributes)
    }

    private func drawCell(
        kind _: TetrominoKind,
        point: GridPoint,
        in rect: NSRect,
        alpha: CGFloat,
        strokeOnly: Bool = false,
        pulse: CGFloat = 0
    ) {
        guard isRenderable(point) else { return }
        let cell = cellSize(in: rect)
        var cellRect = cellRect(for: point, in: rect, inset: 2)
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

    private func isRenderable(_ point: GridPoint) -> Bool {
        point.x >= 0 && point.x < engine.width && point.y >= -spawnLaneRows && point.y < engine.height
    }

    private func cellRect(for point: GridPoint, in rect: NSRect, inset: CGFloat) -> NSRect {
        let cell = cellSize(in: rect)
        let visualY = point.y + spawnLaneRows
        return NSRect(
            x: rect.minX + CGFloat(point.x) * cell + inset,
            y: rect.maxY - CGFloat(visualY + 1) * cell + inset,
            width: cell - inset * 2,
            height: cell - inset * 2
        )
    }

    private func centerY(forRow row: Int, in rect: NSRect) -> CGFloat {
        let cell = cellSize(in: rect)
        let visualY = row + spawnLaneRows
        return rect.maxY - CGFloat(visualY) * cell - cell / 2
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

    private func trailSegments(from start: ActivePiece, to end: ActivePiece) -> [TrailSegment] {
        let startBlocks = start.blocks.sorted { left, right in
            left.x == right.x ? left.y < right.y : left.x < right.x
        }
        let endBlocks = end.blocks.sorted { left, right in
            left.x == right.x ? left.y < right.y : left.x < right.x
        }
        return zip(startBlocks, endBlocks).map { start, end in
            TrailSegment(x: end.x, startY: min(start.y, end.y), endY: max(start.y, end.y))
        }.filter { $0.endY > $0.startY }
    }

    private func animationScale(for effect: AnimationEffect) -> CGFloat {
        guard animationMode == .subtle else { return 0 }
        return CGFloat(currentAnimationIntensities.value(for: effect)) / 10.0
    }

    private func clearDisabledAnimations() {
        if currentAnimationIntensities.lineClear == 0 {
            lineClearFrames = 0
            clearedRows = []
        }
        if currentAnimationIntensities.hardDrop == 0 {
            hardDropTrailFrames = 0
            hardDropTrail = []
        }
        if currentAnimationIntensities.softDrop == 0 {
            softDropTrailFrames = 0
            softDropTrail = []
        }
        if currentAnimationIntensities.spawn == 0 {
            spawnPulseFrames = 0
        }
        if currentAnimationIntensities.move == 0 {
            movePulseFrames = 0
        }
    }

    private func clearAllAnimations() {
        lineClearFrames = 0
        hardDropTrailFrames = 0
        softDropTrailFrames = 0
        spawnPulseFrames = 0
        movePulseFrames = 0
        clearedRows = []
        hardDropTrail = []
        softDropTrail = []
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
