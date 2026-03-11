//
//  DailyChallengeManager.swift
//  RestIQ
//
//  Fixed: engine.snapshot() is no longer async — removed unnecessary await.
//

import Foundation

@MainActor
final class DailyChallengeManager {
    static let shared = DailyChallengeManager()
    private let calendar = Calendar.current

    private var cachedEngines: [String: QueensPuzzleEngine] = [:]
    private var cachedDayKey: String?

    private init() {}

    private func dayKey(for date: Date = Date()) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let y = components.year ?? 1970
        let m = components.month ?? 1
        let d = components.day ?? 1
        return String(format: "%04d%02d%02d", y, m, d)
    }

    private func dailySeed(size: Int, levelKey: String) -> UInt64 {
        let key = dayKey() + ":\(size):\(levelKey)"
        var hash: UInt64 = 0xcbf29ce484222325
        let prime: UInt64 = 0x100000001b3
        for b in key.utf8 {
            hash ^= UInt64(b)
            hash = hash &* prime
        }
        return hash
    }

    func generateDailyPuzzle(for level: String) async -> QueensPuzzleEngine? {
        let today = dayKey()
        let debug = DebugConfig.shared.debugMode

        if cachedDayKey != today && !debug {
            cachedEngines.removeAll()
            cachedDayKey = today
        }

        if let existing = cachedEngines[level], !debug {
            return existing
        }

        let size: Int
        let difficulty: Difficulty
        switch level {
        case "Easy":   size = 6; difficulty = .easy
        case "Medium": size = 7; difficulty = .medium
        case "Hard":   size = 8; difficulty = .hard
        case "Expert": size = 9; difficulty = .expert
        default:       size = 6; difficulty = .easy
        }

        let seed: UInt64 = debug
            ? UInt64.random(in: 0..<UInt64.max)
            : dailySeed(size: size, levelKey: level)

        guard let engine = await QueensPuzzleEngine.generate(
            size: size,
            difficulty: difficulty,
            seed: seed
        ) else { return nil }

        cachedEngines[level] = engine
        return engine
    }
}
