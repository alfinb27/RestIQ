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

public enum Difficulty {
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
    public init(row: Int, col: Int, newState: CellState) {
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
    let canonicalSolution: [(Int, Int)]
    private var rng: RandomNumberGenerator

    // MARK: - Initialization
    init(size: Int,
         regionMap: [[Int]],
         canonicalSolution: [(Int, Int)],
         seed: UInt64? = nil) {
        self.size = size
        self.regionMap = regionMap
        self.canonicalSolution = canonicalSolution
        self.board = Array(repeating: Array(repeating: .empty, count: size), count: size)
        if let s = seed {
            self.rng = SplitMix64(seed: s)
        } else {
            self.rng = SystemRNG()
        }
    }

    // MARK: - Generator
    public static func generate(size: Int,
                                difficulty: Difficulty,
                                attempts: Int = 120,
                                seed: UInt64? = nil) async -> QueensPuzzleEngine? {
        guard size >= 4 && size <= 20 else { return nil }

        var rng: RandomNumberGenerator = seed.map { SplitMix64(seed: $0) } ?? SystemRNG()

        for _ in 0..<attempts {
            let regionMap = RegionGenerator.generateRegionMap(size: size,
                                                              regions: size,
                                                              difficulty: difficulty,
                                                              rng: &rng)
            let solver = Solver(size: size, regionMap: regionMap)
            let solutions = solver.findUpTo(maxCount: 2)
            if solutions.count == 1 {
                let canonical = solutions[0]
                return QueensPuzzleEngine(size: size,
                                          regionMap: regionMap,
                                          canonicalSolution: canonical,
                                          seed: seed)
            }
        }
        return nil
    }

    // MARK: - Snapshot
    public func snapshot() -> EngineSnapshot {
        EngineSnapshot(board: board, regionMap: regionMap)
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
                if nr >= 0, nr < size, nc >= 0, nc < size {
                    if board[nr][nc] == .queen { return false }
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
        for r in 0..<size {
            for c in 0..<size where regionMap[r][c] == rid && !(r == row && c == col) {
                if board[r][c] == .queen {
                    conflicts.append("Region")
                    break
                }
            }
        }

        // Adjacent
        for dr in -1...1 {
            for dc in -1...1 {
                if dr == 0 && dc == 0 { continue }
                let nr = row + dr
                let nc = col + dc
                if nr >= 0, nr < size, nc >= 0, nc < size {
                    if board[nr][nc] == .queen {
                        conflicts.append("Adjacent")
                        break
                    }
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

        func isAdjacentConflict(r1: Int, c1: Int, r2: Int, c2: Int) -> Bool {
            abs(r1 - r2) <= 1 && abs(c1 - c2) <= 1
        }

        func backtrack(row: Int) {
            if solutions.count >= maxCount { return }
            if row == size {
                solutions.append(placed)
                return
            }

            for c in 0..<size {
                if colsUsed[c] { continue }
                let rid = regionMap[row][c]
                if regionUsed[rid] == true { continue }
                var bad = false
                for (pr, pc) in placed {
                    if isAdjacentConflict(r1: pr, c1: pc, r2: row, c2: c) { bad = true; break }
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
    static func generateRegionMap(size: Int,
                                  regions: Int,
                                  difficulty: Difficulty,
                                  rng: inout RandomNumberGenerator) -> [[Int]] {
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

        for _ in 0..<regionCount {
            seeds.append(pickRandomEmpty())
        }

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
                if nr >= 0, nr < size, nc >= 0, nc < size {
                    if map[nr][nc] == -1 { neighbors.append((nr, nc)) }
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

// MARK: - RNG Helpers

fileprivate struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

fileprivate struct SystemRNG: RandomNumberGenerator {
    mutating func next() -> UInt64 { UInt64.random(in: UInt64.min...UInt64.max) }
}
