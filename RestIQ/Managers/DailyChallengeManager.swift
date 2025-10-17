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
    private var cachedEngines: [String: QueensPuzzleEngine] = [:] // level → engine

    func dailySeed() -> UInt64 {
        let date = calendar.startOfDay(for: Date())
        return UInt64(abs(date.hashValue))
    }

    func generateDailyPuzzle(for level: String) async -> QueensPuzzleEngine? {
        if let existing = cachedEngines[level] { return existing }

        let size: Int
        let difficulty: Difficulty
        switch level {
        case "Easy": size = 6; difficulty = .easy
        case "Medium": size = 8; difficulty = .medium
        case "Hard": size = 9; difficulty = .hard
        case "Expert": size = 10; difficulty = .expert
        default: size = 6; difficulty = .easy
        }

        let seed = dailySeed() &+ UInt64(size * 7919)
        guard let engine = await QueensPuzzleEngine.generate(size: size, difficulty: difficulty, seed: seed) else {
            return nil
        }
        cachedEngines[level] = engine
        return engine
    }
}
