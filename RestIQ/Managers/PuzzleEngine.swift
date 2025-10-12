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
        self.size = size
        self.regionMap = regionMap
        self.board = Array(repeating: Array(repeating: .empty, count: size), count: size)
    }

    // MARK: - Tap Cycle
    func tapCell(row: Int, col: Int) {
        switch board[row][col] {
        case .empty:
            board[row][col] = .markedX
        case .markedX:
            board[row][col] = .queen
        case .queen:
            board[row][col] = .empty
        }
    }

    // MARK: - Validation Logic
    func isValidPlacement(row: Int, col: Int) -> Bool {
        guard board[row][col] == .queen else { return true }

        // Row and column check
        for i in 0..<size {
            if i != row && board[i][col] == .queen { return false }
            if i != col && board[row][i] == .queen { return false }
        }

        // Diagonal check
        for i in 0..<size {
            let diff = abs(row - i)
            if diff == 0 { continue }
            if col + diff < size && board[i][col + diff] == .queen { return false }
            if col - diff >= 0 && board[i][col - diff] == .queen { return false }
        }

        // Adjacent (no touching)
        for dr in -1...1 {
            for dc in -1...1 {
                if dr == 0 && dc == 0 { continue }
                let nr = row + dr, nc = col + dc
                if nr >= 0, nr < size, nc >= 0, nc < size {
                    if board[nr][nc] == .queen { return false }
                }
            }
        }

        // Region check — only one queen per region
        let regionID = regionMap[row][col]
        for r in 0..<size {
            for c in 0..<size where regionMap[r][c] == regionID && !(r == row && c == col) {
                if board[r][c] == .queen { return false }
            }
        }

        return true
    }

    // MARK: - Puzzle Completion
    func checkIfSolved() -> Bool {
        // All queens must be valid
        for r in 0..<size {
            for c in 0..<size where board[r][c] == .queen {
                if !isValidPlacement(row: r, col: c) { return false }
            }
        }

        // Exactly one queen per row and column
        for i in 0..<size {
            if board[i].filter({ $0 == .queen }).count != 1 { return false }
            if board.map({ $0[i] }).filter({ $0 == .queen }).count != 1 { return false }
        }

        // Exactly one queen per region
        var regionCount: [Int: Int] = [:]
        for r in 0..<size {
            for c in 0..<size where board[r][c] == .queen {
                let id = regionMap[r][c]
                regionCount[id, default: 0] += 1
            }
        }
        if regionCount.values.contains(where: { $0 != 1 }) { return false }

        return true
    }

    // MARK: - Utility
    func resetBoard() {
        for r in 0..<size {
            for c in 0..<size {
                board[r][c] = .empty
            }
        }
    }

    var uniqueRegionIDs: [Int] {
        Set(regionMap.flatMap { $0 }).sorted()
    }
}
