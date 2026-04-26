import AVFoundation
import Foundation
import MatrixTetrisCore

final class SoundManager {
    private let poolSize = 3
    private var players: [SoundEffect: [AVAudioPlayer]] = [:]
    private var playerIndexes: [SoundEffect: Int] = [:]
    private var lastPlayedAt: [SoundEffect: TimeInterval] = [:]
    private var theme: SoundTheme = .matrixMinimal
    private var enabled = true
    private var masterVolume: Float = 0.6

    init(settings: SettingsState = .defaultState()) {
        rebuildPlayers(for: settings.soundTheme)
        apply(settings)
    }

    func apply(_ settings: SettingsState) {
        let normalized = settings.normalized()
        enabled = normalized.soundEnabled
        masterVolume = Float(normalized.soundVolume) / 10.0
        if theme != normalized.soundTheme {
            rebuildPlayers(for: normalized.soundTheme)
        }
        updatePlayerVolumes()
    }

    func play(_ effect: SoundEffect) {
        guard enabled, masterVolume > 0 else { return }

        let now = ProcessInfo.processInfo.systemUptime
        let minimumInterval = throttleInterval(for: effect)
        if let last = lastPlayedAt[effect], now - last < minimumInterval {
            return
        }
        lastPlayedAt[effect] = now

        guard let pool = players[effect], !pool.isEmpty else { return }
        let index = playerIndexes[effect, default: 0] % pool.count
        playerIndexes[effect] = index + 1

        let player = pool[index]
        if player.isPlaying {
            player.stop()
        }
        player.currentTime = 0
        player.volume = volume(for: effect)
        player.play()
    }

    func playLineClear(count: Int) {
        play(.lineClear(for: count))
    }

    func playTestSequence() {
        let sequence: [(SoundEffect, TimeInterval)] = [
            (.button, 0),
            (.move, 0.12),
            (.rotate, 0.24),
            (.softDrop, 0.38),
            (.hardDrop, 0.54),
            (.lineClearTetris, 0.78)
        ]
        for (effect, delay) in sequence {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.play(effect)
            }
        }
    }

    private func rebuildPlayers(for theme: SoundTheme) {
        self.theme = theme
        players.removeAll()
        playerIndexes.removeAll()

        for effect in SoundEffect.allCases {
            let data = SoundSynthesizer.wavData(for: effect, theme: theme)
            let pool = (0..<poolSize).compactMap { _ -> AVAudioPlayer? in
                guard let player = try? AVAudioPlayer(data: data) else { return nil }
                player.prepareToPlay()
                player.volume = volume(for: effect)
                return player
            }
            players[effect] = pool
        }
    }

    private func updatePlayerVolumes() {
        for (effect, pool) in players {
            for player in pool {
                player.volume = volume(for: effect)
            }
        }
    }

    private func volume(for effect: SoundEffect) -> Float {
        masterVolume * gain(for: effect)
    }

    private func gain(for effect: SoundEffect) -> Float {
        switch effect {
        case .move:
            theme == .matrixMinimal ? 0.34 : 0.42
        case .softDrop:
            theme == .matrixMinimal ? 0.32 : 0.38
        case .button, .dropdownOpen, .dropdownClose:
            theme == .matrixMinimal ? 0.42 : 0.48
        case .hardDrop, .lineClearTetris, .gameOver:
            theme == .matrixMinimal ? 0.68 : 0.82
        case .highScore:
            theme == .matrixMinimal ? 0.72 : 0.86
        default:
            theme == .matrixMinimal ? 0.54 : 0.66
        }
    }

    private func throttleInterval(for effect: SoundEffect) -> TimeInterval {
        switch effect {
        case .move:
            0.045
        case .softDrop:
            0.085
        case .button:
            0.05
        default:
            0
        }
    }
}

private enum SoundSynthesizer {
    private static let sampleRate = 22_050

    static func wavData(for effect: SoundEffect, theme: SoundTheme) -> Data {
        let profile = profile(for: effect, theme: theme)
        let sampleCount = max(1, Int(profile.duration * Double(sampleRate)))
        var samples: [Float] = Array(repeating: 0, count: sampleCount)
        var noiseState = UInt64(bitPattern: Int64(effect.rawValue.hashValue)) &* 1_103_515_245

        for index in 0..<sampleCount {
            let time = Double(index) / Double(sampleRate)
            var value: Float = 0

            for layer in profile.layers {
                guard time >= layer.start, time <= layer.start + layer.duration else { continue }
                let local = time - layer.start
                let progress = local / max(layer.duration, 0.001)
                let frequency = layer.startFrequency + (layer.endFrequency - layer.startFrequency) * progress
                let phase = 2.0 * Double.pi * frequency * local
                let waveValue: Double
                switch layer.wave {
                case .sine:
                    waveValue = sin(phase)
                case .square:
                    waveValue = sin(phase) >= 0 ? 1 : -1
                case .triangle:
                    waveValue = asin(sin(phase)) * 2.0 / Double.pi
                }
                value += Float(waveValue) * layer.gain * envelope(progress)
            }

            if profile.noise > 0 {
                noiseState = noiseState &* 6_364_136_223_846_793_005 &+ 1
                let noise = Float(Int((noiseState >> 32) & 0xffff) - 32_768) / 32_768.0
                let decay = Float(1.0 - min(1, time / max(profile.duration, 0.001)))
                value += noise * profile.noise * decay
            }

            if profile.bitCrush {
                value = (value * 12).rounded() / 12
            }
            samples[index] = max(-1, min(1, value))
        }

        return wavData(from: samples)
    }

