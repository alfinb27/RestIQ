// QueensPuzzleEngineV2.swift
// RestIQ — New puzzle logic (fresh, self-contained)
// Created by ChatGPT for Alfin Baby — full single-file engine with generator, solver, and autoplace logic.

import Foundation

// MARK: - Public Types

public enum CellStateV2: Int, Codable, Sendable {
    case empty
    case markedX
    case queen
}

public enum DifficultyV2: String, Codable, CaseIterable, Sendable {
    case easy
    case medium
    case hard
    case expert
}

public struct CellChangeV2: Sendable {
    public let row: Int
    public let col: Int
    public let newState: CellStateV2
    public nonisolated init(row: Int, col: Int, newState: CellStateV2) {
        self.row = row; self.col = col; self.newState = newState
    }
}

public struct EngineSnapshotV2: Sendable {
    public let board: [[CellStateV2]]
    public let regionMap: [[Int]]
    public init(board: [[CellStateV2]], regionMap: [[Int]]) {
        self.board = board; self.regionMap = regionMap
    }
}

// MARK: - Seeded RNG (LCG)

@preconcurrency
struct LCG: RandomNumberGenerator, Sendable {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed != 0 ? seed : 0xdeadbeefcafebabe }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

// MARK: - Puzzle Engine V2

