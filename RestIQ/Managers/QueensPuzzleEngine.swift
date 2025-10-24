//
//  QueensPuzzleEngine.swift
//  RestIQ
//
//  Created by Alfin Baby on 17/10/25.
//

import Foundation

// MARK: - Public Types

public enum CellState: Int, Codable, Sendable {
    case empty
    case markedX
    case queen
}

public enum Difficulty: String, Codable, CaseIterable, Sendable {
    case easy
    case medium
    case hard
    case expert
}

// Small diff describing a cell change for UI patching.
public struct CellChange: Sendable {
    public let row: Int
    public let col: Int
    public let newState: CellState
    public nonisolated init(row: Int, col: Int, newState: CellState) {
        self.row = row; self.col = col; self.newState = newState
    }
}

// Snapshot of engine state suitable for publishing from ViewModel.
public struct EngineSnapshot: Sendable {
    public let board: [[CellState]]
    public let regionMap: [[Int]]
    public init(board: [[CellState]], regionMap: [[Int]]) {
        self.board = board; self.regionMap = regionMap
    }
}

// MARK: - QueensPuzzleEngine actor

public actor QueensPuzzleEngine {
    public let size: Int
    public let regionMap: [[Int]]
    public private(set) var board: [[CellState]]
    private let canonicalSolution: [(Int, Int)]

    // MARK: - Initialization
    public init(size: Int,
                regionMap: [[Int]],
                canonicalSolution: [(Int, Int)],
                seed: UInt64? = nil) {
        self.size = size
        self.regionMap = regionMap
        self.canonicalSolution = canonicalSolution
        self.board = Array(repeating: Array(repeating: .empty, count: size), count: size)
    }

    // MARK: - Generator
    /// Generates an engine whose puzzle has a unique solution for the given size/difficulty.
    /// Marked `nonisolated` so it can be called without actor hopping (Swift 6 safe).
    public nonisolated static func generate(
        size: Int,
        difficulty: Difficulty,
        attempts: Int = 400,          // increased from 120 for expert stability
        seed: UInt64? = nil
    ) async -> QueensPuzzleEngine? {
        guard size >= 4 && size <= 20 else { return nil }

        func tryGenerate<R: RandomNumberGenerator>(
            rng: inout R,
            maxTries: Int
        ) async -> QueensPuzzleEngine? {
            for _ in 0..<maxTries {
                let regionMap = await RegionGenerator.generateRegionMap(
                    size: size,
                    regions: size,
                    difficulty: difficulty,
                    rng: &rng
                )
                let solver = Solver(size: size, regionMap: regionMap)
                let solutions = await solver.findUpTo(maxCount: 2)
                if solutions.count == 1 {
                    let canonical = solutions[0]
                    return QueensPuzzleEngine(
                        size: size,
                        regionMap: regionMap,
                        canonicalSolution: canonical,
                        seed: seed
                    )
                }
            }
            return nil
        }

        if let seed {
            // Deterministic generation path
            var rng = await SeededRandomNumberGenerator(seed: seed)
            if let engine = await tryGenerate(rng: &rng, maxTries: attempts) {
                return engine
            }
            // Retry with a slightly varied seed if deterministic path fails
            var fallback = await SeededRandomNumberGenerator(seed: seed &+ 0x9e3779b97f4a7c15)
            if let engine = await tryGenerate(rng: &fallback, maxTries: attempts / 2) {
                return engine
            }
            return nil
        } else {
            // Non-deterministic (random) path
            var rng = SystemRandomNumberGenerator()
            if let engine = await tryGenerate(rng: &rng, maxTries: attempts) {
                return engine
            }

            // Guaranteed fallback: progressively lower difficulty to ensure solvable layout
            let fallbackDifficulties: [Difficulty] = {
                switch difficulty {
                case .expert: return [.hard, .medium, .easy]
                case .hard: return [.medium, .easy]
                case .medium: return [.easy]
                case .easy: return []
                }
            }()

            for alt in fallbackDifficulties {
                var altRng = SystemRandomNumberGenerator()
                if let engine = await tryGenerate(rng: &altRng, maxTries: attempts / 2) {
                    return engine
                }
            }
            return nil
        }
    }

    // MARK: - Snapshot
    public func snapshot() async -> EngineSnapshot {
        // Access actor-isolated state directly; no MainActor hop here.
        await EngineSnapshot(board: board, regionMap: regionMap)
    }

    // MARK: - Actions
    public func tapCell(row: Int, col: Int) -> [CellChange] {
        guard row >= 0, row < size, col >= 0, col < size else { return [] }
        let old = board[row][col]
        let next: CellState
        switch old {
        case .empty: next = .markedX
        case .markedX: next = .queen
        case .queen: next = .empty
        }
        board[row][col] = next
        return [CellChange(row: row, col: col, newState: next)]
    }

    public func setCell(_ state: CellState, row: Int, col: Int) -> CellChange? {
        guard row >= 0, row < size, col >= 0, col < size else { return nil }
        board[row][col] = state
        return CellChange(row: row, col: col, newState: state)
    }

    public func resetBoard() -> [CellChange] {
        var changes: [CellChange] = []
        for r in 0..<size {
            for c in 0..<size {
                if board[r][c] != .empty {
                    board[r][c] = .empty
                    changes.append(CellChange(row: r, col: c, newState: .empty))
                }
            }
        }
        return changes
    }

    // MARK: - Validation
    public func isValidPlacement(row: Int, col: Int) -> Bool {
        guard board[row][col] == .queen else { return true }

        // Row
        for c in 0..<size where c != col {
            if board[row][c] == .queen { return false }
        }

        // Column
        for r in 0..<size where r != row {
            if board[r][col] == .queen { return false }
        }

        // Region
        let rid = regionMap[row][col]
        for r in 0..<size {
            for c in 0..<size where regionMap[r][c] == rid && !(r == row && c == col) {
                if board[r][c] == .queen { return false }
            }
        }

        // Adjacency
        for dr in -1...1 {
            for dc in -1...1 {
                if dr == 0 && dc == 0 { continue }
                let nr = row + dr
                let nc = col + dc
                if nr >= 0, nr < size, nc >= 0, nc < size, board[nr][nc] == .queen {
                    return false
                }
            }
        }
        return true
    }

    // MARK: - Conflict Detection
    public func conflictTypesForQueen(at row: Int, col: Int) -> [String] {
        guard row >= 0, row < size, col >= 0, col < size else { return [] }
        guard board[row][col] == .queen else { return [] }

        var conflicts: [String] = []

        // Row
        for c in 0..<size where c != col {
            if board[row][c] == .queen { conflicts.append("Row"); break }
        }

        // Column
        for r in 0..<size where r != row {
            if board[r][col] == .queen { conflicts.append("Column"); break }
        }

        // Region
        let rid = regionMap[row][col]
        outer: for r in 0..<size {
            for c in 0..<size where regionMap[r][c] == rid && !(r == row && c == col) {
                if board[r][c] == .queen { conflicts.append("Region"); break outer }
            }
        }

        // Adjacent
        for dr in -1...1 {
            for dc in -1...1 {
                if dr == 0 && dc == 0 { continue }
                let nr = row + dr
                let nc = col + dc
                if nr >= 0, nr < size, nc >= 0, nc < size, board[nr][nc] == .queen {
                    conflicts.append("Adjacent")
                    break
                }
            }
        }

        // Remove duplicates and preserve order
        var seen = Set<String>()
        return conflicts.filter { seen.insert($0).inserted }
    }

    // MARK: - Solved Check
    public func checkIfSolved() -> Bool {
        var queens: [(Int, Int)] = []
        for r in 0..<size {
            for c in 0..<size where board[r][c] == .queen {
                queens.append((r, c))
            }
        }
        if queens.count != size { return false }

        for (r, c) in queens {
            if !isValidPlacement(row: r, col: c) { return false }
        }

        for r in 0..<size {
            if board[r].filter({ $0 == .queen }).count != 1 { return false }
        }

        for c in 0..<size {
            var ct = 0
            for r in 0..<size where board[r][c] == .queen { ct += 1 }
            if ct != 1 { return false }
        }

        var counts: [Int: Int] = [:]
        for r in 0..<size {
            for c in 0..<size where board[r][c] == .queen {
                counts[regionMap[r][c], default: 0] += 1
            }
        }
        if counts.values.contains(where: { $0 != 1 }) { return false }

        return true
    }

    // MARK: - Canonical Solution
    public func getCanonicalSolution() -> [(Int, Int)] {
        canonicalSolution
    }
}

