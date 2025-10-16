//
//  PuzzleEngine.swift
//  RestIQ
//
//  Created by Alfin Baby on 12/10/25.
//
// Core puzzle model. Keeps board state and implements rules.
// PuzzleEngine is an observable model so ViewModels can observe changes.

import Foundation
import Combine

/// Cell states for UI and logic.
enum CellState: Int, Codable {
    case empty
    case markedX
    case queen
}

/// PuzzleEngine contains only game state and rule checks.
/// Marked @MainActor to keep UI-friendly access and to be safely mutated on main thread.
@MainActor
final class PuzzleEngine: ObservableObject {
    @Published private(set) var board: [[CellState]]
    let size: Int
    let regionMap: [[Int]]

    /// Initialize with square region map. Precondition enforces rule #1.
    init(size: Int, regionMap: [[Int]]) {
        precondition(regionMap.count == size && regionMap.allSatisfy({ $0.count == size }),
                     "Region map must be square and match grid size")
        self.size = size
        self.regionMap = regionMap
        self.board = Array(repeating: Array(repeating: .empty, count: size), count: size)
    }

    // MARK: - Mutations

    /// Tap cycles: empty -> X -> queen -> empty
    func tapCell(row: Int, col: Int) {
        switch board[row][col] {
        case .empty: board[row][col] = .markedX
        case .markedX: board[row][col] = .queen
        case .queen: board[row][col] = .empty
        }
    }

    func resetBoard() {
        for r in 0..<size {
            for c in 0..<size {
                board[r][c] = .empty
            }
        }
    }

    // MARK: - Validation logic (rules 4,5,6,7)

    /// True if the queen at (row,col) obeys all placement constraints.
    /// Returns true for non-queen cells to simplify UI checks.
    func isValidPlacement(row: Int, col: Int) -> Bool {
        guard board[row][col] == .queen else { return true }

        // Row uniqueness
        for c in 0..<size where c != col {
            if board[row][c] == .queen { return false }
        }

        // Column uniqueness
        for r in 0..<size where r != row {
            if board[r][col] == .queen { return false }
        }

        // Region uniqueness
        let regionID = regionMap[row][col]
        for r in 0..<size {
            for c in 0..<size where regionMap[r][c] == regionID && !(r == row && c == col) {
                if board[r][c] == .queen { return false }
            }
        }

        // Adjacency (no touching in 8 directions)
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

    /// Full solved check enforcing exact counts.
    func checkIfSolved() -> Bool {
        // Must be exactly size queens placed.
        let totalQueens = board.flatMap { $0 }.filter { $0 == .queen }.count
        if totalQueens != size { return false }

        // Every queen must be locally valid.
        for r in 0..<size {
            for c in 0..<size where board[r][c] == .queen {
                if !isValidPlacement(row: r, col: c) { return false }
            }
        }

        // One queen per row and per column (redundant with above but explicit)
        for r in 0..<size {
            if board[r].filter({ $0 == .queen }).count != 1 { return false }
        }
        for c in 0..<size {
            var count = 0
            for r in 0..<size where board[r][c] == .queen { count += 1 }
            if count != 1 { return false }
        }

        // One queen per region
        var regionCounts: [Int: Int] = [:]
        for r in 0..<size {
            for c in 0..<size where board[r][c] == .queen {
                regionCounts[regionMap[r][c], default: 0] += 1
            }
        }
        if regionCounts.values.contains(where: { $0 != 1 }) { return false }

        return true
    }

    // Helpers
    var uniqueRegionIDs: [Int] {
        Set(regionMap.flatMap { $0 }).sorted()
    }
}