public actor QueensPuzzleEngineV2 {
    public let size: Int
    public let regionMap: [[Int]]          // region id per cell; invariant: exactly `size` distinct region ids (0..size-1)
    public private(set) var board: [[CellStateV2]]
    private let canonicalSolution: [(Int, Int)]

    // MARK: - Init
    public init(size: Int, regionMap: [[Int]], canonicalSolution: [(Int, Int)]) {
        self.size = size
        self.regionMap = regionMap
        self.canonicalSolution = canonicalSolution
        self.board = Array(repeating: Array(repeating: .empty, count: size), count: size)
    }

    // MARK: - Generator (fresh, simple contract)
    /// Generate a new engine whose canonical solution uses exactly one queen per row, column, and region
    /// Returns nil if generation failed after attempts.
    public nonisolated static func generate(size: Int, difficulty: DifficultyV2, seed: UInt64?, attempts: Int = 300) async -> QueensPuzzleEngineV2? {
        guard size >= 4 && size <= 18 else { return nil }

        func tryOnce<R: RandomNumberGenerator>(rng: inout R) -> QueensPuzzleEngineV2? {
            // 1) generate region map with exactly `size` regions
            let regionMap = RegionGeneratorV2.generate(size: size, regions: size, difficulty: difficulty, rng: &rng)

            // 2) produce a canonical solution via solver that enforces one queen per region
            let solver = SolverV2(size: size, regionMap: regionMap)
            let solutions = solver.findUpTo(maxCount: 2, rng: &rng)
            guard solutions.count == 1 else { return nil }
            let canonical = solutions[0]

            // 3) final sanity: check canonical touches each distinct region exactly once
            var seen = Set<Int>()
            for (r, c) in canonical { seen.insert(regionMap[r][c]) }
            if seen.count != size { return nil }

            return QueensPuzzleEngineV2(size: size, regionMap: regionMap, canonicalSolution: canonical)
        }

        if let seed {
            var rng = LCG(seed: seed)
            for _ in 0..<attempts {
                if let e = tryOnce(rng: &rng) { return e }
            }
            return nil
        } else {
            var rng = SystemRandomNumberGenerator()
            for _ in 0..<attempts {
                if let e = tryOnce(rng: &rng) { return e }
            }
            return nil
        }
    }

    // MARK: - Snapshot
    public func snapshot() async -> EngineSnapshotV2 { EngineSnapshotV2(board: board, regionMap: regionMap) }

    // MARK: - Validation helpers (actor-local)
    private func isRowClear(_ row: Int, excludingCol: Int?) -> Bool {
        for c in 0..<size where c != (excludingCol ?? -1) {
            if board[row][c] == .queen { return false }
        }
        return true
    }

    private func isColClear(_ col: Int, excludingRow: Int?) -> Bool {
        for r in 0..<size where r != (excludingRow ?? -1) {
            if board[r][col] == .queen { return false }
        }
        return true
    }

    private func isRegionClear(_ rid: Int, excluding: (Int,Int)?) -> Bool {
        for r in 0..<size {
            for c in 0..<size where regionMap[r][c] == rid {
                if let ex = excluding, ex.0 == r && ex.1 == c { continue }
                if board[r][c] == .queen { return false }
            }
        }
        return true
    }

    private func isAdjacentClear(row: Int, col: Int, excluding: (Int,Int)?) -> Bool {
        for dr in -1...1 {
            for dc in -1...1 {
                if dr == 0 && dc == 0 { continue }
                let nr = row + dr; let nc = col + dc
                if nr >= 0, nr < size, nc >= 0, nc < size {
                    if let ex = excluding, ex.0 == nr && ex.1 == nc { continue }
                    if board[nr][nc] == .queen { return false }
                }
            }
        }
        return true
    }

    // Atomic validation if placing queen at row,col is legal on current board
    private func canPlaceQueenAt(_ row: Int, _ col: Int) -> Bool {
        if !isRowClear(row, excludingCol: col) { return false }
        if !isColClear(col, excludingRow: row) { return false }
        let rid = regionMap[row][col]
        if !isRegionClear(rid, excluding: (row,col)) { return false }
        if !isAdjacentClear(row: row, col: col, excluding: (row,col)) { return false }
        return true
    }

    // MARK: - Actions (tap/set/reset)
    public func tapCell(row: Int, col: Int) -> [CellChangeV2] {
        guard row >= 0, row < size, col >= 0, col < size else { return [] }
        let old = board[row][col]
        switch old {
        case .empty:
            board[row][col] = .markedX
            return [CellChangeV2(row: row, col: col, newState: .markedX)]
        case .markedX:
            // before placing queen, validate
            if !canPlaceQueenAt(row, col) { return [] }
            board[row][col] = .queen
            return [CellChangeV2(row: row, col: col, newState: .queen)]
        case .queen:
            board[row][col] = .empty
            return [CellChangeV2(row: row, col: col, newState: .empty)]
        }
    }

    /// Direct setter with validation for queen placements.
    public func setCell(_ state: CellStateV2, row: Int, col: Int) -> CellChangeV2? {
        guard row >= 0, row < size, col >= 0, col < size else { return nil }
        if state == .queen {
            if !canPlaceQueenAt(row, col) { return nil }
        }
        board[row][col] = state
        return CellChangeV2(row: row, col: col, newState: state)
    }

    public func resetBoard() -> [CellChangeV2] {
        var changes: [CellChangeV2] = []
        for r in 0..<size {
            for c in 0..<size {
                if board[r][c] != .empty {
                    board[r][c] = .empty
                    changes.append(CellChangeV2(row: r, col: c, newState: .empty))
                }
            }
        }
        return changes
    }

    // MARK: - Autoplace logic (actor-safe)
    /// After a queen has been placed at (row,col), returns the CellChangeV2 list of placed crosses
    /// It marks any empty cell that would be invalid for a queen (using same validation as setCell).
    /// This function uses strict validation: it simulates the board as-is (including the newly placed queen).
    public func autoplaceCrossesAfterPlacing(row: Int, col: Int) -> [CellChangeV2] {
        guard row >= 0, row < size, col >= 0, col < size else { return [] }
        // The board already reflects the newly placed queen (caller responsibility). We'll compute overridable list.
        var placed: [CellChangeV2] = []
        // Use current `board` snapshot
        let snapshot = board
        for r in 0..<size {
            for c in 0..<size {
                if snapshot[r][c] != .empty { continue }
                // simulate placing queen at (r,c)
                // Quick filters: same row, same col, same region, adjacency — if none true, it's likely valid.
                let rid = regionMap[r][c]
                var wouldBeInvalid = false
                // row
                for i in 0..<size { if snapshot[r][i] == .queen { wouldBeInvalid = true; break } }
                if wouldBeInvalid { /* mark below */ }
                // col
                if !wouldBeInvalid {
                    for i in 0..<size { if snapshot[i][c] == .queen { wouldBeInvalid = true; break } }
                }
                // region
                if !wouldBeInvalid {
                    for rr in 0..<size where !wouldBeInvalid {
                        for cc in 0..<size where regionMap[rr][cc] == rid {
                            if snapshot[rr][cc] == .queen { wouldBeInvalid = true; break }
                        }
                    }
                }
                // adjacency
                if !wouldBeInvalid {
                    for dr in -1...1 where !wouldBeInvalid {
                        for dc in -1...1 {
                            if dr == 0 && dc == 0 { continue }
                            let nr = r + dr; let nc = c + dc
                            if nr >= 0, nr < size, nc >= 0, nc < size, snapshot[nr][nc] == .queen {
                                wouldBeInvalid = true; break
                            }
                        }
                    }
                }
                if wouldBeInvalid {
                    board[r][c] = .markedX
                    placed.append(CellChangeV2(row: r, col: c, newState: .markedX))
                }
            }
        }
        return placed
    }

    // MARK: - Validators / helpers for UI
    public func isValidPlacement(row: Int, col: Int) -> Bool {
        guard row >= 0, row < size, col >= 0, col < size else { return true }
        if board[row][col] != .queen { return true }
        return canPlaceQueenAt(row, col)
    }

    public func conflictTypesForQueen(at row: Int, col: Int) -> [String] {
        guard row >= 0, row < size, col >= 0, col < size else { return [] }
        guard board[row][col] == .queen else { return [] }
        var conflicts: [String] = []
        // row
        for c in 0..<size where c != col { if board[row][c] == .queen { conflicts.append("Row"); break } }
        // col
        for r in 0..<size where r != row { if board[r][col] == .queen { conflicts.append("Column"); break } }
        // region
        let rid = regionMap[row][col]
        outer: for r in 0..<size {
            for c in 0..<size where regionMap[r][c] == rid && !(r==row && c==col) {
                if board[r][c] == .queen { conflicts.append("Region"); break outer }
            }
        }
        // adjacent
        for dr in -1...1 {
            for dc in -1...1 {
                if dr == 0 && dc == 0 { continue }
                let nr = row + dr; let nc = col + dc
                if nr >= 0, nr < size, nc >= 0, nc < size, board[nr][nc] == .queen {
                    conflicts.append("Adjacent"); break
                }
            }
        }
        var seen = Set<String>()
        return conflicts.filter { seen.insert($0).inserted }
    }

    public func checkIfSolved() -> Bool {
        var queens: [(Int, Int)] = []
        for r in 0..<size { for c in 0..<size where board[r][c] == .queen { queens.append((r,c)) }}
        if queens.count != size { return false }
        for (r,c) in queens { if !isValidPlacement(row: r, col: c) { return false } }
        // row/col uniqueness
        for r in 0..<size { if board[r].filter({ $0 == .queen}).count != 1 { return false } }
        for c in 0..<size { var ct = 0; for r in 0..<size where board[r][c] == .queen { ct += 1 }; if ct != 1 { return false } }
        // region counts
        var counts: [Int:Int] = [:]
        for r in 0..<size { for c in 0..<size where board[r][c] == .queen { counts[regionMap[r][c], default: 0] += 1 }}
        if counts.values.contains(where: { $0 != 1 }) { return false }
        return true
    }

    public func getCanonicalSolution() -> [(Int, Int)] { canonicalSolution }
}