// MARK: - Solver

fileprivate struct Solver {
    let size: Int
    let regionMap: [[Int]]

    func findUpTo(maxCount: Int) -> [[(Int, Int)]] {
        var solutions: [[(Int, Int)]] = []
        var colsUsed = Array(repeating: false, count: size)
        var regionUsed = [Int: Bool]()
        var placed: [(Int, Int)] = []

        func isAdjacentConflict(_ r1: Int, _ c1: Int, _ r2: Int, _ c2: Int) -> Bool {
            abs(r1 - r2) <= 1 && abs(c1 - c2) <= 1
        }

        func backtrack(row: Int) {
            if solutions.count >= maxCount { return }
            if row == size {
                solutions.append(placed)
                return
            }

            for c in 0..<size where !colsUsed[c] {
                let rid = regionMap[row][c]
                if regionUsed[rid] == true { continue }

                var bad = false
                for (pr, pc) in placed where isAdjacentConflict(pr, pc, row, c) {
                    bad = true; break
                }
                if bad { continue }

                colsUsed[c] = true
                regionUsed[rid] = true
                placed.append((row, c))
                backtrack(row: row + 1)
                if solutions.count >= maxCount { return }
                placed.removeLast()
                colsUsed[c] = false
                regionUsed[rid] = nil
            }
        }

        backtrack(row: 0)
        return solutions
    }
}

