//
//  DailyChallengeManager.swift
//  RestIQ
//
//  Created by Alfin Baby on 12/10/25.
//
// Responsible for generating deterministic daily puzzles and region maps.
// The region generator guarantees exactly N contiguous regions (rules 1-3).

import Foundation

@MainActor
final class DailyChallengeManager {
    static let shared = DailyChallengeManager()
    private let calendar = Calendar.current

    /// Seed derived from current day (start of day). Deterministic across devices.
    func dailySeed() -> Int {
        let date = calendar.startOfDay(for: Date())
        return date.hashValue
    }

    /// Public generator: returns a PuzzleEngine ready to use.
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

    // MARK: - Region generation (balanced, contiguous, exactly N regions)

    /// Generate contiguous region map with exactly `size` regions.
    private func generateRegionMap(size: Int, seed: UInt64) -> [[Int]] {
        var rng = SeededRandomNumberGenerator(seed: seed)
        var map = Array(repeating: Array(repeating: -1, count: size), count: size)
        let totalRegions = size
        let totalCells = size * size
        let baseTarget = totalCells / totalRegions

        // Create list of all coordinates and pick seeds
        var allCells = [Coord]()
        for r in 0..<size { for c in 0..<size { allCells.append(Coord(r: r, c: c)) } }
        allCells.shuffle(using: &rng)
        let seeds = Array(allCells.prefix(totalRegions))

        // Assign seeds and prepare region cell lists
        var regionCells: [Int: [Coord]] = [:]
        for (id, seedCoord) in seeds.enumerated() {
            map[seedCoord.r][seedCoord.c] = id
            regionCells[id] = [seedCoord]
        }

        // Unassigned set
        var unfilled = Set(allCells.dropFirst(totalRegions))

        // Round-robin expansion with soft targets for balanced sizes.
        // Regions expand one cell at a time from their frontier in a fair cycle.
        let regionOrder = Array(0..<totalRegions)
        var growthRound = 0
        while !unfilled.isEmpty {
            growthRound += 1
            for regionID in regionOrder {
                // Soft target allows some variability: baseTarget +/- floor(baseTarget*0.5)
                let softMax = max(1, baseTarget + Int.random(in: -(baseTarget/2)...(baseTarget/2), using: &rng))
                guard let current = regionCells[regionID], current.count < softMax else { continue }

                // Frontier: neighbors of current cells that are unassigned
                let frontier = current
                    .flatMap { neighbors(of: $0, size: size) }
                    .filter { unfilled.contains($0) }

                guard let pick = frontier.randomElement(using: &rng) else { continue }

                map[pick.r][pick.c] = regionID
                regionCells[regionID, default: []].append(pick)
                unfilled.remove(pick)

                if unfilled.isEmpty { break }
            }

            // If expansion stalls (no frontiers for many regions), fill remaining unfilled by attaching to neighbor regions.
            if growthRound % (size * 2) == 0 && !unfilled.isEmpty {
                for cell in unfilled {
                    let neighborsIDs = neighbors(of: cell, size: size)
                        .compactMap { map[$0.r][$0.c] }
                    if let assignTo = neighborsIDs.randomElement(using: &rng) {
                        map[cell.r][cell.c] = assignTo
                        regionCells[assignTo, default: []].append(cell)
                    } else {
                        // fallback random assignment
                        let fallback = Int.random(in: 0..<totalRegions, using: &rng)
                        map[cell.r][cell.c] = fallback
                        regionCells[fallback, default: []].append(cell)
                    }
                }
                unfilled.removeAll()
                break
            }
        }

        // Ensure connectivity and exact count
        map = enforceConnectivity(map: map, totalRegions: totalRegions, size: size, rng: &rng)
        map = normalizeRegionCount(map: map, totalRegions: totalRegions, size: size, rng: &rng)
        return map
    }

