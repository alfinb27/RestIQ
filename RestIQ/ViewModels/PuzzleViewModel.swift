//
//  PuzzleViewModel.swift
//  RestIQ
//
//  Created by Alfin Baby on 16/10/25.
//  Updated: Performance — precompute invalid positions and region borders.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class PuzzleViewModel: ObservableObject {
    @Published private(set) var engine: PuzzleEngine
    @Published var isTimerRunning: Bool = false
    @Published var elapsedSeconds: Int = 0
    @Published var regionColors: [Int: Color] = [:]
    @Published var showCompletion: Bool = false

    /// Derived, performance-oriented state used by the view
    @Published private(set) var invalidPositions: Set<BoardPos> = []
    @Published private(set) var borderFlags: [[BorderFlags]] = []

    private var timerTask: Task<Void, Never>?
    private let level: String
    private let gridSize: Int

    init(level: String) {
        self.level = level
        switch level {
        case "Easy": gridSize = 6
        case "Medium": gridSize = 7
        case "Hard": gridSize = 8
        case "Expert": gridSize = 9
        default: gridSize = 6
        }

        self.engine = DailyChallengeManager.shared.generatePuzzle(for: level)
        buildRegionColors()
        computeDerivedState() // initial derived state
    }

    // MARK: - Actions

    func tapCell(row: Int, col: Int) {
        engine.tapCell(row: row, col: col)
        computeDerivedState()

        if engine.checkIfSolved() {
            stopTimer()
            showCompletion = true
        }
    }

    func resetBoard() {
        engine.resetBoard()
        elapsedSeconds = 0
        computeDerivedState()
        startTimer()
    }

    // MARK: - Derived state computation (fast)

    /// Small struct to identify board coordinates cheaply.
    struct BoardPos: Hashable, Codable {
        let r: Int
        let c: Int
    }

    /// Border flags for a cell. Small value type cheap to read in views.
    struct BorderFlags {
        var top: Bool = false
        var bottom: Bool = false
        var left: Bool = false
        var right: Bool = false
    }

    /// Recompute invalid queen locations and region border map.
    /// This avoids expensive `isValidPlacement()` calls on every cell during view rendering.
    private func computeDerivedState() {
        computeInvalidPositionsFast()
        computeRegionBorderFlags()
    }

    /// Compute invalid queen positions using counts and adjacency checks.
    /// Complexity dominated by scanning the board once and checking queens list (<= size).
    private func computeInvalidPositionsFast() {
        var queens: [BoardPos] = []
        let size = engine.size

        for r in 0..<size {
            for c in 0..<size {
                if engine.board[r][c] == .queen {
                    queens.append(BoardPos(r: r, c: c))
                }
            }
        }

        // Quick fail: if queen count not equal to size then some positions may be invalid,
        // but we still detect local conflicts (rows, cols, region, adjacency).
        var rowCounts = [Int: Int]()
        var colCounts = [Int: Int]()
        var regionCounts = [Int: Int]()

        for q in queens {
            rowCounts[q.r, default: 0] += 1
            colCounts[q.c, default: 0] += 1
            let rid = engine.regionMap[q.r][q.c]
            regionCounts[rid, default: 0] += 1
        }

        var invalid = Set<BoardPos>()

        // Row / column / region conflicts
        for q in queens {
            if rowCounts[q.r, default: 0] > 1 { invalid.insert(q); continue }
            if colCounts[q.c, default: 0] > 1 { invalid.insert(q); continue }
            let rid = engine.regionMap[q.r][q.c]
            if regionCounts[rid, default: 0] > 1 { invalid.insert(q); continue }
        }

        // Adjacency conflicts (8-neighbour)
        let deltas = [-1, 0, 1]
        let queenSet = Set(queens)
        for q in queens {
            outer: for dr in deltas {
                for dc in deltas {
                    if dr == 0 && dc == 0 { continue }
                    let nr = q.r + dr
                    let nc = q.c + dc
                    if nr >= 0, nr < size, nc >= 0, nc < size {
                        let pos = BoardPos(r: nr, c: nc)
                        if queenSet.contains(pos) {
                            invalid.insert(q)
                            break outer
                        }
                    }
                }
            }
        }

        // If total queens != size then any queen may be considered "incomplete" for solved state,
        // but visually we mark only those conflicting by rules above (the solved check handles count).
        invalidPositions = invalid
    }

    /// Compute thin border flags for each cell by comparing regionMap neighbors.
    private func computeRegionBorderFlags() {
        let size = engine.size
        var flags = Array(repeating: Array(repeating: BorderFlags(), count: size), count: size)
        for r in 0..<size {
            for c in 0..<size {
                let current = engine.regionMap[r][c]
                if r > 0 && engine.regionMap[r - 1][c] != current { flags[r][c].top = true }
                if r < size - 1 && engine.regionMap[r + 1][c] != current { flags[r][c].bottom = true }
                if c > 0 && engine.regionMap[r][c - 1] != current { flags[r][c].left = true }
                if c < size - 1 && engine.regionMap[r][c + 1] != current { flags[r][c].right = true }
            }
        }
        borderFlags = flags
    }

    // MARK: - Timer

    func startTimer() {
        guard timerTask == nil else { return }
        isTimerRunning = true

        timerTask = Task { [weak self] in
            while let self = self, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if self.isTimerRunning {
                    self.elapsedSeconds += 1
                } else {
                    break
                }
            }
        }
    }

    func stopTimer() {
        isTimerRunning = false
        timerTask?.cancel()
        timerTask = nil
    }

    func formattedElapsed() -> String {
        String(format: "%d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)
    }

    // MARK: - Visuals

    func buildRegionColors() {
        let ids = engine.uniqueRegionIDs
        let total = max(ids.count, 1)
        var map: [Int: Color] = [:]
        for (index, id) in ids.enumerated() {
            let hue = Double(index) / Double(total)
            map[id] = Color(hue: hue, saturation: 0.5, brightness: 0.95).opacity(0.35)
        }
        regionColors = map
    }

    var size: Int { gridSize }

    // Helpers for view usage
    func isPositionInvalid(_ r: Int, _ c: Int) -> Bool {
        invalidPositions.contains(BoardPos(r: r, c: c))
    }

    func borderFlagsFor(_ r: Int, _ c: Int) -> BorderFlags {
        guard r >= 0, r < borderFlags.count, c >= 0, c < borderFlags[r].count else { return BorderFlags() }
        return borderFlags[r][c]
    }
}
