//
//  QueensPuzzleEngine.swift
//  RestIQ
//
//  v4 changes:
//  - ConstraintAnalyser: counts depth-1 forced placements; generate() rejects
//    puzzles above the per-difficulty threshold so chain-solving is eliminated.
//  - RegionGenerator: connectivity pass after flood-fill reassigns stray cells
//    so every region is guaranteed to be a single connected body.
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

public struct CellChange: Sendable {
    public let row: Int
    public let col: Int
    public let newState: CellState
    public nonisolated init(row: Int, col: Int, newState: CellState) {
        self.row = row; self.col = col; self.newState = newState
    }
}

public struct EngineSnapshot: Sendable {
    public let board: [[CellState]]
    public let regionMap: [[Int]]
    public init(board: [[CellState]], regionMap: [[Int]]) {
        self.board = board; self.regionMap = regionMap
    }
}

public struct PuzzleRecord: Codable, Sendable {
    public let regionMap: [[Int]]
    public let solution: [[Int]]

    public var solutionTuples: [(Int, Int)] {
        solution.compactMap { pair in
            guard pair.count == 2 else { return nil }
            return (pair[0], pair[1])
        }
    }

    public init(regionMap: [[Int]], solution: [(Int, Int)]) {
        self.regionMap = regionMap
        self.solution = solution.map { [$0.0, $0.1] }
    }
}

// MARK: - QueensPuzzleEngine

