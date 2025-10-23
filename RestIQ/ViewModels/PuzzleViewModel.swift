//
//  PuzzleViewModel.swift
//  RestIQ
//
//  Created by Alfin Baby on 16/10/25.
//  Updated: Undo/Hint UI state, settings toggles (showClock, autoPlaceCrosses).
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class PuzzleViewModel: ObservableObject {
    @Published var board: [[CellState]] = []
    @Published var regionMap: [[Int]] = []
    @Published var regionColors: [Int: Color] = [:]
    @Published var showCompletion = false
    @Published var isLoading = true
    @Published var elapsedSeconds = 0
    @Published var conflictMessage: String? = nil

    // Settings toggles (gear sheet)
    @Published var showClock: Bool = true
    @Published var autoPlaceCrosses: Bool = false // reserved for future logic

    // Undo / Hint state
    @Published private(set) var canUndo = false
    @Published private(set) var hintsUsed = 0
    let maxHints = 3

    private var undoStack: [[CellChange]] = [] // each entry is a reversible group

    private var timerTask: Task<Void, Never>?
    private var engine: QueensPuzzleEngine?
    private let gridSize: Int
    private let difficulty: Difficulty
    private let level: String

    init(level: String) {
        self.level = level
        switch level {
        case "Easy": gridSize = 6; difficulty = .easy
        case "Medium": gridSize = 7; difficulty = .medium
        case "Hard": gridSize = 8; difficulty = .hard
        case "Expert": gridSize = 9; difficulty = .expert
        default: gridSize = 6; difficulty = .easy
        }
        Task { await generateDailyPuzzle() }
    }

    // MARK: - Daily Puzzle Generation
    func generateDailyPuzzle() async {
        isLoading = true
        stopTimer()
        if let cached = await DailyChallengeManager.shared.generateDailyPuzzle(for: level) {
            engine = cached
        }
        guard let engine else {
            print("Puzzle generation failed for \(level)")
            isLoading = false
            return
        }

        let snapshot = await engine.snapshot()
        board = snapshot.board
        regionMap = snapshot.regionMap
        buildRegionColors()
        isLoading = false
        showCompletion = false
        undoStack.removeAll()
        canUndo = false
        hintsUsed = 0
        elapsedSeconds = 0
        startTimer()
    }

    // MARK: - Cell Interaction
    func tapCell(row: Int, col: Int) {
        guard let engine else { return }
        Task {
            let prev = board[row][col]
            let changes = await engine.tapCell(row: row, col: col)
            for change in changes {
                board[change.row][change.col] = change.newState
            }
            // allow undo for a single tap
            pushUndoGroup([CellChange(row: row, col: col, newState: prev)])

            // Conflict detection toast + haptic
            if board[row][col] == .queen {
                let conflicts = await engine.conflictTypesForQueen(at: row, col: col)
                if !conflicts.isEmpty {
                    conflictMessage = "Conflict: " + conflicts.joined(separator: ", ")
                    Haptics.warning()
                    dismissToastAfterDelay()
                }
            }

            await computeInvalidPositions()

            if await engine.checkIfSolved() {
                stopTimer()
                Haptics.success()
                showCompletion = true
            }
        }
    }

    // MARK: - Undo
    func undo() {
        guard let engine else { return }
        Task {
            guard let reverseGroup = undoStack.popLast() else { return }
            for rev in reverseGroup {
                if let ch = await engine.setCell(rev.newState, row: rev.row, col: rev.col) {
                    board[ch.row][ch.col] = ch.newState
                } else {
                    board[rev.row][rev.col] = rev.newState
                }
            }
            canUndo = !undoStack.isEmpty
            showCompletion = false
            await computeInvalidPositions()
            Haptics.light()
        }
    }

    private func pushUndoGroup(_ reverse: [CellChange]) {
        undoStack.append(reverse)
        canUndo = true
    }

    // MARK: - Hint
    func revealHint() {
        guard let engine, hintsUsed < maxHints else { return }
        Task {
            let canonical = await engine.getCanonicalSolution()

            // pick first not-yet-correct spot
            guard let (tr, tc) = canonical.first(where: { board[$0.0][$0.1] != .queen }) else { return }
            var reverseGroup: [CellChange] = []

            // clear conflicting queens row/col/region around target
            let targetRID = regionMap[tr][tc]

            for c in 0..<gridSize where c != tc && board[tr][c] == .queen {
                reverseGroup.append(CellChange(row: tr, col: c, newState: .queen))
                if let ch = await engine.setCell(.empty, row: tr, col: c) { board[ch.row][ch.col] = ch.newState } else { board[tr][c] = .empty }
            }
            for r in 0..<gridSize where r != tr && board[r][tc] == .queen {
                reverseGroup.append(CellChange(row: r, col: tc, newState: .queen))
                if let ch = await engine.setCell(.empty, row: r, col: tc) { board[ch.row][ch.col] = ch.newState } else { board[r][tc] = .empty }
            }
            for r in 0..<gridSize {
                for c in 0..<gridSize where regionMap[r][c] == targetRID && !(r == tr && c == tc) && board[r][c] == .queen {
                    reverseGroup.append(CellChange(row: r, col: c, newState: .queen))
                    if let ch = await engine.setCell(.empty, row: r, col: c) { board[ch.row][ch.col] = ch.newState } else { board[r][c] = .empty }
                }
            }
            // place the correct queen
            let prevAtTarget = board[tr][tc]
            if prevAtTarget != .queen {
                reverseGroup.append(CellChange(row: tr, col: tc, newState: prevAtTarget))
                if let ch = await engine.setCell(.queen, row: tr, col: tc) { board[ch.row][ch.col] = ch.newState } else { board[tr][tc] = .queen }
            }

            if !reverseGroup.isEmpty { pushUndoGroup(reverseGroup) }

            hintsUsed += 1
            Haptics.soft()
            await computeInvalidPositions()

            if await engine.checkIfSolved() {
                stopTimer()
                Haptics.success()
                showCompletion = true
            }
        }
    }

    // MARK: - Invalid Position Tracking
    @Published private(set) var invalidPositions: Set<BoardPos> = []

    struct BoardPos: Hashable {
        let r: Int
        let c: Int
    }

    private func computeInvalidPositions() async {
        guard let engine else { return }
        var invalid = Set<BoardPos>()
        let size = board.count

        for r in 0..<size {
            for c in 0..<size where board[r][c] == .queen {
                if !(await engine.isValidPlacement(row: r, col: c)) {
                    invalid.insert(BoardPos(r: r, c: c))
                }
            }
        }
        self.invalidPositions = invalid
    }

    func isPositionInvalid(_ r: Int, _ c: Int) -> Bool {
        invalidPositions.contains(BoardPos(r: r, c: c))
    }

    func resetBoard() {
        guard let engine else { return }
        Task {
            let changes = await engine.resetBoard()
            for ch in changes {
                board[ch.row][ch.col] = ch.newState
            }
            elapsedSeconds = 0
            invalidPositions = []
            conflictMessage = nil
            undoStack.removeAll()
            canUndo = false
            hintsUsed = 0
            startTimer()
        }
    }

    // MARK: - Toast
    private func dismissToastAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.conflictMessage = nil
        }
    }

    // MARK: - Timer
    func startTimer() {
        stopTimer()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self.elapsedSeconds += 1
            }
        }
    }

    func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    func formattedElapsed() -> String {
        String(format: "%d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)
    }

    // MARK: - Region Colors
    private func buildRegionColors() {
        let ids = Set(regionMap.flatMap { $0 })
        var colors: [Int: Color] = [:]
        for id in ids.sorted() {
            let hue = Double((id * 37) % 360) / 360.0
            colors[id] = Color(hue: hue, saturation: 0.45, brightness: 0.92).opacity(0.35)
        }
        regionColors = colors
    }

    var size: Int { gridSize }
}
