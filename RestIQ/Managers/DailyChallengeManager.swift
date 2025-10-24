//
//  DailyChallengeManager.swift
//  RestIQ
//
//  Created by Alfin Baby on 12/10/25.
//  Updated: Stable day key + cache invalidation at midnight.
//

import Foundation

@MainActor
final class DailyChallengeManager {
    static let shared = DailyChallengeManager()
    private let calendar = Calendar.current

    // Cache per level for the current day
    private var cachedEngines: [String: QueensPuzzleEngine] = [:] // level → engine
    private var cachedDayKey: String?

    private init() {}

    /// A stable string key for the "day" in the user's current calendar.
    private func dayKey(for date: Date = Date()) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let y = components.year ?? 1970
        let m = components.month ?? 1
        let d = components.day ?? 1
        return String(format: "%04d%02d%02d", y, m, d) // e.g. 20251022
    }

    /// Stable seed derived from dayKey + grid size for variety across levels.
    private func dailySeed(size: Int, levelKey: String) -> UInt64 {
        let key = dayKey() + ":\(size):\(levelKey)"
        // Simple 64-bit hash (FNV-1a-ish)
        var hash: UInt64 = 0xcbf29ce484222325
        let prime: UInt64 = 0x100000001b3
        for b in key.utf8 {
            hash ^= UInt64(b)
            hash = hash &* prime
        }
        return hash
    }

    /// Generate or return a cached daily puzzle for a level.
    func generateDailyPuzzle(for level: String) async -> QueensPuzzleEngine? {
        // Invalidate cache if the day changed
        let today = dayKey()
        let debug = await MainActor.run { DebugConfig.shared.debugMode }

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
        case "Easy": size = 6; difficulty = .easy
        case "Medium": size = 7; difficulty = .medium
        case "Hard": size = 8; difficulty = .hard
        case "Expert": size = 9; difficulty = .expert
        default: size = 6; difficulty = .easy
        }

        // Determine seed
        let seed: UInt64
        if debug {
            // Random seed in debug mode so puzzle changes each call
            seed = UInt64.random(in: 0..<UInt64.max)
        } else {
            // Stable daily seed otherwise
            seed = dailySeed(size: size, levelKey: level)
        }

        // Generate puzzle
        guard let engine = await QueensPuzzleEngine.generate(
            size: size,
            difficulty: difficulty,
            seed: seed
        ) else {
            return nil
        }

        cachedEngines[level] = engine
        return engine
    }
}
