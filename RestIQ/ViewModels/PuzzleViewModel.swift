//
//  PuzzleViewModel.swift
//  RestIQ
//
//  Created by Alfin Baby on 16/10/25.
//  Updated: drag cross undo grouping support. setCross now records undo; beginCrossDrag()/endCrossDrag() available for grouping.
///

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

    // Settings toggles (gear sheet)
    @Published var showClock: Bool = true
    @Published var autoPlaceCrosses: Bool = false

    // Undo / Hint state
    @Published private(set) var canUndo = false
    @Published private(set) var hintsUsed = 0
    let maxHints = 3

    private var undoStack: [[CellChange]] = []
    private var timerTask: Task<Void, Never>?
    private var engine: QueensPuzzleEngine?
    private let gridSize: Int
    private let difficulty: Difficulty
    private let level: String

    // Drag undo grouping: collect changes during a drag then push as single undo group
    private var currentDragUndoGroup: [CellChange]? = nil

    // Conflict highlighting only (no toast)
    @Published private(set) var invalidPositions: Set<BoardPos> = []

    struct BoardPos: Hashable {
        let r: Int
        let c: Int
    }

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
        invalidPositions = []
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

            // Only highlight conflicts + haptic, no toast message
            if board[row][col] == .queen {
                let conflicts = await engine.conflictTypesForQueen(at: row, col: col)
                if !conflicts.isEmpty {
                    Haptics.warning()
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

    // MARK: - Drag grouping API
    /// Call when drag across grid begins (e.g., on drag start).
    func beginCrossDrag() {
        // start a new group; if a previous group exists, discard it (shouldn't happen)
        currentDragUndoGroup = []
    }

    /// Call when drag ends (e.g., on drag end) to commit the group to undo stack.
    func endCrossDrag() {
        if let group = currentDragUndoGroup, !group.isEmpty {
            pushUndoGroup(group)
        }
        currentDragUndoGroup = nil
    }

    // MARK: - Cross Setter (used for drag)
    /// Sets a cross (.markedX) or clears it (.empty). Records undo.
    func setCross(row: Int, col: Int, state: CellState) {
        guard let engine else { return }
        Task {
            // capture previous state for undo
            let previous = board[row][col]
            // if no-op, skip
            if previous == state { return }

            if let change = await engine.setCell(state, row: row, col: col) {
                board[change.row][change.col] = change.newState
            } else {
                board[row][col] = state
            }

            // Build reverse change (to restore previous state on undo)
            let reverse = CellChange(row: row, col: col, newState: previous)

            if var group = currentDragUndoGroup {
                // append to existing drag group
                group.append(reverse)
                currentDragUndoGroup = group
            } else {
                // single change, push immediately as its own undo group
                pushUndoGroup([reverse])
            }

            await computeInvalidPositions()
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
            undoStack.removeAll()
            canUndo = false
            hintsUsed = 0
            startTimer()
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

    // MARK: - Region Colors (uses your pastel palette)
    private func buildRegionColors() {
        let ids = Set(regionMap.flatMap { $0 })
        var colors: [Int: Color] = [:]

        let palette: [Color] = [
            Color(.displayP3, red: 205/255, green: 190/255, blue: 245/255), // violet
            Color(.displayP3, red: 245/255, green: 195/255, blue: 215/255), // pink
            Color(.displayP3, red: 191/255, green: 224/255, blue: 187/255), // green
            Color(.displayP3, red: 188/255, green: 211/255, blue: 247/255), // blue
            Color(.displayP3, red: 250/255, green: 242/255, blue: 185/255), // yellow
            Color(.displayP3, red: 240/255, green: 160/255, blue: 160/255), // red
            Color(.displayP3, red: 250/255, green: 195/255, blue: 155/255), // orange
            Color(.displayP3, red: 190/255, green: 190/255, blue: 190/255), // grey
            Color(.displayP3, red: 185/255, green: 235/255, blue: 235/255)  // cyan
        ]

        for (i, id) in ids.sorted().enumerated() {
            colors[id] = palette[i % palette.count].opacity(0.75)
        }

        regionColors = colors
    }

    var size: Int { gridSize }
}
