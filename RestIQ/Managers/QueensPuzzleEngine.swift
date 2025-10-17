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
    // Public read-only
    public let size: Int
    public let regionMap: [[Int]]      // region id per cell
    public private(set) var board: [[CellState]]

    // Internal solution found during generation (one canonical solution).
    // Stored for reference / hinting. Each item is (row,col).
    let canonicalSolution: [(Int, Int)]

    // Random generator used for deterministic attempts if seed provided.
    private var rng: RandomNumberGenerator

    // MARK: - Initialization (internal)
    /// Internal initializer. Use `generate(size:difficulty:attempts:seed:)` to build guaranteed-unique puzzles.
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

    // MARK: - Public factory generator (async)
    /// Generate an engine with a unique solution.
    /// - Parameters:
    ///   - size: grid size (6..9 recommended)
    ///   - difficulty: controls shape variance of regions
    ///   - attempts: how many tries before giving up (default 120)
    ///   - seed: optional deterministic seed
    /// - Returns: QueensPuzzleEngine if successful, nil on failure.
    public static func generate(size: Int,
                                difficulty: Difficulty,
                                attempts: Int = 120,
                                seed: UInt64? = nil) async -> QueensPuzzleEngine? {
        guard size >= 4 && size <= 20 else { return nil } // safety limits

        var rng: RandomNumberGenerator = seed.map { SplitMix64(seed: $0) } ?? SystemRNG()

        for _ in 0..<attempts {
            // 1) construct a contiguous region map with exactly `size` regions
            let regionMap = RegionGenerator.generateRegionMap(size: size,
                                                              regions: size,
                                                              difficulty: difficulty,
                                                              rng: &rng)
            // 2) attempt to find all solutions (stop at 2). If exactly 1, accept.
            let solver = Solver(size: size, regionMap: regionMap)
            let solutions = solver.findUpTo(maxCount: 2)
            if solutions.count == 1 {
                let canonical = solutions[0]
                // Build engine with canonical solution recorded. Board is empty initially.
                return QueensPuzzleEngine(size: size, regionMap: regionMap, canonicalSolution: canonical, seed: seed)
            }
            // else try again
        }
        return nil
    }

    // MARK: - Snapshot for ViewModel
    /// Return a snapshot of board + regionMap for publishing on main actor.
    public func snapshot() -> EngineSnapshot {
        EngineSnapshot(board: board, regionMap: regionMap)
    }

    // MARK: - Actions (async, safe to call off-main)
    /// Tap cycles: empty -> X -> queen -> empty
    /// Returns list of cell changes that occurred (usually 1).
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

    /// Toggle mark (useful for programmatic moves). Returns change.
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

    // MARK: - Validation & solved checks (fast)
    /// Checks whether cell at (row,col) is valid assuming it contains a queen.
    /// Returns true for non-queen cells (helper for UI).
    public func isValidPlacement(row: Int, col: Int) -> Bool {
        guard board[row][col] == .queen else { return true }

        // Row check
        for c in 0..<size where c != col {
            if board[row][c] == .queen { return false }
        }

        // Column check
        for r in 0..<size where r != row {
            if board[r][col] == .queen { return false }
        }

        // Region uniqueness
        let rid = regionMap[row][col]
        for r in 0..<size {
            for c in 0..<size where regionMap[r][c] == rid && !(r == row && c == col) {
                if board[r][c] == .queen { return false }
            }
        }

        // Adjacency 8-neighbour
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

    /// Full solved check: correct count and all queens valid and one per region/row/col.
    public func checkIfSolved() -> Bool {
        // Count queens
        var queens: [(Int, Int)] = []
        for r in 0..<size {
            for c in 0..<size where board[r][c] == .queen {
                queens.append((r, c))
            }
        }
        if queens.count != size { return false }

        // Each queen must be locally valid
        for (r, c) in queens {
            if !isValidPlacement(row: r, col: c) { return false }
        }

        // Row uniqueness
        for r in 0..<size {
            let ct = board[r].filter { $0 == .queen }.count
            if ct != 1 { return false }
        }

        // Col uniqueness
        for c in 0..<size {
            var ct = 0
            for r in 0..<size where board[r][c] == .queen { ct += 1 }
            if ct != 1 { return false }
        }

        // Region uniqueness
        var counts: [Int: Int] = [:]
        for r in 0..<size {
            for c in 0..<size where board[r][c] == .queen {
                counts[regionMap[r][c], default: 0] += 1
            }
        }
        if counts.values.contains(where: { $0 != 1 }) { return false }

        return true
    }

    // MARK: - Hints / canonical solution access
    /// Returns canonical solution positions (row,col) discovered during generation.
    public func getCanonicalSolution() -> [(Int, Int)] {
        canonicalSolution
    }
}

// MARK: - Solver (backtracking) - finds solutions for a given regionMap