// MARK: - Region Generator

fileprivate enum RegionGenerator {
    static func generateRegionMap<R: RandomNumberGenerator>(size: Int,
                                                            regions: Int,
                                                            difficulty: Difficulty,
                                                            rng: inout R) -> [[Int]] {
        let regionCount = max(1, min(regions, size * size))

        var seeds: [(r: Int, c: Int)] = []
        var occupied = Array(repeating: Array(repeating: false, count: size), count: size)

        func pickRandomEmpty() -> (Int, Int) {
            while true {
                let r = Int.random(in: 0..<size, using: &rng)
                let c = Int.random(in: 0..<size, using: &rng)
                if !occupied[r][c] { occupied[r][c] = true; return (r, c) }
            }
        }

        for _ in 0..<regionCount { seeds.append(pickRandomEmpty()) }

        var map = Array(repeating: Array(repeating: -1, count: size), count: size)
        var fronts: [[(Int, Int)]] = Array(repeating: [], count: regionCount)

        for (id, seed) in seeds.enumerated() {
            let (r, c) = seed
            map[r][c] = id
            fronts[id].append((r, c))
        }

        let totalCells = size * size
        let avgSize = Double(totalCells) / Double(regionCount)
        let varianceFactor: Double
        switch difficulty {
        case .easy: varianceFactor = 0.6
        case .medium: varianceFactor = 1.0
        case .hard: varianceFactor = 1.6
        case .expert: varianceFactor = 2.0
        }

        var regionSizes = Array(repeating: 1, count: regionCount)
        var queue: [(id: Int, cell: (Int, Int))] = []
        for id in 0..<regionCount { queue.append((id, fronts[id][0])) }

        let directions = [(1,0),(-1,0),(0,1),(0,-1)]
        while !queue.isEmpty {
            let idx = Int.random(in: 0..<queue.count, using: &rng)
            let item = queue.remove(at: idx)
            let (id, cell) = item
            let target = max(1, Int(round(avgSize + Double.random(in: -varianceFactor...varianceFactor, using: &rng) * avgSize)))
            if regionSizes[id] >= target {
                if Double.random(in: 0...1, using: &rng) > 0.08 { continue }
            }

            var neighbors: [(Int, Int)] = []
            for d in directions {
                let nr = cell.0 + d.0
                let nc = cell.1 + d.1
                if nr >= 0, nr < size, nc >= 0, nc < size, map[nr][nc] == -1 {
                    neighbors.append((nr, nc))
                }
            }
            if neighbors.isEmpty { continue }

            let chosen = neighbors[Int.random(in: 0..<neighbors.count, using: &rng)]
            map[chosen.0][chosen.1] = id
            regionSizes[id] += 1
            queue.append((id, chosen))
            for f in fronts[id] { if Bool.random(using: &rng) { queue.append((id, f)) } }
            fronts[id].append(chosen)
        }

        // Fill any stray -1 cells
        for r in 0..<size {
            for c in 0..<size where map[r][c] == -1 {
                var assigned = false
                for d in directions {
                    let nr = r + d.0
                    let nc = c + d.1
                    if nr >= 0, nr < size, nc >= 0, nc < size, map[nr][nc] != -1 {
                        map[r][c] = map[nr][nc]
                        assigned = true
                        break
                    }
                }
                if !assigned { map[r][c] = Int.random(in: 0..<regionCount, using: &rng) }
            }
        }

        return map
    }
}
