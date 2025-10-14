//
//  DailyChallengeManager.swift
//  RestIQ
//
//  Created by Alfin Baby on 12/10/25.
//

import Foundation

struct Coord: Hashable {
    let r: Int
    let c: Int
}

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

        let seed = UInt64(abs(dailySeed() + baseSize))
        let regionMap = generateRegionMap(size: baseSize, seed: seed)
        return PuzzleEngine(size: baseSize, regionMap: regionMap)
    }

    // MARK: - Contiguous Region Generator (final)
    private func generateRegionMap(size: Int, seed: UInt64) -> [[Int]] {
        var rng = SeededRandomNumberGenerator(seed: seed)
        var map = Array(repeating: Array(repeating: -1, count: size), count: size)
        let totalRegions = size
        let totalCells = size * size
        let targetRegionSize = totalCells / totalRegions

        // Step 1: place N random seeds
        var allCells = [Coord]()
        for r in 0..<size { for c in 0..<size { allCells.append(Coord(r: r, c: c)) } }
        allCells.shuffle(using: &rng)
        let seeds = Array(allCells.prefix(totalRegions))
        for (id, s) in seeds.enumerated() { map[s.r][s.c] = id }

        // Step 2: fair round-robin growth
        var regionCells: [Int: [Coord]] = [:]
        for (id, coord) in seeds.enumerated() { regionCells[id] = [coord] }

        var unfilled = Set(allCells.filter { !seeds.contains($0) })

        while !unfilled.isEmpty {
            for regionID in 0..<totalRegions {
                guard let currentCells = regionCells[regionID],
                      currentCells.count < targetRegionSize else { continue }

                let frontier = currentCells
                    .flatMap { neighbors(of: $0, size: size) }
                    .filter { unfilled.contains($0) }

                guard let next = frontier.randomElement(using: &rng) else { continue }

                map[next.r][next.c] = regionID
                regionCells[regionID, default: []].append(next)
                unfilled.remove(next)

                if unfilled.isEmpty { break }
            }

            if unfilled.count < size {
                for cell in unfilled {
                    let neighbors = self.neighbors(of: cell, size: size)
                        .compactMap { map[$0.r][$0.c] }
                    if let neighborID = neighbors.randomElement(using: &rng) {
                        map[cell.r][cell.c] = neighborID
                        regionCells[neighborID, default: []].append(cell)
                    } else {
                        let fallback = Int.random(in: 0..<totalRegions, using: &rng)
                        map[cell.r][cell.c] = fallback
                        regionCells[fallback, default: []].append(cell)
                    }
                }
                unfilled.removeAll()
            }
        }

        // Step 3–4
        map = enforceConnectivity(map: map, totalRegions: totalRegions, size: size)
        map = normalizeRegionCount(map: map, totalRegions: totalRegions, size: size)
        return map
    }

    // MARK: - Helpers
    private func neighbors(of cell: Coord, size: Int) -> [Coord] {
        [(1,0),(-1,0),(0,1),(0,-1)]
            .map { Coord(r: cell.r + $0.0, c: cell.c + $0.1) }
            .filter { $0.r >= 0 && $0.r < size && $0.c >= 0 && $0.c < size }
    }

    private func countRegion(_ map: [[Int]], id: Int) -> Int {
        map.flatMap { $0 }.filter { $0 == id }.count
    }

    // MARK: - Connectivity
    private func enforceConnectivity(map: [[Int]], totalRegions: Int, size: Int) -> [[Int]] {
        var map = map
        for regionID in 0..<totalRegions {
            var visited = Set<Coord>()
            var groups: [[Coord]] = []

            for r in 0..<size {
                for c in 0..<size where map[r][c] == regionID && !visited.contains(Coord(r: r, c: c)) {
                    var queue = [Coord(r: r, c: c)]
                    var group: [Coord] = []
                    visited.insert(Coord(r: r, c: c))

                    while !queue.isEmpty {
                        let cur = queue.removeFirst()
                        group.append(cur)
                        for n in neighbors(of: cur, size: size)
                        where map[n.r][n.c] == regionID && !visited.contains(n) {
                            visited.insert(n)
                            queue.append(n)
                        }
                    }
                    groups.append(group)
                }
            }

            // merge fragments
            if groups.count > 1 {
                let mainIndex = groups.indices.max(by: { groups[$0].count < groups[$1].count }) ?? 0
                for (idx, group) in groups.enumerated() where idx != mainIndex {
                    for cell in group {
                        let neighbor = neighbors(of: cell, size: size)
                            .compactMap { map[$0.r][$0.c] }
                            .filter { $0 != regionID }
                            .randomElement()
                        map[cell.r][cell.c] = neighbor ?? regionID
                    }
                }
            }
        }
        return map
    }

    // MARK: - Normalize Region Count
    private func normalizeRegionCount(map: [[Int]], totalRegions: Int, size: Int) -> [[Int]] {
        var map = map
        var unique = Array(Set(map.flatMap { $0 })).sorted()

        while unique.count > totalRegions {
            if let smallest = unique.min(by: { countRegion(map, id: $0) < countRegion(map, id: $1) }) {
                outer: for r in 0..<size {
                    for c in 0..<size where map[r][c] == smallest {
                        if let neighbor = neighbors(of: Coord(r: r, c: c), size: size)
                            .compactMap({ map[$0.r][$0.c] })
                            .filter({ $0 != smallest })
                            .first {
                            map[r][c] = neighbor
                            break outer
                        }
                    }
                }
            }
            unique = Array(Set(map.flatMap { $0 })).sorted()
        }

        while unique.count < totalRegions {
            if let largest = unique.max(by: { countRegion(map, id: $0) < countRegion(map, id: $1) }) {
                var candidates = [Coord]()
                for r in 0..<size {
                    for c in 0..<size where map[r][c] == largest {
                        candidates.append(Coord(r: r, c: c))
                    }
                }
                guard candidates.count > 2 else { break }
                let splitCount = candidates.count / 2
                for cell in candidates.prefix(splitCount) {
                    map[cell.r][cell.c] = unique.count
                }
            }
            unique = Array(Set(map.flatMap { $0 })).sorted()
        }

        let remap = Dictionary(unique.enumerated().map { ($1, $0) },
                               uniquingKeysWith: { first, _ in first })
        for r in 0..<size {
            for c in 0..<size {
                map[r][c] = remap[map[r][c]] ?? 0
            }
        }
        return map
    }
}