fileprivate struct Solver {
    let size: Int
    let regionMap: [[Int]]

    // Solve by placing one queen per row. This enumerates full-board placements where
    // each row has exactly one queen. The region-map constraint is enforced by tracking region usage.
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
                // Collect solution
                solutions.append(placed)
                return
            }

            // Try columns in random-ish order (but deterministic per run)
            for c in 0..<size {
                if colsUsed[c] { continue }
                // region
                let rid = regionMap[row][c]
                if regionUsed[rid] == true { continue }
                // adjacency with previously placed queens
                var bad = false
                for (pr, pc) in placed {
                    if isAdjacentConflict(r1: pr, c1: pc, r2: row, c2: c) { bad = true; break }
                    // diag conflict is allowed? For standard non-attacking queens diag is forbidden.
                    // The original game's rules forbid same row/col only and adjacency; diagonals allowed.
                    // The earlier engine checks only row/column/region/adjacency, not diagonals.
                    // So we do NOT enforce diagonal attacks beyond row/col checks (row is unique by construction).
                }
                if bad { continue }

                // place
                colsUsed[c] = true
                regionUsed[rid] = true
                placed.append((row, c))
                backtrack(row: row + 1)
                if solutions.count >= maxCount { return }
                // undo
                placed.removeLast()
                colsUsed[c] = false
                regionUsed[rid] = nil
            }
        }

        backtrack(row: 0)
        return solutions
    }
}

// MARK: - Region generator
fileprivate enum RegionGenerator {
    /// Create `regions` contiguous regions on `size x size` grid.
    /// Each region id is in 0..<regions.
    /// Difficulty controls size variance: easy -> low variance, hard -> high variance.
    static func generateRegionMap(size: Int,
                                  regions: Int,
                                  difficulty: Difficulty,
                                  rng: inout RandomNumberGenerator) -> [[Int]] {
        // Simple stochastic region expansion:
        // - pick `regions` seed cells (unique)
        // - expand region fronts until every cell is assigned
        // - expansion selection randomness controlled by difficulty to increase jaggedness

        // clamp regions
        let regionCount = max(1, min(regions, size * size))

        // pick seeds
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

        // region map initial -1
        var map = Array(repeating: Array(repeating: -1, count: size), count: size)
        var fronts: [[(Int, Int)]] = Array(repeating: [], count: regionCount)

        for (id, seed) in seeds.enumerated() {
            let (r, c) = seed
            map[r][c] = id
            fronts[id].append((r, c))
        }

        // Target average region size
        let totalCells = size * size
        let avgSize = Double(totalCells) / Double(regionCount)
        // difficulty affects allowed size variance factor
        let varianceFactor: Double
        switch difficulty {
        case .easy: varianceFactor = 0.6
        case .medium: varianceFactor = 1.0
        case .hard: varianceFactor = 1.6
        case .expert: varianceFactor = 2.0
        }
        var regionSizes = Array(repeating: 1, count: regionCount)
        var queue: [(id: Int, cell: (Int, Int))] = []
        for id in 0..<regionCount {
            queue.append((id, fronts[id][0]))
        }

        // Expand until all assigned
        let directions = [(1,0),(-1,0),(0,1),(0,-1)]
        while queue.count > 0 {
            // pop a random element from queue
            let idx = Int.random(in: 0..<queue.count, using: &rng)
            let item = queue.remove(at: idx)
            let (id, cell) = item
            // compute desirable max size for region
            let target = max(1, Int(round(avgSize + Double.random(in: -varianceFactor...varianceFactor, using: &rng) * avgSize)))
            // prefer to expand smaller regions first
            if regionSizes[id] >= target {
                // occasionally still expand to avoid islands
                if Double.random(in: 0...1, using: &rng) > 0.08 { continue }
            }

            // pick neighbor candidates
            var neighbors: [(Int, Int)] = []
            for d in directions {
                let nr = cell.0 + d.0
                let nc = cell.1 + d.1
                if nr >= 0, nr < size, nc >= 0, nc < size {
                    if map[nr][nc] == -1 {
                        neighbors.append((nr, nc))
                    }
                }
            }
            if neighbors.isEmpty { continue }

            // choose a neighbor (bias: larger regions expand slightly more for easy)
            let choiceIndex = Int.random(in: 0..<neighbors.count, using: &rng)
            let chosen = neighbors[choiceIndex]
            map[chosen.0][chosen.1] = id
            regionSizes[id] += 1
            queue.append((id, chosen))

            // also push other frontier cells of same region to keep expansion distributed
            for f in fronts[id] {
                if Bool.random(using: &rng) { queue.append((id, f)) }
            }
            fronts[id].append(chosen)
        }

        // Fix any leftover -1 (shouldn't happen, but safety)
        for r in 0..<size {
            for c in 0..<size where map[r][c] == -1 {
                // find nearest assigned neighbor
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
                if !assigned {
                    // assign random region
                    map[r][c] = Int.random(in: 0..<regionCount, using: &rng)
                }
            }
        }

        return map
    }
}

// MARK: - Helpers: small RNG wrappers for determinism when seed provided

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
