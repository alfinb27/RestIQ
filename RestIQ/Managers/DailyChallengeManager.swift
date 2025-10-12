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
        return generateSeededPuzzle(size: baseSize, seed: seed, level: level)
    }

    // MARK: - Region generation

    private func generateRegionMap(size: Int, seed: UInt64, level: String) -> [[Int]] {
        let (minRegionSize, maxRegionSize): (Int, Int)
        switch level {
        case "Easy":   (minRegionSize, maxRegionSize) = (2, 4)
        case "Medium": (minRegionSize, maxRegionSize) = (2, 5)
        case "Hard":   (minRegionSize, maxRegionSize) = (2, 6)
        case "Expert": (minRegionSize, maxRegionSize) = (3, 6)
        default:       (minRegionSize, maxRegionSize) = (2, 4)
        }

        var rng = SeededRandomNumberGenerator(seed: seed)
        var map = Array(repeating: Array(repeating: -1, count: size), count: size)
        var nextRegionId = 0

        func neighbors(of r: Int, c: Int) -> [(Int,Int)] {
            [(1,0),(-1,0),(0,1),(0,-1)]
                .map { (r + $0.0, c + $0.1) }
                .filter { $0.0 >= 0 && $0.0 < size && $0.1 >= 0 && $0.1 < size }
        }

        // Coordinates shuffled deterministically
        var all = [(Int,Int)]()
        for r in 0..<size { for c in 0..<size { all.append((r,c)) } }
        all.shuffle(using: &rng)

        for (startR, startC) in all {
            if map[startR][startC] != -1 { continue }

            nextRegionId += 1
            let regionId = nextRegionId
            let target = Int.random(in: minRegionSize...maxRegionSize, using: &rng)

            var queue: [(Int,Int)] = [(startR,startC)]
            var regionCells: [(Int,Int)] = [(startR,startC)]
            map[startR][startC] = regionId

            while !queue.isEmpty && regionCells.count < target {
                let (r,c) = queue.removeFirst()
                var shuffled = neighbors(of: r, c: c)
                shuffled.shuffle(using: &rng)
                for (nr,nc) in shuffled where map[nr][nc] == -1 {
                    map[nr][nc] = regionId
                    regionCells.append((nr,nc))
                    queue.append((nr,nc))
                    if regionCells.count >= target { break }
                }
            }
        }

        // Fill any gaps with nearest region
        for r in 0..<size {
            for c in 0..<size where map[r][c] == -1 {
                let neigh = neighbors(of: r, c: c)
                    .compactMap { map[$0.0][$0.1] }
                    .randomElement(using: &rng)
                map[r][c] = neigh ?? (nextRegionId + 1)
            }
        }

        // Normalize region IDs
        let unique = Array(Set(map.flatMap { $0 })).sorted()
        var remap = [Int:Int]()
        for (newId, oldId) in unique.enumerated() { remap[oldId] = newId }
        for r in 0..<size {
            for c in 0..<size {
                map[r][c] = remap[map[r][c]] ?? 0
            }
        }

        return map
    }

    private func generateSeededPuzzle(size: Int, seed: Int, level: String) -> PuzzleEngine {
        let regionMap = generateRegionMap(size: size, seed: UInt64(abs(seed)), level: level)
        let engine = PuzzleEngine(size: size, regionMap: regionMap)

        // Optional: deterministic prefill
        var rng = SeededRandomNumberGenerator(seed: UInt64(abs(seed)) ^ 0x9E3779B97F4A7C15)
        if Bool.random(using: &rng) {
            let r = Int.random(in: 0..<size, using: &rng)
            let c = Int.random(in: 0..<size, using: &rng)
            engine.tapCell(row: r, col: c)
        }

        return engine
    }
}
