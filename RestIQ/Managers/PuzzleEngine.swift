//
//  PuzzleEngine.swift
//  RestIQ
//
//  Created by Alfin Baby on 12/10/25.
//

import Foundation
import Combine

class PuzzleEngine: ObservableObject {
    @Published var board: [[Bool]]
    private var size: Int

    init(size: Int) {
        self.size = size
        self.board = Array(repeating: Array(repeating: false, count: size), count: size)
    }

    func toggleQueen(atRow row: Int, column col: Int) {
        board[row][col].toggle()
    }

    func isValidPlacement(row: Int, col: Int) -> Bool {
        for i in 0..<size {
            if i != row && board[i][col] { return false }
        }
        for j in 0..<size {
            if j != col && board[row][j] { return false }
        }
        for i in 0..<size {
            let j1 = col + (row - i)
            let j2 = col - (row - i)
            if j1 >= 0 && j1 < size && i != row && board[i][j1] { return false }
            if j2 >= 0 && j2 < size && i != row && board[i][j2] { return false }
        }
        return true
    }

    func checkIfSolved() -> Bool {
        let totalQueens = board.flatMap { $0 }.filter { $0 }.count
        if totalQueens != size { return false }

        for row in 0..<size {
            for col in 0..<size {
                if board[row][col] && !isValidPlacement(row: row, col: col) {
                    return false
                }
            }
        }
        return true
    }

    func resetBoard() {
        board = Array(repeating: Array(repeating: false, count: size), count: size)
    }
}
