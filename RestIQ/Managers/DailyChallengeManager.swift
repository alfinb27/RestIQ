//
//  DailyChallengeManager.swift
//  RestIQ
//
//  Created by Alfin Baby on 12/10/25.
//

import Foundation

class DailyChallengeManager {
    static let shared = DailyChallengeManager()

    private let calendar = Calendar.current

    func dailySeed() -> Int {
        let date = calendar.startOfDay(for: Date())
        return date.hashValue
    }

    func generatePuzzle(for level: String) -> PuzzleEngine {
        let baseSize: Int
        switch level {
        case "Easy": baseSize = 6
        case "Medium": baseSize = 7
        case "Hard": baseSize = 8
        case "Expert": baseSize = 9
        default: baseSize = 6
        }

        let seed = dailySeed() + baseSize
        return generateSeededPuzzle(size: baseSize, seed: seed)
    }

    private func generateSeededPuzzle(size: Int, seed: Int) -> PuzzleEngine {
        var rng = SeededRandomNumberGenerator(seed: UInt64(abs(seed)))
        let engine = PuzzleEngine(size: size)

        let prefillCount = Int.random(in: 1...2, using: &rng)
        for _ in 0..<prefillCount {
            let r = Int.random(in: 0..<size, using: &rng)
            let c = Int.random(in: 0..<size, using: &rng)
            engine.toggleQueen(atRow: r, column: c)
        }

        return engine
    }
}

