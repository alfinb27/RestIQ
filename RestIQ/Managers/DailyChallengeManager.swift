//
//  DailyChallengeManager.swift
//  RestIQ
//
//  Created by Alfin Baby on 12/10/25.
//

import Foundation

@MainActor
final class DailyChallengeManager {
    static let shared = DailyChallengeManager()
    private let calendar = Calendar.current

    /// Deterministic seed derived from the current day
    func dailySeed() -> UInt64 {
        let date = calendar.startOfDay(for: Date())
        return UInt64(abs(date.hashValue))
    }

    /// Async generator for the day's Queens puzzle
    func generateDailyPuzzle(for level: String) async -> QueensPuzzleEngine? {
        let size: Int
        let difficulty: Difficulty
        switch level {
        case "Easy": size = 6; difficulty = .easy
        case "Medium": size = 7; difficulty = .medium
        case "Hard": size = 8; difficulty = .hard
        case "Expert": size = 9; difficulty = .expert
        default: size = 6; difficulty = .easy
        }

        let seed = dailySeed() &+ UInt64(size * 7919) // stable prime offset
        let engine = await QueensPuzzleEngine.generate(size: size, difficulty: difficulty, seed: seed)
        return engine
    }

    /// Optional helper to preload puzzle generation in the background
    func preloadDailyPuzzle(level: String) {
        Task.detached {
            _ = await self.generateDailyPuzzle(for: level)
        }
    }
}
