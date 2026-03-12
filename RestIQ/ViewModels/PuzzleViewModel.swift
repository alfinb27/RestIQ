//
//  PuzzleViewModel.swift
//  RestIQ
//
//  Updated: auto-place crosses now works — marks X on all cells eliminated
//  by a placed queen, and clears them when the queen is removed.
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
    @Published var generationFailed = false
    @Published var elapsedSeconds = 0

    // Settings toggles — persisted to UserDefaults so they survive navigation and relaunch
    @Published var showClock: Bool = UserDefaults.standard.object(forKey: "setting.showClock") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showClock, forKey: "setting.showClock") }
    }
    @Published var autoPlaceCrosses: Bool = UserDefaults.standard.bool(forKey: "setting.autoPlaceCrosses") {
        didSet { UserDefaults.standard.set(autoPlaceCrosses, forKey: "setting.autoPlaceCrosses") }
    }

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

    // Drag undo grouping
    private var currentDragUndoGroup: [CellChange]? = nil

    // Conflict highlighting
    @Published private(set) var invalidPositions: Set<BoardPos> = []

    struct BoardPos: Hashable {
        let r: Int
        let c: Int
    }

    init(level: String) {
        self.level = level
        switch level {
        case "Easy":   gridSize = 6; difficulty = .easy
        case "Medium": gridSize = 7; difficulty = .medium
        case "Hard":   gridSize = 8; difficulty = .hard
        case "Expert": gridSize = 9; difficulty = .expert
        default:       gridSize = 6; difficulty = .easy
        }
        Task { await generateDailyPuzzle() }
    }

    // MARK: - Daily Puzzle Generation

    func generateDailyPuzzle() async {
        isLoading = true
        generationFailed = false
        stopTimer()
        if let cached = await DailyChallengeManager.shared.generateDailyPuzzle(for: level) {
            engine = cached
        }
        guard let engine else {
            print("Puzzle generation failed for \(level)")
            isLoading = false
            generationFailed = true
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

        if let record = UserStatsManager.shared.completion(for: level) {
            elapsedSeconds = record.elapsedSeconds
            showCompletion = true
        } else {
            elapsedSeconds = 0
            startTimer()
        }

        invalidPositions = []
    }

    // MARK: - Cell Interaction

    func tapCell(row: Int, col: Int) {
        guard let engine else { return }
        Task {
            let prev = board[row][col]

            let changes = await engine.tapCell(row: row, col: col)
            for change in changes { board[change.row][change.col] = change.newState }

            var undoGroup = [CellChange(row: row, col: col, newState: prev)]

            if board[row][col] == .queen {
                let conflicts = await engine.conflictTypesForQueen(at: row, col: col)
                if !conflicts.isEmpty { Haptics.warning() }

                if autoPlaceCrosses {
                    let crosses = await placeCrossesAroundQueen(row: row, col: col, engine: engine)
                    undoGroup.append(contentsOf: crosses)
                }
            } else if prev == .queen {
                // Queen removed — clear auto-crosses that are no longer justified
                if autoPlaceCrosses {
                    let cleared = await clearCrossesForRemovedQueen(row: row, col: col, engine: engine)
                    undoGroup.append(contentsOf: cleared)
                }
            }

            pushUndoGroup(undoGroup)
            await computeInvalidPositions()

            if await engine.checkIfSolved() {
                handleSolved()
            }
        }
    }

    // MARK: - Auto-Cross Helpers

    /// Marks X on every empty cell eliminated by a queen at (row, col).
    /// Returns reverse changes (restore to .empty) for undo.
    private func placeCrossesAroundQueen(row: Int, col: Int, engine: QueensPuzzleEngine) async -> [CellChange] {
        var reverseChanges: [CellChange] = []
        let regionID = regionMap[row][col]

        for r in 0..<gridSize {
            for c in 0..<gridSize {
                guard board[r][c] == .empty else { continue }
                guard !(r == row && c == col) else { continue }

                let eliminated = r == row
                    || c == col
                    || regionMap[r][c] == regionID
                    || (abs(r - row) <= 1 && abs(c - col) <= 1)

                if eliminated {
                    reverseChanges.append(CellChange(row: r, col: c, newState: .empty))
                    if let ch = await engine.setCell(.markedX, row: r, col: c) {
                        board[ch.row][ch.col] = ch.newState
                    }
                }
            }
        }
        return reverseChanges
    }

    /// When a queen is removed, clears auto-placed X marks that are no longer
    /// justified by any remaining queen on the board.
    private func clearCrossesForRemovedQueen(row: Int, col: Int, engine: QueensPuzzleEngine) async -> [CellChange] {
        var reverseChanges: [CellChange] = []
        let regionID = regionMap[row][col]

        for r in 0..<gridSize {
            for c in 0..<gridSize {
                guard board[r][c] == .markedX else { continue }

                let affectedByRemovedQueen = r == row
                    || c == col
                    || regionMap[r][c] == regionID
                    || (abs(r - row) <= 1 && abs(c - col) <= 1)

                guard affectedByRemovedQueen else { continue }

                if !isEliminatedByAnyQueen(r: r, c: c) {
                    reverseChanges.append(CellChange(row: r, col: c, newState: .markedX))
                    if let ch = await engine.setCell(.empty, row: r, col: c) {
                        board[ch.row][ch.col] = ch.newState
                    }
                }
            }
        }
        return reverseChanges
    }

    /// Returns true if any queen currently on the board eliminates cell (r, c).
    private func isEliminatedByAnyQueen(r: Int, c: Int) -> Bool {
        let regionID = regionMap[r][c]
        for qr in 0..<gridSize {
            for qc in 0..<gridSize {
                guard board[qr][qc] == .queen else { continue }
                if qr == r || qc == c
                    || regionMap[qr][qc] == regionID
                    || (abs(qr - r) <= 1 && abs(qc - c) <= 1) {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Drag Grouping

    func beginCrossDrag() {
        currentDragUndoGroup = []
    }

    func endCrossDrag() {
        if let group = currentDragUndoGroup, !group.isEmpty {
            pushUndoGroup(group)
        }
        currentDragUndoGroup = nil
    }

    // MARK: - Cross Setter (drag)

    func setCross(row: Int, col: Int, state: CellState) {
        guard let engine else { return }
        Task {
            let previous = board[row][col]
            if previous == state { return }

            if let change = await engine.setCell(state, row: row, col: col) {
                board[change.row][change.col] = change.newState
            } else {
                board[row][col] = state
            }

            let reverse = CellChange(row: row, col: col, newState: previous)

            if var group = currentDragUndoGroup {
                group.append(reverse)
                currentDragUndoGroup = group
            } else {
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
            guard let (tr, tc) = canonical.first(where: { board[$0.0][$0.1] != .queen }) else { return }
            var reverseGroup: [CellChange] = []
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

            let prevAtTarget = board[tr][tc]
            if prevAtTarget != .queen {
                reverseGroup.append(CellChange(row: tr, col: tc, newState: prevAtTarget))
                if let ch = await engine.setCell(.queen, row: tr, col: tc) { board[ch.row][ch.col] = ch.newState } else { board[tr][tc] = .queen }
            }

            if !reverseGroup.isEmpty { pushUndoGroup(reverseGroup) }
            hintsUsed += 1
            Haptics.soft()
            await computeInvalidPositions()
            if await engine.checkIfSolved() { handleSolved() }
        }
    }

    // MARK: - Solve Handler

    private func handleSolved() {
        stopTimer()
        Haptics.success()
        showCompletion = true
        UserStatsManager.shared.recordCompletion(
            level: level,
            elapsedSeconds: elapsedSeconds,
            hintsUsed: hintsUsed
        )
    }

    // MARK: - Invalid Position Tracking

    private func computeInvalidPositions() async {
        guard let engine else { return }
        var invalid = Set<BoardPos>()
        for r in 0..<board.count {
            for c in 0..<board.count where board[r][c] == .queen {
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
            for ch in changes { board[ch.row][ch.col] = ch.newState }
            elapsedSeconds = 0
            invalidPositions = []
            undoStack.removeAll()
            canUndo = false
            hintsUsed = 0
            showCompletion = false
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

    // MARK: - Region Colors

    private func buildRegionColors() {
        let ids = Set(regionMap.flatMap { $0 })
        var colors: [Int: Color] = [:]

        let palette: [Color] = [
            Color(.displayP3, red: 205/255, green: 190/255, blue: 245/255),
            Color(.displayP3, red: 245/255, green: 195/255, blue: 215/255),
            Color(.displayP3, red: 191/255, green: 224/255, blue: 187/255),
            Color(.displayP3, red: 188/255, green: 211/255, blue: 247/255),
            Color(.displayP3, red: 250/255, green: 242/255, blue: 185/255),
            Color(.displayP3, red: 240/255, green: 160/255, blue: 160/255),
            Color(.displayP3, red: 250/255, green: 195/255, blue: 155/255),
            Color(.displayP3, red: 190/255, green: 190/255, blue: 190/255),
            Color(.displayP3, red: 185/255, green: 235/255, blue: 235/255)
        ]

        for (i, id) in ids.sorted().enumerated() {
            colors[id] = palette[i % palette.count].opacity(0.75)
        }

        regionColors = colors
    }

    var size: Int { gridSize }
}
