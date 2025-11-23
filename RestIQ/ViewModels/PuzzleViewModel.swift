//
//  PuzzleViewModel.swift
//  RestIQ
//
//  Updated to use QueensPuzzleEngineV2 (fully replacing previous engine interaction).
//  Created: ChatGPT
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class PuzzleViewModel: ObservableObject {
    // Board uses V2 types
    @Published var board: [[CellStateV2]] = []
    @Published var regionMap: [[Int]] = []
    @Published var regionColors: [Int: Color] = [:]
    @Published var showCompletion = false
    @Published var isLoading = true
    @Published var elapsedSeconds = 0

    // Settings
    @Published var showClock: Bool = true
    @Published var autoPlaceCrosses: Bool {
        didSet { UserDefaults.standard.set(autoPlaceCrosses, forKey: "autoPlaceCrossesEnabled") }
    }

    // Undo / hints
    @Published private(set) var canUndo = false
    @Published private(set) var hintsUsed = 0
    let maxHints = 3

    private var undoStack: [[CellChangeV2]] = []
    private var timerTask: Task<Void, Never>?
    private var engine: QueensPuzzleEngineV2?
    private let level: String

    // Drag grouping
    private var currentDragUndoGroup: [CellChangeV2]? = nil

    // Invalid highlight
    @Published private(set) var invalidPositions: Set<BoardPos> = []

    struct BoardPos: Hashable {
        let r: Int
        let c: Int
    }

    init(level: String) {
        self.level = level
        self.autoPlaceCrosses = UserDefaults.standard.bool(forKey: "autoPlaceCrossesEnabled")
        Task { await generateDailyPuzzle() }
    }

    func generateDailyPuzzle() async {
        isLoading = true
        stopTimer()
        if let eng = await DailyChallengeManager.shared.generateDailyPuzzle(for: level) {
            engine = eng
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

    // MARK: - Tap handling
    func tapCell(row: Int, col: Int) {
        guard let engine else { return }
        Task {
            let prev = board[row][col]
            let changes = await engine.tapCell(row: row, col: col)

            // empty changes -> engine rejected (e.g., attempted illegal queen); provide feedback
            if changes.isEmpty {
                Haptics.warning()
                await computeInvalidPositions()
                return
            }

            // Apply changes
            for ch in changes {
                board[ch.row][ch.col] = ch.newState
            }

            var undoGroup: [CellChangeV2] = [CellChangeV2(row: row, col: col, newState: prev)]

            // If we placed a queen and autoplace is enabled, ask engine for autoplace results
            if board[row][col] == .queen, autoPlaceCrosses {
                // engine.autoplaceCrossesAfterPlacing will mark crosses on the actor's board and return list
                let placed = await engine.autoplaceCrossesAfterPlacing(row: row, col: col)
                // Apply placements to local board and record reverse actions
                for p in placed {
                    // record reverse (restore to .empty)
                    undoGroup.append(CellChangeV2(row: p.row, col: p.col, newState: .empty))
                    board[p.row][p.col] = p.newState
                }
            }

            pushUndoGroup(undoGroup)

            // conflict feedback
            if board[row][col] == .queen {
                let conflicts = await engine.conflictTypesForQueen(at: row, col: col)
                if !conflicts.isEmpty { Haptics.warning() }
            }

            await computeInvalidPositions()

            if await engine.checkIfSolved() {
                stopTimer()
                Haptics.success()
                showCompletion = true
            }
        }
    }

    // MARK: - Drag grouping (cross placement)
    func beginCrossDrag() { currentDragUndoGroup = [] }
    func endCrossDrag() {
        if let group = currentDragUndoGroup, !group.isEmpty { pushUndoGroup(group) }
        currentDragUndoGroup = nil
    }

    func setCross(row: Int, col: Int, state: CellStateV2) {
        guard let engine else { return }
        Task {
            // don't touch queens
            if board[row][col] == .queen { return }
            let previous = board[row][col]
            if previous == state { return }

            if let ch = await engine.setCell(state, row: row, col: col) {
                board[ch.row][ch.col] = ch.newState
            } else {
                // setCell rejected (shouldn't happen for non-queen states), but fallback
                board[row][col] = state
            }

            let reverse = CellChangeV2(row: row, col: col, newState: previous)
            if var g = currentDragUndoGroup { g.append(reverse); currentDragUndoGroup = g }
            else { pushUndoGroup([reverse]) }

            await computeInvalidPositions()
        }
    }

    // MARK: - Undo
    func undo() {
        guard let engine else { return }
        Task {
            guard let group = undoStack.popLast() else { return }
            for rev in group {
                if let ch = await engine.setCell(rev.newState, row: rev.row, col: rev.col) {
                    board[ch.row][ch.col] = ch.newState
                } else {
                    // if engine rejected, still apply locally
                    board[rev.row][rev.col] = rev.newState
                }
            }
            canUndo = !undoStack.isEmpty
            showCompletion = false
            await computeInvalidPositions()
            Haptics.light()
        }
    }

    private func pushUndoGroup(_ reverse: [CellChangeV2]) {
        undoStack.append(reverse)
        canUndo = true
    }

    // MARK: - Hint
    func revealHint() {
        guard let engine, hintsUsed < maxHints else { return }
        Task {
            let canonical = await engine.getCanonicalSolution()
            guard let (tr, tc) = canonical.first(where: { board[$0.0][$0.1] != .queen }) else { return }
            var reverseGroup: [CellChangeV2] = []

            // Clear conflicting queens in row
            for c in 0..<board.count where c != tc && board[tr][c] == .queen {
                reverseGroup.append(CellChangeV2(row: tr, col: c, newState: .queen))
                if let ch = await engine.setCell(.empty, row: tr, col: c) { board[ch.row][ch.col] = ch.newState } else { board[tr][c] = .empty }
            }
            // Clear conflicting queens in column
            for r in 0..<board.count where r != tr && board[r][tc] == .queen {
                reverseGroup.append(CellChangeV2(row: r, col: tc, newState: .queen))
                if let ch = await engine.setCell(.empty, row: r, col: tc) { board[ch.row][ch.col] = ch.newState } else { board[r][tc] = .empty }
            }
            // Clear conflicting queens in region
            let targetRID = regionMap[tr][tc]
            for r in 0..<board.count {
                for c in 0..<board.count where regionMap[r][c] == targetRID && !(r == tr && c == tc) && board[r][c] == .queen {
                    reverseGroup.append(CellChangeV2(row: r, col: c, newState: .queen))
                    if let ch = await engine.setCell(.empty, row: r, col: c) { board[ch.row][ch.col] = ch.newState } else { board[r][c] = .empty }
                }
            }

            // Place hint queen
            let prevAtTarget = board[tr][tc]
            if prevAtTarget != .queen {
                reverseGroup.append(CellChangeV2(row: tr, col: tc, newState: prevAtTarget))
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

    // MARK: - Invalid positions
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
        invalidPositions = invalid
    }

    func isPositionInvalid(_ r: Int, _ c: Int) -> Bool {
        invalidPositions.contains(BoardPos(r: r, c: c))
    }

    // MARK: - Reset
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

    // MARK: - Region colors
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

    var size: Int { board.count }
}