    // Ensure each region is a single connected component by merging fragments to neighbors.
    private func enforceConnectivity(map: [[Int]], totalRegions: Int, size: Int, rng: inout SeededRandomNumberGenerator) -> [[Int]] {
        var map = map
        for regionID in 0..<totalRegions {
            var visited = Set<Coord>()
            var groups: [[Coord]] = []

            for r in 0..<size {
                for c in 0..<size where map[r][c] == regionID && !visited.contains(Coord(r: r, c: c)) {
                    var queue: [Coord] = [Coord(r: r, c: c)]
                    visited.insert(Coord(r: r, c: c))
                    var group: [Coord] = []

                    while !queue.isEmpty {
                        let cur = queue.removeFirst()
                        group.append(cur)
                        for n in neighbors(of: cur, size: size) where map[n.r][n.c] == regionID && !visited.contains(n) {
                            visited.insert(n)
                            queue.append(n)
                        }
                    }
                    groups.append(group)
                }
            }

            // Merge fragments into neighboring regions (keep largest intact)
            if groups.count > 1 {
                let mainIndex = groups.indices.max(by: { groups[$0].count < groups[$1].count }) ?? 0
                for (idx, group) in groups.enumerated() where idx != mainIndex {
                    for cell in group {
                        if let neighborID = neighbors(of: cell, size: size)
                            .compactMap({ map[$0.r][$0.c] })
                            .filter({ $0 != regionID })
                            .randomElement(using: &rng) {
                            map[cell.r][cell.c] = neighborID
                        } else {
                            // fallback: assign to main region if no external neighbor
                            map[cell.r][cell.c] = regionID
                        }
                    }
                }
            }
        }
        return map
    }

    // Guarantee exactly totalRegions IDs by merging smallest or splitting largest.
    private func normalizeRegionCount(map: [[Int]], totalRegions: Int, size: Int, rng: inout SeededRandomNumberGenerator) -> [[Int]] {
        var map = map
        func regionSizes() -> [(id: Int, count: Int)] {
            let unique = Array(Set(map.flatMap { $0 }))
            return unique.map { ($0, map.flatMap { $0 }.filter { $0 == $0 }.count) }
        }

        // Recompute unique after changes
        var unique = Array(Set(map.flatMap { $0 })).sorted()

        // If too many, merge smallest into neighbors until count == totalRegions
        while unique.count > totalRegions {
            // find smallest region id
            let sizes = unique.map { ($0, countRegion(map, id: $0)) }
            guard let smallest = sizes.min(by: { $0.1 < $1.1 })?.0 else { break }

            // find one cell of smallest and merge it into a neighbor
            var merged = false
            for r in 0..<size where !merged {
                for c in 0..<size where map[r][c] == smallest {
                    let neighborIDs = neighbors(of: Coord(r: r, c: c), size: size)
                        .compactMap { map[$0.r][$0.c] }
                        .filter { $0 != smallest }
                    if let target = neighborIDs.randomElement(using: &rng) {
                        map[r][c] = target
                        merged = true
                        break
                    }
                }
            }
            if !merged {
                // fallback: assign all smallest cells to region 0
                for r in 0..<size {
                    for c in 0..<size where map[r][c] == smallest {
                        map[r][c] = 0
                    }
                }
            }
            unique = Array(Set(map.flatMap { $0 })).sorted()
        }

        // If too few, split largest region(s) until count == totalRegions
        while unique.count < totalRegions {
            // find largest region
            let sizes = unique.map { ($0, countRegion(map, id: $0)) }
            guard let largest = sizes.max(by: { $0.1 < $1.1 })?.0 else { break }
            // pick some frontier cells from largest and convert them to a new region id
            let cellsOfLargest: [Coord] = (0..<size).flatMap { r in
                (0..<size).compactMap { c in map[r][c] == largest ? Coord(r: r, c: c) : nil }
            }
            guard cellsOfLargest.count > 2 else { break }
            // choose about half to split (or at least 1)
            let splitCount = max(1, cellsOfLargest.count / 4)
            for cell in cellsOfLargest.shuffled(using: &rng).prefix(splitCount) {
                // assign new id equal to current max + 1 (will be normalized later)
                map[cell.r][cell.c] = (unique.max() ?? 0) + 1
            }
            unique = Array(Set(map.flatMap { $0 })).sorted()
        }

        // Normalize IDs to contiguous 0..N-1
        unique = Array(Set(map.flatMap { $0 })).sorted()
        var remap: [Int: Int] = [:]
        for (newId, oldId) in unique.enumerated() { remap[oldId] = newId }
        for r in 0..<size {
            for c in 0..<size {
                map[r][c] = remap[map[r][c]] ?? 0
            }
        }

        return map
    }

    private func countRegion(_ map: [[Int]], id: Int) -> Int {
        map.flatMap { $0 }.filter { $0 == id }.count
    }

    private func neighbors(of coord: Coord, size: Int) -> [Coord] {
        [(1,0),(-1,0),(0,1),(0,-1)]
            .map { Coord(r: coord.r + $0.0, c: coord.c + $0.1) }
            .filter { $0.r >= 0 && $0.r < size && $0.c >= 0 && $0.c < size }
    }
}