    private static func envelope(_ progress: Double) -> Float {
        let attack = min(1, progress / 0.08)
        let release = pow(max(0, 1 - progress), 1.45)
        return Float(min(attack, release))
    }

    private static func profile(for effect: SoundEffect, theme: SoundTheme) -> SoundProfile {
        switch theme {
        case .matrixMinimal:
            return matrixProfile(for: effect)
        case .arcadePunchy:
            return arcadeProfile(for: effect)
        }
    }

    private static func matrixProfile(for effect: SoundEffect) -> SoundProfile {
        switch effect {
        case .move:
            return SoundProfile(0.045, [.init(0, 0.04, 520, 760, 0.16, .triangle)], 0.025, true)
        case .rotate:
            return SoundProfile(0.075, [.init(0, 0.07, 740, 1_120, 0.20, .sine), .init(0.015, 0.045, 1_480, 920, 0.08, .triangle)], 0.035, true)
        case .softDrop:
            return SoundProfile(0.085, [.init(0, 0.08, 360, 170, 0.16, .triangle)], 0.05, true)
        case .hardDrop:
            return SoundProfile(0.16, [.init(0, 0.13, 150, 68, 0.30, .sine), .init(0.015, 0.09, 840, 260, 0.12, .triangle)], 0.12, true)
        case .lock:
            return SoundProfile(0.06, [.init(0, 0.045, 280, 280, 0.22, .square), .init(0.01, 0.035, 1_200, 820, 0.07, .sine)], 0.025, true)
        case .lineClearSingle:
            return SoundProfile(0.18, [.init(0, 0.16, 520, 860, 0.19, .sine), .init(0.04, 0.09, 1_060, 1_360, 0.08, .triangle)], 0.05, true)
        case .lineClearDouble:
            return SoundProfile(0.22, [.init(0, 0.19, 500, 980, 0.22, .sine), .init(0.04, 0.12, 1_100, 1_560, 0.10, .triangle)], 0.055, true)
        case .lineClearTriple:
            return SoundProfile(0.27, [.init(0, 0.22, 480, 1_120, 0.25, .sine), .init(0.05, 0.14, 1_180, 1_760, 0.12, .triangle)], 0.06, true)
        case .lineClearTetris:
            return SoundProfile(0.48, [
                .init(0.00, 0.075, 520, 760, 0.16, .triangle),
                .init(0.075, 0.075, 700, 980, 0.17, .triangle),
                .init(0.150, 0.075, 920, 1_260, 0.18, .triangle),
                .init(0.225, 0.085, 1_180, 1_620, 0.19, .triangle),
                .init(0.285, 0.175, 760, 2_220, 0.20, .sine),
                .init(0.315, 0.120, 1_520, 2_640, 0.10, .triangle)
            ], 0.09, true)
        case .gameOver:
            return SoundProfile(0.42, [.init(0, 0.38, 320, 88, 0.28, .sine), .init(0.05, 0.26, 640, 160, 0.13, .triangle)], 0.10, true)
        case .pause:
            return SoundProfile(0.11, [.init(0, 0.09, 660, 420, 0.16, .triangle)], 0.025, true)
        case .resume:
            return SoundProfile(0.11, [.init(0, 0.09, 420, 720, 0.17, .triangle)], 0.025, true)
        case .highScore:
            return SoundProfile(0.38, [.init(0, 0.11, 620, 620, 0.15, .sine), .init(0.10, 0.11, 930, 930, 0.15, .sine), .init(0.20, 0.15, 1_240, 1_520, 0.19, .triangle)], 0.035, true)
        case .dropdownOpen:
            return SoundProfile(0.12, [.init(0, 0.10, 360, 760, 0.15, .triangle)], 0.025, true)
        case .dropdownClose:
            return SoundProfile(0.10, [.init(0, 0.08, 760, 340, 0.13, .triangle)], 0.025, true)
        case .button:
            return SoundProfile(0.055, [.init(0, 0.045, 820, 1_080, 0.14, .triangle)], 0.025, true)
        }
    }