public actor QueensPuzzleEngine {
    public let size: Int
    public let regionMap: [[Int]]
    public private(set) var board: [[CellState]]
    private let canonicalSolution: [(Int, Int)]

    public init(size: Int,
                regionMap: [[Int]],
                canonicalSolution: [(Int, Int)],
                seed: UInt64? = nil) {
        self.size = size
        self.regionMap = regionMap
        self.canonicalSolution = canonicalSolution
        self.board = Array(repeating: Array(repeating: .empty, count: size), count: size)
    }

    public nonisolated static func restore(from record: PuzzleRecord) -> QueensPuzzleEngine {
        let size = record.regionMap.count
        return QueensPuzzleEngine(
            size: size,
            regionMap: record.regionMap,
            canonicalSolution: record.solutionTuples
        )
    }

    // MARK: - Generator

    public nonisolated static func generate(
        size: Int,
        difficulty: Difficulty,
        attempts: Int = 600,
        seed: UInt64? = nil
    ) async -> QueensPuzzleEngine? {
        guard size >= 4 && size <= 20 else { return nil }

        func tryGenerate<R: RandomNumberGenerator>(rng: inout R, maxTries: Int) -> QueensPuzzleEngine? {
            for _ in 0..<maxTries {
                let regionMap = RegionGenerator.generateRegionMap(
                    size: size, regions: size, difficulty: difficulty, rng: &rng
                )

                // Gate 1: must have exactly one solution
                let solutions = Solver(size: size, regionMap: regionMap).findUpTo(maxCount: 2)
                guard solutions.count == 1 else { continue }

                // Gate 2: shape complexity (hard/expert only)
                if difficulty == .hard || difficulty == .expert {
                    let score = ComplexityAnalyzer.score(map: regionMap, size: size, regionCount: size)
                    guard score.meetsThreshold(for: difficulty) else { continue }
                }

                // Gate 3: depth-1 chain filter — rejects puzzles where too many queens
                // are force-placed by trivial single-candidate deductions.
                let depth1Count = ConstraintAnalyser.countDepth1Queens(
                    map: regionMap, size: size, regionCount: size
                )
                let depth1Limit: Int = {
                    switch difficulty {
                    case .easy:   return size - 2        // a couple of giveaways are fine
                    case .medium: return size / 2
                    case .hard:   return 2
                    case .expert: return 0               // every placement must require reasoning
                    }
                }()
                guard depth1Count <= depth1Limit else { continue }

                return QueensPuzzleEngine(
                    size: size, regionMap: regionMap,
                    canonicalSolution: solutions[0], seed: seed
                )
            }
            return nil
        }

        if let seed {
            var rng = SeededRandomNumberGenerator(seed: seed)
            if let e = tryGenerate(rng: &rng, maxTries: attempts) { return e }

            for offset: UInt64 in [0x9e3779b97f4a7c15, 0x6c62272e07bb0142, 0x94d049bb133111eb] {
                var r = SeededRandomNumberGenerator(seed: seed &+ offset)
                if let e = tryGenerate(rng: &r, maxTries: attempts / 3) { return e }
            }
        }

        var rng = SystemRandomNumberGenerator()
        if let e = tryGenerate(rng: &rng, maxTries: attempts) { return e }

        // Fallback: drop complexity + depth-1 gates, keep uniqueness — a valid puzzle > nil.
        let easierDifficulties: [Difficulty] = {
            switch difficulty {
            case .expert: return [.hard, .medium, .easy]
            case .hard:   return [.medium, .easy]
            case .medium: return [.easy]
            case .easy:   return []
            }
        }()
        for alt in easierDifficulties {
            var r = SystemRandomNumberGenerator()
            let regionMap = RegionGenerator.generateRegionMap(size: size, regions: size, difficulty: alt, rng: &r)
            let solutions = Solver(size: size, regionMap: regionMap).findUpTo(maxCount: 2)
            if solutions.count == 1 {
                return QueensPuzzleEngine(size: size, regionMap: regionMap, canonicalSolution: solutions[0])
            }
        }
        return nil
    }

    public func record() -> PuzzleRecord {
        PuzzleRecord(regionMap: regionMap, solution: canonicalSolution)
    }

    // MARK: - Snapshot

    public func snapshot() async -> EngineSnapshot {
        EngineSnapshot(board: board, regionMap: regionMap)
    }

    // MARK: - Actions

    public func tapCell(row: Int, col: Int) -> [CellChange] {
        guard row >= 0, row < size, col >= 0, col < size else { return [] }
        let old = board[row][col]
        let next: CellState
        switch old {
        case .empty:   next = .markedX
        case .markedX: next = .queen
        case .queen:   next = .empty
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
            for c in 0..<size where board[r][c] != .empty {
                board[r][c] = .empty
                changes.append(CellChange(row: r, col: c, newState: .empty))
            }
        }
        return changes
    }

    // MARK: - Validation

    public func isValidPlacement(row: Int, col: Int) -> Bool {
        guard board[row][col] == .queen else { return true }
        for c in 0..<size where c != col { if board[row][c] == .queen { return false } }
        for r in 0..<size where r != row { if board[r][col] == .queen { return false } }
        let rid = regionMap[row][col]
        for r in 0..<size {
            for c in 0..<size where regionMap[r][c] == rid && !(r == row && c == col) {
                if board[r][c] == .queen { return false }
            }
        }
        for dr in -1...1 {
            for dc in -1...1 {
                if dr == 0 && dc == 0 { continue }
                let nr = row + dr; let nc = col + dc
                if nr >= 0, nr < size, nc >= 0, nc < size, board[nr][nc] == .queen { return false }
            }
        }
        return true
    }

    // MARK: - Conflict Detection

    public func conflictTypesForQueen(at row: Int, col: Int) -> [String] {
        guard row >= 0, row < size, col >= 0, col < size else { return [] }
        guard board[row][col] == .queen else { return [] }
        var conflicts: [String] = []
        for c in 0..<size where c != col { if board[row][c] == .queen { conflicts.append("Row"); break } }
        for r in 0..<size where r != row { if board[r][col] == .queen { conflicts.append("Column"); break } }
        let rid = regionMap[row][col]
        outer: for r in 0..<size {
            for c in 0..<size where regionMap[r][c] == rid && !(r == row && c == col) {
                if board[r][c] == .queen { conflicts.append("Region"); break outer }
            }
        }
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

    // MARK: - Solved Check

    public func checkIfSolved() -> Bool {
        var queens: [(Int, Int)] = []
        for r in 0..<size { for c in 0..<size where board[r][c] == .queen { queens.append((r, c)) } }
        guard queens.count == size else { return false }
        for (r, c) in queens { if !isValidPlacement(row: r, col: c) { return false } }
        for r in 0..<size { if board[r].filter({ $0 == .queen }).count != 1 { return false } }
        for c in 0..<size {
            var ct = 0; for r in 0..<size where board[r][c] == .queen { ct += 1 }
            if ct != 1 { return false }
        }
        var counts: [Int: Int] = [:]
        for r in 0..<size { for c in 0..<size where board[r][c] == .queen { counts[regionMap[r][c], default: 0] += 1 } }
        return !counts.values.contains(where: { $0 != 1 })
    }

    public func getCanonicalSolution() -> [(Int, Int)] { canonicalSolution }
}

// MARK: - Solver

fileprivate struct Solver {
    let size: Int
    let regionMap: [[Int]]

    nonisolated func findUpTo(maxCount: Int) -> [[(Int, Int)]] {
        var solutions: [[(Int, Int)]] = []
        var colsUsed    = Array(repeating: false, count: size)
        var regionUsed  = [Int: Bool]()
        var placed: [(Int, Int)] = []

        func adjacent(_ r1: Int, _ c1: Int, _ r2: Int, _ c2: Int) -> Bool {
            abs(r1 - r2) <= 1 && abs(c1 - c2) <= 1
        }

        func backtrack(row: Int) {
            if solutions.count >= maxCount { return }
            if row == size { solutions.append(placed); return }
            for c in 0..<size where !colsUsed[c] {
                let rid = regionMap[row][c]
                if regionUsed[rid] == true { continue }
                var bad = false
                for (pr, pc) in placed where adjacent(pr, pc, row, c) { bad = true; break }
                if bad { continue }
                colsUsed[c] = true; regionUsed[rid] = true; placed.append((row, c))
                backtrack(row: row + 1)
                if solutions.count >= maxCount { return }
                placed.removeLast(); colsUsed[c] = false; regionUsed[rid] = nil
            }
        }

        backtrack(row: 0)
        return solutions
    }
}

// MARK: - Constraint Analyser
//
// Simulates human constraint-propagation solving on a fresh board.
// Counts how many queens can be placed via depth-1 deductions alone —
// i.e. a region, row, or column that has exactly one valid candidate remaining.
//
// The simulation is purely logical (no guessing). It places a forced queen,
// propagates the new eliminations, and repeats until no more forced moves exist.

fileprivate enum ConstraintAnalyser {

    nonisolated static func countDepth1Queens(map: [[Int]], size: Int, regionCount: Int) -> Int {
        // Candidate set: for each cell, is it still a legal placement?
        // A cell is eliminated if: its row has a queen, its column has a queen,
        // its region has a queen, or it is adjacent (8-dir) to a queen.
        var rowHasQueen    = Array(repeating: false, count: size)
        var colHasQueen    = Array(repeating: false, count: size)
        var regionHasQueen = Array(repeating: false, count: regionCount)
        // adjacentBlocked[r][c] = count of queens adjacent to (r,c)
        var adjacentBlocked = Array(repeating: Array(repeating: 0, count: size), count: size)

        var placedCount = 0
        var changed = true

        while changed {
            changed = false

            // Helper: is cell (r,c) a valid candidate given current state?
            func isCandidate(_ r: Int, _ c: Int) -> Bool {
                !rowHasQueen[r]
                    && !colHasQueen[c]
                    && !regionHasQueen[map[r][c]]
                    && adjacentBlocked[r][c] == 0
            }

            // Helper: place a queen at (r,c) and propagate eliminations.
            func place(_ r: Int, _ c: Int) {
                rowHasQueen[r]          = true
                colHasQueen[c]          = true
                regionHasQueen[map[r][c]] = true
                // Mark all 8 neighbours as adjacency-blocked
                for dr in -1...1 {
                    for dc in -1...1 {
                        if dr == 0 && dc == 0 { continue }
                        let nr = r + dr; let nc = c + dc
                        if nr >= 0, nr < size, nc >= 0, nc < size {
                            adjacentBlocked[nr][nc] += 1
                        }
                    }
                }
                placedCount += 1
            }

            // Check each region for a single valid candidate
            for rid in 0..<regionCount {
                guard !regionHasQueen[rid] else { continue }
                var candidates: [(Int, Int)] = []
                for r in 0..<size {
                    for c in 0..<size where map[r][c] == rid {
                        if isCandidate(r, c) { candidates.append((r, c)) }
                    }
                }
                if candidates.count == 1 {
                    place(candidates[0].0, candidates[0].1)
                    changed = true
                }
            }

            // Check each row for a single valid candidate
            for r in 0..<size {
                guard !rowHasQueen[r] else { continue }
                var candidates: [(Int, Int)] = []
                for c in 0..<size where isCandidate(r, c) { candidates.append((r, c)) }
                if candidates.count == 1 {
                    place(candidates[0].0, candidates[0].1)
                    changed = true
                }
            }

            // Check each column for a single valid candidate
            for c in 0..<size {
                guard !colHasQueen[c] else { continue }
                var candidates: [(Int, Int)] = []
                for r in 0..<size where isCandidate(r, c) { candidates.append((r, c)) }
                if candidates.count == 1 {
                    place(candidates[0].0, candidates[0].1)
                    changed = true
                }
            }
        }

        return placedCount
    }
}

// MARK: - Complexity Analyser

fileprivate struct ComplexityScore {
    let avgIrregularity:  Double
    let microRegionCount: Int
    let interleavingScore: Int

    func meetsThreshold(for difficulty: Difficulty) -> Bool {
        switch difficulty {
        case .easy:   return true
        case .medium: return true
        case .hard:   return microRegionCount >= 2 && avgIrregularity >= 10.0
        case .expert: return microRegionCount >= 3 && avgIrregularity >= 14.0 && interleavingScore >= 6
        }
    }
}

fileprivate enum ComplexityAnalyzer {
    static func score(map: [[Int]], size: Int, regionCount: Int) -> ComplexityScore {
        let directions = [(0,1),(0,-1),(1,0),(-1,0)]
        var areas      = Array(repeating: 0, count: regionCount)
        var perimeters = Array(repeating: 0, count: regionCount)
        var interleavingPairs = Set<Int>()

        for r in 0..<size {
            for c in 0..<size {
                let rid = map[r][c]
                areas[rid] += 1
                for d in directions {
                    let nr = r + d.0; let nc = c + d.1
                    if nr < 0 || nr >= size || nc < 0 || nc >= size {
                        perimeters[rid] += 1
                    } else {
                        let nrid = map[nr][nc]
                        if nrid != rid {
                            perimeters[rid] += 1
                            let lo = min(rid, nrid); let hi = max(rid, nrid)
                            if hi - lo > 1 { interleavingPairs.insert(lo * 1000 + hi) }
                        }
                    }
                }
            }
        }

        var totalIrregularity = 0.0
        for id in 0..<regionCount where areas[id] > 0 {
            totalIrregularity += (Double(perimeters[id]) * Double(perimeters[id])) / Double(areas[id])
        }

        return ComplexityScore(
            avgIrregularity:   totalIrregularity / Double(regionCount),
            microRegionCount:  areas.filter { $0 <= 2 }.count,
            interleavingScore: interleavingPairs.count
        )
    }
}

// MARK: - Region Generator

fileprivate enum RegionGenerator {

    private enum ExpansionMode { case blob, snake }

    nonisolated static func generateRegionMap<R: RandomNumberGenerator>(
        size: Int,
        regions: Int,
        difficulty: Difficulty,
        rng: inout R
    ) -> [[Int]] {
        let regionCount = max(1, min(regions, size * size))
        let totalCells  = size * size
        let avgSize     = Double(totalCells) / Double(regionCount)
        let directions  = [(0,1),(0,-1),(1,0),(-1,0)]

        // MARK: Step 1 — Assign size budgets with intentional asymmetry

        let forcedMicroCount: Int = {
            switch difficulty {
            case .easy:   return 0
            case .medium: return 1
            case .hard:   return 2
            case .expert: return 3
            }
        }()

        let snakeFraction: Double = {
            switch difficulty {
            case .easy:   return 0.0
            case .medium: return 0.1
            case .hard:   return 0.4
            case .expert: return 0.6
            }
        }()

        var modes = Array(repeating: ExpansionMode.blob, count: regionCount)
        let snakeCount = Int(Double(regionCount) * snakeFraction)
        var snakeCandidates = Array(0..<regionCount).shuffled(using: &rng)
        for i in 0..<min(snakeCount, snakeCandidates.count) { modes[snakeCandidates[i]] = .snake }

        var targetSizes  = Array(repeating: 0, count: regionCount)
        var microIndices = Set<Int>()
        var nonMicroPool = Array(0..<regionCount).shuffled(using: &rng)

        for _ in 0..<forcedMicroCount {
            guard let idx = nonMicroPool.popLast() else { break }
            targetSizes[idx] = Int.random(in: 1...2, using: &rng)
            microIndices.insert(idx)
        }

        let cellsUsedByMicro = microIndices.reduce(0) { $0 + targetSizes[$1] }
        let remainingCells   = totalCells - cellsUsedByMicro
        let remainingRegions = regionCount - microIndices.count

        if remainingRegions > 0 {
            let baseSize = remainingCells / remainingRegions
            var leftover = remainingCells - baseSize * remainingRegions

            let spread: Int = {
                switch difficulty {
                case .easy:   return max(1, Int(avgSize * 0.3))
                case .medium: return max(1, Int(avgSize * 0.6))
                case .hard:   return max(1, Int(avgSize * 1.0))
                case .expert: return max(1, Int(avgSize * 1.4))
                }
            }()

            for id in 0..<regionCount where !microIndices.contains(id) {
                let delta = Int.random(in: -spread...spread, using: &rng)
                targetSizes[id] = max(3, baseSize + delta)
            }

            let nonMicro = (0..<regionCount).filter { !microIndices.contains($0) }
            var idx = 0
            while leftover > 0 { targetSizes[nonMicro[idx % nonMicro.count]] += 1; leftover -= 1; idx += 1 }
        }

        // MARK: Step 2 — Place seed cells

        var map = Array(repeating: Array(repeating: -1, count: size), count: size)
        var seeds: [(Int, Int)] = []
        var seedAttempts = 0

        while seeds.count < regionCount && seedAttempts < size * size * 10 {
            seedAttempts += 1
            let r = Int.random(in: 0..<size, using: &rng)
            let c = Int.random(in: 0..<size, using: &rng)
            if map[r][c] == -1 { map[r][c] = seeds.count; seeds.append((r, c)) }
        }
        if seeds.count < regionCount {
            outer: for r in 0..<size {
                for c in 0..<size where map[r][c] == -1 {
                    map[r][c] = seeds.count; seeds.append((r, c))
                    if seeds.count == regionCount { break outer }
                }
            }
        }

        // MARK: Step 3 — Flood-fill with per-region mode and momentum

        var momentum: [Int] = (0..<regionCount).map { _ in Int.random(in: 0..<4, using: &rng) }
        let snakeMomentumP: Double = difficulty == .expert ? 0.80 : 0.65

        var frontiers: [[(Int, Int)]] = seeds.enumerated().map { [($1.0, $1.1)] }
        var regionSizes = Array(repeating: 1, count: regionCount)
        var activeRegions = Set(0..<regionCount)

        let maxIter = size * size * regionCount * 6
        var iter = 0

        while !activeRegions.isEmpty && iter < maxIter {
            iter += 1
            guard let id = activeRegions.randomElement(using: &rng) else { break }

            if regionSizes[id] >= targetSizes[id] { activeRegions.remove(id); continue }

            let frontier = frontiers[id].filter { cell in
                directions.contains(where: { d in
                    let nr = cell.0 + d.0; let nc = cell.1 + d.1
                    return nr >= 0 && nr < size && nc >= 0 && nc < size && map[nr][nc] == -1
                })
            }
            if frontier.isEmpty { activeRegions.remove(id); continue }

            let expandFrom: (Int, Int) = modes[id] == .snake
                ? (frontier.last ?? frontier[Int.random(in: 0..<frontier.count, using: &rng)])
                : frontier[Int.random(in: 0..<frontier.count, using: &rng)]

            let freeNeighbours: [(Int, (Int, Int))] = directions.enumerated().compactMap { (di, d) in
                let nr = expandFrom.0 + d.0; let nc = expandFrom.1 + d.1
                guard nr >= 0, nr < size, nc >= 0, nc < size, map[nr][nc] == -1 else { return nil }
                return (di, (nr, nc))
            }
            guard !freeNeighbours.isEmpty else { continue }

            let chosen: (Int, Int)
            if modes[id] == .snake {
                let cur = momentum[id]
                if let match = freeNeighbours.first(where: { $0.0 == cur }),
                   Double.random(in: 0...1, using: &rng) < snakeMomentumP {
                    chosen = match.1
                } else {
                    let pick = freeNeighbours[Int.random(in: 0..<freeNeighbours.count, using: &rng)]
                    chosen = pick.1; momentum[id] = pick.0
                }
            } else {
                chosen = freeNeighbours[Int.random(in: 0..<freeNeighbours.count, using: &rng)].1
            }

            map[chosen.0][chosen.1] = id
            regionSizes[id] += 1
            frontiers[id].append(chosen)
        }

        // MARK: Step 4 — Fill unassigned cells

        var changed = true
        while changed {
            changed = false
            for r in 0..<size {
                for c in 0..<size where map[r][c] == -1 {
                    for d in directions {
                        let nr = r + d.0; let nc = c + d.1
                        if nr >= 0, nr < size, nc >= 0, nc < size, map[nr][nc] != -1 {
                            map[r][c] = map[nr][nc]; changed = true; break
                        }
                    }
                }
            }
        }
        for r in 0..<size {
            for c in 0..<size where map[r][c] == -1 {
                map[r][c] = Int.random(in: 0..<regionCount, using: &rng)
            }
        }

        // MARK: Step 5 — Connectivity repair
        // BFS within each region. Any cell not reachable from the region's main body
        // is a stray — reassign it to the most common adjacent region ID.
        // Repeat until the map is fully connected.

        map = repairConnectivity(map: map, size: size, regionCount: regionCount)

        return map
    }

    // Reassigns stray (disconnected) cells until every region is a single connected body.
    private nonisolated static func repairConnectivity(
        map: [[Int]], size: Int, regionCount: Int
    ) -> [[Int]] {
        var map = map
        let directions = [(0,1),(0,-1),(1,0),(-1,0)]
        var anyStray = true

        while anyStray {
            anyStray = false

            for rid in 0..<regionCount {
                // Collect all cells belonging to this region
                var cells: [(Int, Int)] = []
                for r in 0..<size { for c in 0..<size where map[r][c] == rid { cells.append((r, c)) } }
                guard cells.count > 1 else { continue }

                // BFS from the first cell within the region's own cells
                var visited = Set(cells.map { $0.0 * size + $0.1 })
                var queue   = [cells[0]]
                var reachable = Set<Int>()
                reachable.insert(cells[0].0 * size + cells[0].1)

                while !queue.isEmpty {
                    let curr = queue.removeFirst()
                    for d in directions {
                        let nr = curr.0 + d.0; let nc = curr.1 + d.1
                        let key = nr * size + nc
                        guard nr >= 0, nr < size, nc >= 0, nc < size else { continue }
                        guard map[nr][nc] == rid, !reachable.contains(key) else { continue }
                        reachable.insert(key)
                        queue.append((nr, nc))
                    }
                }

                // Cells not reachable from the main body are strays
                for cell in cells where !reachable.contains(cell.0 * size + cell.1) {
                    anyStray = true

                    // Count adjacent region IDs (excluding own region)
                    var neighbourCounts: [Int: Int] = [:]
                    for d in directions {
                        let nr = cell.0 + d.0; let nc = cell.1 + d.1
                        guard nr >= 0, nr < size, nc >= 0, nc < size else { continue }
                        let nrid = map[nr][nc]
                        if nrid != rid { neighbourCounts[nrid, default: 0] += 1 }
                    }

                    // Reassign to the most common neighbouring region
                    if let best = neighbourCounts.max(by: { $0.value < $1.value }) {
                        map[cell.0][cell.1] = best.key
                    }
                }
            }
        }

        return map
    }
}
