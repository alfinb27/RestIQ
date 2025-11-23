//
//  DailyChallengeManager.swift
//  RestIQ
//
//  Updated to use QueensPuzzleEngineV2
//  Created: ChatGPT
//

import Foundation

@MainActor
final class DailyChallengeManager {
    static let shared = DailyChallengeManager()
    private let calendar = Calendar.current

    // Cache per level for the current day
    private var cachedEngines: [String: QueensPuzzleEngineV2] = [:] // level → engine
    private var cachedDayKey: String?

    private init() {}

    private func dayKey(for date: Date = Date()) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let y = components.year ?? 1970
        let m = components.month ?? 1
        let d = components.day ?? 1
        return String(format: "%04d%02d%02d", y, m, d)
    }

    /// Deterministic stable seed for daily puzzles.
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

    /// Map level to a preferred size range and difficulty for the new engine.
    private func sizeAndDifficulty(for level: String) -> (Int, DifficultyV2) {
        switch level {
        case "Easy": return (6, .easy)
        case "Medium": return (7, .medium)
        case "Hard": return (8, .hard)
        case "Expert": return (9, .expert)
        default: return (6, .easy)
        }
    }

    /// Generate or return a cached daily puzzle for a level using QueensPuzzleEngineV2.
    func generateDailyPuzzle(for level: String) async -> QueensPuzzleEngineV2? {
        let today = dayKey()
        let debug = await MainActor.run { DebugConfig.shared.debugMode }

        if cachedDayKey != today && !debug {
            cachedEngines.removeAll()
            cachedDayKey = today
        }

        if let existing = cachedEngines[level], !debug {
            return existing
        }

        let (size, difficulty) = sizeAndDifficulty(for: level)
        let seed: UInt64
        if debug {
            seed = UInt64.random(in: 0..<UInt64.max)
        } else {
            seed = dailySeed(size: size, levelKey: level)
        }

        // Try several seeded attempts, then fall back to unseeded generation.
        let maxAttempts = 6
        for attempt in 0..<maxAttempts {
            let attemptSeed = debug ? UInt64.random(in: 0..<UInt64.max) : seed &+ UInt64(attempt)
            if let engine = await QueensPuzzleEngineV2.generate(size: size, difficulty: difficulty, seed: attemptSeed, attempts: 300) {
                // final validation (sanity): canonical solution must touch each region exactly once
                let canonical = await engine.getCanonicalSolution()
                guard canonical.count == engine.size else { continue }

                var regionSeen = Set<Int>()
                var ok = true
                for (r, c) in canonical {
                    if r < 0 || r >= engine.size || c < 0 || c >= engine.size { ok = false; break }
                    regionSeen.insert(engine.regionMap[r][c])
                }
                if !ok { continue }
                if regionSeen.count != engine.size { continue }

                cachedEngines[level] = engine
                return engine
            }
        }

        // fallback: try one non-deterministic generation
        if let fallback = await QueensPuzzleEngineV2.generate(size: size, difficulty: difficulty, seed: nil, attempts: 400) {
            cachedEngines[level] = fallback
            return fallback
        }

        return nil
    }
}