// MARK: - SolverV2
fileprivate struct SolverV2 {
    let size: Int
    let regionMap: [[Int]]

    init(size: Int, regionMap: [[Int]]) {
        self.size = size
        self.regionMap = regionMap
    }

    func findUpTo(maxCount: Int, rng: inout some RandomNumberGenerator) -> [[(Int, Int)]] {
        var solutions: [[(Int, Int)]] = []
        var colsUsed = Array(repeating: false, count: size)
        var regionsUsed = [Int: Bool]()
        var placed: [(Int, Int)] = []

        func isAdjacent(_ r1:Int,_ c1:Int,_ r2:Int,_ c2:Int)->Bool { abs(r1-r2) <= 1 && abs(c1-c2) <= 1 }

        func backtrack(row: Int) {
            if solutions.count >= maxCount { return }
            if row == size { solutions.append(placed); return }

            // column order randomized slightly to increase variety
            var cols = Array(0..<size)
            cols.shuffle(using: &rng)
            for c in cols where !colsUsed[c] {
                let rid = regionMap[row][c]
                if regionsUsed[rid] == true { continue }
                var conflict = false
                for (pr,pc) in placed where isAdjacent(pr,pc,row,c) { conflict = true; break }
                if conflict { continue }
                colsUsed[c] = true
                regionsUsed[rid] = true
                placed.append((row,c))
                backtrack(row: row+1)
                if solutions.count >= maxCount { return }
                placed.removeLast()
                colsUsed[c] = false
                regionsUsed[rid] = nil
            }
        }

        backtrack(row: 0)
        return solutions
    }
}

