//
//  PuzzleEngine.swift
//  RestIQ
//
//  Created by Alfin Baby on 12/10/25.
//

import Foundation
import Combine

enum CellState: Int, Codable {
    case empty
    case markedX
    case queen
}

final class PuzzleEngine: ObservableObject {
    @Published var board: [[CellState]]
    let size: Int
    let regionMap: [[Int]]

    init(size: Int, regionMap: [[Int]]) {
        precondition(regionMap.count == size && regionMap.allSatisfy({ $0.count == size }),
                     "Region map must match grid size.")
        self.size = size
        self.regionMap = regionMap
        self.board = Array(repeating: Array(repeating: .empty, count: size), count: size)
    }

    // MARK: - Tap Cycle
    func tapCell(row: Int, col: Int) {
        switch board[row][col] {
        case .empty: board[row][col] = .markedX
        case .markedX: board[row][col] = .queen
        case .queen: board[row][col] = .empty
        }
    }

    // MARK: - Validation Logic
    func isValidPlacement(row: Int, col: Int) -> Bool {
        guard board[row][col] == .queen else { return true }

        // Row and Column uniqueness
        for i in 0..<size {
            if i != row && board[i][col] == .queen { return false }
            if i != col && board[row][i] == .queen { return false }
        }

        // Region uniqueness
        let regionID = regionMap[row][col]
        for r in 0..<size {
            for c in 0..<size where regionMap[r][c] == regionID && !(r == row && c == col) {
                if board[r][c] == .queen { return false }
            }
        }

        // Adjacency rule — no 8-way neighbors
        for dr in -1...1 {
            for dc in -1...1 {
                if dr == 0 && dc == 0 { continue }
                let nr = row + dr, nc = col + dc
                if nr >= 0, nr < size, nc >= 0, nc < size,
                   board[nr][nc] == .queen {
                    return false
                }
            }
        }

        return true
    }

    // MARK: - Completion Check
    func checkIfSolved() -> Bool {
        // Must have exactly N queens total
        let totalQueens = board.flatMap { $0 }.filter { $0 == .queen }.count
        if totalQueens != size { return false }

        // All queens valid by placement rules
        for r in 0..<size {
            for c in 0..<size where board[r][c] == .queen {
                if !isValidPlacement(row: r, col: c) { return false }
            }
        }

        // One queen per row
        for r in 0..<size where board[r].filter({ $0 == .queen }).count != 1 {
            return false
        }

        // One queen per column
        for c in 0..<size {
            let colQueens = (0..<size).filter { board[$0][c] == .queen }.count
            if colQueens != 1 { return false }
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

    // MARK: - Reset
    func resetBoard() {
        for r in 0..<size { for c in 0..<size { board[r][c] = .empty } }
    }

    // MARK: - Helpers
    var uniqueRegionIDs: [Int] {
        Set(regionMap.flatMap { $0 }).sorted()
    }
}