    private static func arcadeProfile(for effect: SoundEffect) -> SoundProfile {
        switch effect {
        case .move:
            return SoundProfile(0.04, [.init(0, 0.035, 420, 420, 0.18, .square)], 0.005, false)
        case .rotate:
            return SoundProfile(0.07, [.init(0, 0.055, 720, 1_080, 0.24, .square)], 0.005, false)
        case .softDrop:
            return SoundProfile(0.075, [.init(0, 0.065, 520, 240, 0.20, .square)], 0.01, false)
        case .hardDrop:
            return SoundProfile(0.15, [.init(0, 0.12, 180, 90, 0.36, .square), .init(0.02, 0.08, 620, 260, 0.18, .square)], 0.05, false)
        case .lock:
            return SoundProfile(0.055, [.init(0, 0.04, 240, 240, 0.28, .square), .init(0.012, 0.03, 900, 900, 0.12, .square)], 0.01, false)
        case .lineClearSingle:
            return SoundProfile(0.16, [.init(0, 0.12, 540, 860, 0.24, .square)], 0.01, false)
        case .lineClearDouble:
            return SoundProfile(0.20, [.init(0, 0.15, 520, 1_020, 0.27, .square)], 0.012, false)
        case .lineClearTriple:
            return SoundProfile(0.24, [.init(0, 0.18, 500, 1_180, 0.30, .square)], 0.014, false)
        case .lineClearTetris:
            return SoundProfile(0.46, [
                .init(0.00, 0.065, 420, 420, 0.20, .square),
                .init(0.070, 0.065, 560, 560, 0.21, .square),
                .init(0.140, 0.065, 700, 700, 0.22, .square),
                .init(0.210, 0.075, 940, 940, 0.24, .square),
                .init(0.270, 0.155, 620, 1_720, 0.25, .square),
                .init(0.305, 0.105, 1_240, 2_240, 0.14, .square)
            ], 0.028, false)
        case .gameOver:
            return SoundProfile(0.38, [.init(0, 0.32, 260, 70, 0.34, .square)], 0.04, false)
        case .pause:
            return SoundProfile(0.10, [.init(0, 0.08, 560, 360, 0.20, .square)], 0.005, false)
        case .resume:
            return SoundProfile(0.10, [.init(0, 0.08, 360, 620, 0.21, .square)], 0.005, false)
        case .highScore:
            return SoundProfile(0.36, [.init(0, 0.09, 660, 660, 0.20, .square), .init(0.09, 0.09, 990, 990, 0.20, .square), .init(0.18, 0.13, 1_320, 1_640, 0.26, .square)], 0.008, false)
        case .dropdownOpen:
            return SoundProfile(0.10, [.init(0, 0.08, 420, 760, 0.18, .square)], 0.005, false)
        case .dropdownClose:
            return SoundProfile(0.10, [.init(0, 0.08, 760, 420, 0.17, .square)], 0.005, false)
        case .button:
            return SoundProfile(0.05, [.init(0, 0.04, 780, 940, 0.17, .square)], 0.005, false)
        }
    }

    private static func wavData(from samples: [Float]) -> Data {
        var data = Data()
        let byteRate = sampleRate * 2
        let dataSize = samples.count * 2

        data.appendASCII("RIFF")
        data.appendUInt32LE(UInt32(36 + dataSize))
        data.appendASCII("WAVE")
        data.appendASCII("fmt ")
        data.appendUInt32LE(16)
        data.appendUInt16LE(1)
        data.appendUInt16LE(1)
        data.appendUInt32LE(UInt32(sampleRate))
        data.appendUInt32LE(UInt32(byteRate))
        data.appendUInt16LE(2)
        data.appendUInt16LE(16)
        data.appendASCII("data")
        data.appendUInt32LE(UInt32(dataSize))

        for sample in samples {
            let scaled = Int16(max(-1, min(1, sample)) * Float(Int16.max))
            data.appendInt16LE(scaled)
        }
        return data
    }
}

private struct SoundProfile {
    var duration: Double
    var layers: [ToneLayer]
    var noise: Float
    var bitCrush: Bool

    init(_ duration: Double, _ layers: [ToneLayer], _ noise: Float, _ bitCrush: Bool) {
        self.duration = duration
        self.layers = layers
        self.noise = noise
        self.bitCrush = bitCrush
    }
}

private struct ToneLayer {
    var start: Double
    var duration: Double
    var startFrequency: Double
    var endFrequency: Double
    var gain: Float
    var wave: Wave

    init(_ start: Double, _ duration: Double, _ startFrequency: Double, _ endFrequency: Double, _ gain: Float, _ wave: Wave) {
        self.start = start
        self.duration = duration
        self.startFrequency = startFrequency
        self.endFrequency = endFrequency
        self.gain = gain
        self.wave = wave
    }
}

private enum Wave {
    case sine
    case square
    case triangle
}

private extension Data {
    mutating func appendASCII(_ string: String) {
        append(contentsOf: string.utf8)
    }

    mutating func appendUInt16LE(_ value: UInt16) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) {
            append(contentsOf: $0)
        }
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) {
            append(contentsOf: $0)
        }
    }

    mutating func appendInt16LE(_ value: Int16) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) {
            append(contentsOf: $0)
        }
    }
}