// MARK: - Region Generator V2
fileprivate enum RegionGeneratorV2 {
    static func generate<R: RandomNumberGenerator>(size: Int, regions: Int, difficulty: DifficultyV2, rng: inout R) -> [[Int]] {
        // Guarantee exactly `regions` region ids and contiguous-ish regions.
        let count = max(1, min(regions, size*size))
        var map = Array(repeating: Array(repeating: -1, count: size), count: size)

        // 1) pick `count` seed cells distinct
        var seeds: [(Int,Int)] = []
        var used = Set<Int>()
        while seeds.count < count {
            let r = Int.random(in: 0..<size, using: &rng)
            let c = Int.random(in: 0..<size, using: &rng)
            let key = r*size + c
            if used.contains(key) { continue }
            used.insert(key); seeds.append((r,c))
        }

        for (id, s) in seeds.enumerated() { map[s.0][s.1] = id }

        // 2) flood-fill expansion with bias from difficulty
        var fronts = seeds.map { [$0] }
        var regionSizes = Array(repeating: 1, count: count)
        let directions = [(1,0),(-1,0),(0,1),(0,-1)]

        let avg = Double(size*size) / Double(count)
        let variance: Double
        switch difficulty {
        case .easy: variance = 0.45
        case .medium: variance = 0.95
        case .hard: variance = 1.4
        case .expert: variance = 2.0
        }

        var queue: [(Int,(Int,Int))] = []
        for id in 0..<count { queue.append((id, fronts[id][0])) }

        while !queue.isEmpty {
            let idx = Int.random(in: 0..<queue.count, using: &rng)
            let (id, cell) = queue.remove(at: idx)
            let target = max(1, Int(round(avg + Double.random(in: -variance...variance, using: &rng) * avg)))
            if regionSizes[id] >= target {
                if Double.random(in: 0...1, using: &rng) < 0.12 { /* allow some growth */ } else { continue }
            }
            var neighbors: [(Int,Int)] = []
            for d in directions {
                let nr = cell.0 + d.0; let nc = cell.1 + d.1
                if nr >= 0, nr < size, nc >= 0, nc < size, map[nr][nc] == -1 { neighbors.append((nr,nc)) }
            }
            if neighbors.isEmpty { continue }
            let chosen = neighbors[Int.random(in: 0..<neighbors.count, using: &rng)]
            map[chosen.0][chosen.1] = id
            regionSizes[id] += 1
            queue.append((id, chosen))
            if Double.random(in: 0...1, using: &rng) < 0.18 { queue.append((id, cell)) }
            fronts[id].append(chosen)
        }

        // 3) fill any -1 left by snapping to smallest neighboring region
        for r in 0..<size {
            for c in 0..<size where map[r][c] == -1 {
                var best: Int? = nil; var bestSize = Int.max
                for d in directions {
                    let nr = r + d.0; let nc = c + d.1
                    if nr >= 0, nr < size, nc >= 0, nc < size, map[nr][nc] != -1 {
                        let rid = map[nr][nc]
                        if regionSizes[rid] < bestSize { bestSize = regionSizes[rid]; best = rid }
                    }
                }
                map[r][c] = best ?? Int.random(in: 0..<count, using: &rng)
            }
        }

        return map
    }
}
