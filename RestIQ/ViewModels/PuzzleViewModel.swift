//
//  PuzzleViewModel.swift
//  RestIQ
//

import Foundation
import SwiftUI
import Combine

// MARK: - GridCoord
// Lightweight coordinate used by HintMode to carry cell sets across the hint system.

struct GridCoord: Hashable, Equatable, Sendable {
    let row: Int
    let col: Int
}

// MARK: - HintMode

enum HintMode: Equatable {
    /// One specific cell is logically forced — place a crown there.
    case forcedPlacement(row: Int, col: Int)

    /// A region is row- or column-locked — eliminate the blocking cells in that line.
    case elimination(regionCells: [GridCoord], eliminateCells: [GridCoord])

    /// The player has marked a canonical solution cell as ✕ — highlight the mistake.
    case wrongMark(row: Int, col: Int)

    /// No logically justifiable hint exists at the current board state.
    /// Shown without consuming a hint use or starting a cooldown.
    case noHint
}

// MARK: - HintState

struct HintState: Equatable {
    let mode: HintMode
    let message: String

    var isError: Bool {
        if case .wrongMark = mode { return true }
        return false
    }

    /// SF Symbol name for the hint banner icon.
    var bannerIcon: String {
        switch mode {
        case .wrongMark:        return "exclamationmark.triangle.fill"
        case .forcedPlacement:  return "crown.fill"
        case .elimination:      return "xmark.circle.fill"
        case .noHint:           return "lightbulb.slash.fill"
        }
    }
}

// MARK: - PuzzleViewModel

@MainActor
final class PuzzleViewModel: ObservableObject {
    @Published var board: [[CellState]] = []
    @Published var regionMap: [[Int]] = []
    @Published var regionColors: [Int: Color] = [:]
    @Published var regionColorNames: [Int: String] = [:]
    @Published var showCompletion = false
    @Published var isLoading = true
    @Published var generationFailed = false
    @Published var elapsedSeconds = 0
    @Published var activeHint: HintState? = nil

    // Settings — persisted to UserDefaults so they survive navigation and relaunch
    @Published var showClock: Bool = UserDefaults.standard.object(forKey: "setting.showClock") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showClock, forKey: "setting.showClock") }
    }
    @Published var autoPlaceCrosses: Bool = UserDefaults.standard.bool(forKey: "setting.autoPlaceCrosses") {
        didSet { UserDefaults.standard.set(autoPlaceCrosses, forKey: "setting.autoPlaceCrosses") }
    }

    @Published private(set) var canUndo = false
    @Published private(set) var hintsUsed = 0
    // Seconds remaining before the next hint is available.
    // Zero means ready. Counts down once per second after each hint is used.
    @Published private(set) var hintCooldownRemaining: Int = 0

    // Cooldown in seconds per difficulty — 0 in debug mode (set in init).
    private let hintCooldownSeconds: Int

    private var cooldownTask: Task<Void, Never>?

    private var undoStack: [[CellChange]] = []
    private var timerTask: Task<Void, Never>?
    private(set) var engine: QueensPuzzleEngine?
    private let gridSize: Int
    private let difficulty: Difficulty
    let level: String

    private var currentDragUndoGroup: [CellChange]? = nil

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
        // Cooldown scales with difficulty. Debug mode disables it entirely.
        if DebugConfig.shared.debugMode {
            hintCooldownSeconds = 0
        } else {
            switch level {
            case "Easy":   hintCooldownSeconds = 5
            case "Medium": hintCooldownSeconds = 7
            case "Hard":   hintCooldownSeconds = 10
            case "Expert": hintCooldownSeconds = 12
            default:       hintCooldownSeconds = 5
            }
        }
        Task { await generateDailyPuzzle() }
    }

    // MARK: - Daily Puzzle Generation

    func generateDailyPuzzle() async {
        isLoading = true
        generationFailed = false
        activeHint = nil
        stopTimer()

        if let cached = await DailyChallengeManager.shared.generateDailyPuzzle(for: level) {
            engine = cached
        }
        guard let engine else {
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
        hintCooldownRemaining = 0
        cooldownTask?.cancel()
        invalidPositions = []

        if let record = UserStatsManager.shared.completion(for: level) {
            elapsedSeconds = record.elapsedSeconds
            showCompletion = true
        } else {
            elapsedSeconds = 0
            startTimer()
        }
    }

    // MARK: - Cell Interaction

    func tapCell(row: Int, col: Int) {
        guard let engine else { return }
        activeHint = nil
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
                if autoPlaceCrosses {
                    let cleared = await clearCrossesForRemovedQueen(row: row, col: col, engine: engine)
                    undoGroup.append(contentsOf: cleared)
                }
            }

            pushUndoGroup(undoGroup)
            await computeInvalidPositions()
            if await engine.checkIfSolved() { handleSolved() }
        }
    }

    // MARK: - Auto-Cross Helpers

    private func placeCrossesAroundQueen(row: Int, col: Int, engine: QueensPuzzleEngine) async -> [CellChange] {
        var reverseChanges: [CellChange] = []
        let regionID = regionMap[row][col]
        for r in 0..<gridSize {
            for c in 0..<gridSize {
                guard board[r][c] == .empty, !(r == row && c == col) else { continue }
                let eliminated = r == row || c == col
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

    private func clearCrossesForRemovedQueen(row: Int, col: Int, engine: QueensPuzzleEngine) async -> [CellChange] {
        var reverseChanges: [CellChange] = []
        let regionID = regionMap[row][col]
        for r in 0..<gridSize {
            for c in 0..<gridSize {
                guard board[r][c] == .markedX else { continue }
                let affected = r == row || c == col
                    || regionMap[r][c] == regionID
                    || (abs(r - row) <= 1 && abs(c - col) <= 1)
                guard affected else { continue }
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

    private func isEliminatedByAnyQueen(r: Int, c: Int) -> Bool {
        let regionID = regionMap[r][c]
        for qr in 0..<gridSize {
            for qc in 0..<gridSize {
                guard board[qr][qc] == .queen else { continue }
                if qr == r || qc == c
                    || regionMap[qr][qc] == regionID
                    || (abs(qr - r) <= 1 && abs(qc - c) <= 1) { return true }
            }
        }
        return false
    }

    // MARK: - Drag

    func beginCrossDrag() { currentDragUndoGroup = [] }

    func endCrossDrag() {
        if let group = currentDragUndoGroup, !group.isEmpty { pushUndoGroup(group) }
        currentDragUndoGroup = nil
    }

    func setCross(row: Int, col: Int, state: CellState) {
        guard let engine else { return }
        activeHint = nil
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
        activeHint = nil
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

    // MARK: - Show Me (applies the current hint move)

    func applyShowMe() {
        guard let hint = activeHint, let engine else { return }
        activeHint = nil
        Task {
            switch hint.mode {

            case .forcedPlacement(let r, let c):
                // Place queen directly and record undo group (including auto-crosses)
                let prev = board[r][c]
                if let ch = await engine.setCell(.queen, row: r, col: c) {
                    board[ch.row][ch.col] = ch.newState
                }
                var undoGroup = [CellChange(row: r, col: c, newState: prev)]
                if autoPlaceCrosses {
                    let crosses = await placeCrossesAroundQueen(row: r, col: c, engine: engine)
                    undoGroup.append(contentsOf: crosses)
                }
                pushUndoGroup(undoGroup)
                await computeInvalidPositions()
                if await engine.checkIfSolved() { handleSolved() }
                Haptics.success()

            case .elimination(_, let eliminateCells):
                // Mark all elimination targets as ✕ in one undo group
                var undoGroup: [CellChange] = []
                for coord in eliminateCells where board[coord.row][coord.col] == .empty {
                    let prev = board[coord.row][coord.col]
                    if let ch = await engine.setCell(.markedX, row: coord.row, col: coord.col) {
                        board[ch.row][ch.col] = ch.newState
                    }
                    undoGroup.append(CellChange(row: coord.row, col: coord.col, newState: prev))
                }
                if !undoGroup.isEmpty { pushUndoGroup(undoGroup) }
                await computeInvalidPositions()
                Haptics.medium()

            case .noHint:
                // Nothing to apply — just clear the hint (already cleared above)
                break

            case .wrongMark(let r, let c):
                // Clear the incorrectly placed ✕
                let prev = board[r][c]
                if let ch = await engine.setCell(.empty, row: r, col: c) {
                    board[ch.row][ch.col] = ch.newState
                }
                pushUndoGroup([CellChange(row: r, col: c, newState: prev)])
                await computeInvalidPositions()
                Haptics.soft()
            }
        }
    }

    // Starts the per-second countdown after a hint is successfully used.
    // No-op in debug mode (cooldownSeconds == 0).
    private func startHintCooldown() {
        guard hintCooldownSeconds > 0 else { return }
        hintCooldownRemaining = hintCooldownSeconds
        cooldownTask?.cancel()
        cooldownTask = Task {
            while hintCooldownRemaining > 0 && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if !Task.isCancelled { hintCooldownRemaining -= 1 }
            }
        }
    }

    // MARK: - Smart Hint

    func revealHint() {
        guard let engine, hintCooldownRemaining == 0, activeHint == nil else { return }
        Task {
            let canonical = await engine.getCanonicalSolution()

            // Snapshot MainActor state — nested funcs below are nonisolated and
            // cannot access self's properties directly (Swift 6 actor rule).
            let board            = self.board
            let regionMap        = self.regionMap
            let regionColorNames = self.regionColorNames
            let gridSize         = self.gridSize

            // ── Scenario B (priority): player marked a correct queen cell as ✕ ──
            for (tr, tc) in canonical where board[tr][tc] == .markedX {
                let colorName = regionColorNames[regionMap[tr][tc]] ?? "this"
                self.hintsUsed += 1
                self.startHintCooldown()
                Haptics.warning()
                self.activeHint = HintState(
                    mode: .wrongMark(row: tr, col: tc),
                    message: "You've marked a valid crown cell as ✕ — check row \(tr + 1) in the \(colorName) region."
                )
                return
            }

            // Shared helpers — operate only on local value snapshots (actor-safe)

            func isValidCandidate(_ r: Int, _ c: Int) -> Bool {
                // .empty only — .markedX cells are excluded so they don't inflate
                // the candidate count and mask forced-placement hints.
                guard board[r][c] == .empty else { return false }
                for qr in 0..<gridSize {
                    for qc in 0..<gridSize {
                        guard board[qr][qc] == .queen else { continue }
                        if qr == r || qc == c
                            || regionMap[qr][qc] == regionMap[r][c]
                            || (abs(qr - r) <= 1 && abs(qc - c) <= 1) { return false }
                    }
                }
                return true
            }

            // Builds the specific reason message for a region-forced placement.
            // Names the exact queens/rows/cols blocking every other cell in the region.
            func regionBlockersMessage(rid: Int, targetRow: Int, targetCol: Int, colorName: String) -> String {
                var blockingRows  = Set<Int>()
                var blockingCols  = Set<Int>()
                var adjacencyOnly = 0
                var otherCount    = 0

                for r in 0..<gridSize {
                    for c in 0..<gridSize where regionMap[r][c] == rid && !(r == targetRow && c == targetCol) {
                        otherCount += 1
                        var rowColBlocked = false
                        for qr in 0..<gridSize {
                            for qc in 0..<gridSize where board[qr][qc] == .queen {
                                if qr == r { blockingRows.insert(qr + 1); rowColBlocked = true }
                                if qc == c { blockingCols.insert(qc + 1); rowColBlocked = true }
                            }
                        }
                        if !rowColBlocked { adjacencyOnly += 1 }
                    }
                }

                let otherWord  = otherCount == 1 ? "the other \(colorName) cell" : "all \(otherCount) other \(colorName) cells"
                let sortedRows = blockingRows.sorted()
                let sortedCols = blockingCols.sorted()

                var parts: [String] = []
                if !sortedRows.isEmpty { parts.append(sortedRows.map { "row \($0)" }.joined(separator: ", ")) }
                if !sortedCols.isEmpty { parts.append(sortedCols.map { "column \($0)" }.joined(separator: ", ")) }

                if parts.isEmpty {
                    return "Nearby crowns block \(otherWord) — this is the only \(colorName) cell left."
                }
                let blocker  = parts.joined(separator: " and ")
                let queenWord = (sortedRows.count + sortedCols.count) == 1 ? "A crown in" : "Crowns in"
                if adjacencyOnly > 0 {
                    return "\(queenWord) \(blocker), plus diagonal adjacency, block \(otherWord) — this is the only \(colorName) cell left."
                }
                return "\(queenWord) \(blocker) block \(otherWord) — this is the only \(colorName) cell left."
            }

            // Pre-compute which rows / cols / regions already have a queen
            let rowHasQueen    = (0..<gridSize).map { r in board[r].contains(.queen) }
            let colHasQueen    = (0..<gridSize).map { c in (0..<gridSize).contains { board[$0][c] == .queen } }
            let regionHasQueen = Dictionary(
                (0..<gridSize).flatMap { r in
                    (0..<gridSize).compactMap { c -> (Int, Bool)? in
                        board[r][c] == .queen ? (regionMap[r][c], true) : nil
                    }
                },
                uniquingKeysWith: { a, _ in a }
            )
            let allRegionIDs = Set(regionMap.flatMap { $0 }).sorted()

            // ── Mode 1: Forced placement ──────────────────────────────────────────

            // 1a. Region with exactly one valid cell
            for rid in allRegionIDs {
                guard regionHasQueen[rid] == nil else { continue }
                var candidates: [(Int, Int)] = []
                for r in 0..<gridSize {
                    for c in 0..<gridSize where regionMap[r][c] == rid {
                        if isValidCandidate(r, c) { candidates.append((r, c)) }
                    }
                }
                if candidates.count == 1 {
                    let (tr, tc) = candidates[0]
                    let colorName = regionColorNames[rid] ?? "this"
                    let message   = regionBlockersMessage(rid: rid, targetRow: tr, targetCol: tc, colorName: colorName)
                    self.hintsUsed += 1
                    self.startHintCooldown()
                    Haptics.soft()
                    self.activeHint = HintState(mode: .forcedPlacement(row: tr, col: tc), message: message)
                    return
                }
            }

            // 1b. Row with exactly one valid cell
            for r in 0..<gridSize where !rowHasQueen[r] {
                let candidates = (0..<gridSize).filter { isValidCandidate(r, $0) }
                if candidates.count == 1 {
                    let tc = candidates[0]
                    self.hintsUsed += 1
                    self.startHintCooldown()
                    Haptics.soft()
                    self.activeHint = HintState(
                        mode: .forcedPlacement(row: r, col: tc),
                        message: "Row \(r + 1) has only one valid cell left."
                    )
                    return
                }
            }

            // 1c. Column with exactly one valid cell
            for c in 0..<gridSize where !colHasQueen[c] {
                let candidates = (0..<gridSize).filter { isValidCandidate($0, c) }
                if candidates.count == 1 {
                    let tr = candidates[0]
                    self.hintsUsed += 1
                    self.startHintCooldown()
                    Haptics.soft()
                    self.activeHint = HintState(
                        mode: .forcedPlacement(row: tr, col: c),
                        message: "Column \(c + 1) has only one valid cell left."
                    )
                    return
                }
            }

            // ── Mode 2: Elimination nudge ─────────────────────────────────────────
            //
            // Find a region whose valid cells are all locked to a single row or column.
            // Two sets of cells can then be safely eliminated:
            //   • Other cells in the locked line (same row/col, different region)
            //   • Cells diagonally adjacent to ALL valid cells of the locked region
            //     (placing a crown there would block every remaining option)

            // Returns true if coord is adjacent (including diagonally) to every cell in the set.
            func adjacentToAll(_ coord: GridCoord, _ cells: [(Int, Int)]) -> Bool {
                cells.allSatisfy { (r, c) in
                    abs(coord.row - r) <= 1 && abs(coord.col - c) <= 1
                }
            }

            for rid in allRegionIDs {
                guard regionHasQueen[rid] == nil else { continue }
                var validCells: [(Int, Int)] = []
                for r in 0..<gridSize {
                    for c in 0..<gridSize where regionMap[r][c] == rid {
                        if isValidCandidate(r, c) { validCells.append((r, c)) }
                    }
                }
                guard validCells.count >= 2 else { continue }

                let colorName       = regionColorNames[rid] ?? "this"
                let regionHighlight = validCells.map { GridCoord(row: $0.0, col: $0.1) }

                // Helper: builds the full elimination set for a locked line.
                // Includes cells in the locked line from other regions, PLUS cells
                // outside the line that are diagonally adjacent to ALL valid cells.
                func buildElimCells(lineCoords: [GridCoord]) -> [GridCoord] {
                    var result = Set<GridCoord>()

                    // 1. Other cells already in the locked line
                    for coord in lineCoords where regionMap[coord.row][coord.col] != rid && board[coord.row][coord.col] == .empty {
                        result.insert(coord)
                    }

                    // 2. Cells outside the line adjacent to ALL valid cells of the locked region
                    for r in 0..<gridSize {
                        for c in 0..<gridSize {
                            let coord = GridCoord(row: r, col: c)
                            guard !lineCoords.contains(coord),     // not already in line set
                                  regionMap[r][c] != rid,          // different region
                                  board[r][c] == .empty,           // not already placed/marked
                                  adjacentToAll(coord, validCells) // blocks every option
                            else { continue }
                            result.insert(coord)
                        }
                    }

                    return Array(result)
                }

                // Row-locked: all valid cells share the same row
                let lockedRows = Set(validCells.map { $0.0 })
                if lockedRows.count == 1, let lockedRow = lockedRows.first {
                    let lineCoords = (0..<gridSize).map { GridCoord(row: lockedRow, col: $0) }
                    let elimCells  = buildElimCells(lineCoords: lineCoords)
                    if !elimCells.isEmpty {
                        self.hintsUsed += 1
                        self.startHintCooldown()
                        Haptics.soft()
                        self.activeHint = HintState(
                            mode: .elimination(regionCells: regionHighlight, eliminateCells: elimCells),
                            message: "The \(colorName) region must place its crown in row \(lockedRow + 1). Any cell in that row — or touching all \(colorName) cells — can't be a crown. Mark them ✕."
                        )
                        return
                    }
                }

                // Column-locked: all valid cells share the same column
                let lockedCols = Set(validCells.map { $0.1 })
                if lockedCols.count == 1, let lockedCol = lockedCols.first {
                    let lineCoords = (0..<gridSize).map { GridCoord(row: $0, col: lockedCol) }
                    let elimCells  = buildElimCells(lineCoords: lineCoords)
                    if !elimCells.isEmpty {
                        self.hintsUsed += 1
                        self.startHintCooldown()
                        Haptics.soft()
                        self.activeHint = HintState(
                            mode: .elimination(regionCells: regionHighlight, eliminateCells: elimCells),
                            message: "The \(colorName) region must place its crown in column \(lockedCol + 1). Any cell in that column — or touching all \(colorName) cells — can't be a crown. Mark them ✕."
                        )
                        return
                    }
                }
            }

            // ── Mode 2b: Exclusive row/column ownership ───────────────────────────
            //
            // If an entire row (or column) belongs to a single region, that region
            // is forced to place its crown in that row/column. Any cells of that
            // region that lie OUTSIDE the locked line can therefore be marked ✕.
            //
            // Example: row 1 is all yellow → yellow crown must be in row 1
            //          → yellow cells in rows 2, 3, 4... can be marked ✕

            // Row ownership: check if every cell in a row shares the same region ID
            for r in 0..<gridSize where !rowHasQueen[r] {
                let regionIDs = (0..<gridSize).map { regionMap[r][$0] }
                guard let ownerRid = regionIDs.first, Set(regionIDs).count == 1 else { continue }
                guard regionHasQueen[ownerRid] == nil else { continue }

                // Find cells of the owner region outside this row that are still empty
                let elimCells = (0..<gridSize).flatMap { er -> [GridCoord] in
                    guard er != r else { return [] }
                    return (0..<gridSize).compactMap { ec -> GridCoord? in
                        guard regionMap[er][ec] == ownerRid,
                              board[er][ec] == .empty
                        else { return nil }
                        return GridCoord(row: er, col: ec)
                    }
                }
                guard !elimCells.isEmpty else { continue }

                let colorName   = regionColorNames[ownerRid] ?? "this"
                let regionCells = (0..<gridSize).map { GridCoord(row: r, col: $0) }

                self.hintsUsed += 1
                self.startHintCooldown()
                Haptics.soft()
                self.activeHint = HintState(
                    mode: .elimination(regionCells: regionCells, eliminateCells: elimCells),
                    message: "Row \(r + 1) is entirely \(colorName), so the \(colorName) crown must be in that row. \(colorName.capitalized) cells elsewhere can't be crowns — mark them ✕."
                )
                return
            }

            // Column ownership: same logic applied to columns
            for c in 0..<gridSize where !colHasQueen[c] {
                let regionIDs = (0..<gridSize).map { regionMap[$0][c] }
                guard let ownerRid = regionIDs.first, Set(regionIDs).count == 1 else { continue }
                guard regionHasQueen[ownerRid] == nil else { continue }

                let elimCells = (0..<gridSize).flatMap { ec -> [GridCoord] in
                    guard ec != c else { return [] }
                    return (0..<gridSize).compactMap { er -> GridCoord? in
                        guard regionMap[er][ec] == ownerRid,
                              board[er][ec] == .empty
                        else { return nil }
                        return GridCoord(row: er, col: ec)
                    }
                }
                guard !elimCells.isEmpty else { continue }

                let colorName   = regionColorNames[ownerRid] ?? "this"
                let regionCells = (0..<gridSize).map { GridCoord(row: $0, col: c) }

                self.hintsUsed += 1
                self.startHintCooldown()
                Haptics.soft()
                self.activeHint = HintState(
                    mode: .elimination(regionCells: regionCells, eliminateCells: elimCells),
                    message: "Column \(c + 1) is entirely \(colorName), so the \(colorName) crown must be in that column. \(colorName.capitalized) cells elsewhere can't be crowns — mark them ✕."
                )
                return
            }

            // ── Mode 2c: N-region N-column/row claiming ───────────────────────────
            //
            // If N unqueened regions have ALL their valid cells confined within the
            // same N columns (or rows), those columns are fully claimed by those
            // regions. Any other region's cells in those columns can be marked ✕.
            //
            // Example (screenshot): yellow + red (2 regions) both have valid cells
            // only in columns 6+7 (2 columns) → those columns are claimed → every
            // other region's cell in columns 6+7 can be eliminated.
            //
            // This covers pairs (N=2), triples (N=3), etc.

            // Build a map: rid → set of columns containing its valid cells
            var regionValidCols: [Int: Set<Int>] = [:]
            var regionValidRows: [Int: Set<Int>] = [:]
            for rid in allRegionIDs {
                guard regionHasQueen[rid] == nil else { continue }
                var cols = Set<Int>()
                var rows = Set<Int>()
                for r in 0..<gridSize {
                    for c in 0..<gridSize where regionMap[r][c] == rid {
                        if isValidCandidate(r, c) { cols.insert(c); rows.insert(r) }
                    }
                }
                if !cols.isEmpty { regionValidCols[rid] = cols }
                if !rows.isEmpty { regionValidRows[rid] = rows }
            }

            let unqueenedRids = Array(regionValidCols.keys)

            // Column claiming: find groups of N regions whose combined valid columns
            // form a set of exactly N columns.
            // Try group sizes 2 and 3 (larger groups are rarely useful in practice).
            for groupSize in 2...min(3, unqueenedRids.count) {
                // Generate combinations of `groupSize` regions
                func combinations(_ arr: [Int], _ size: Int) -> [[Int]] {
                    guard size > 0 else { return [[]] }
                    guard arr.count >= size else { return [] }
                    var result: [[Int]] = []
                    for (i, el) in arr.enumerated() {
                        let rest = combinations(Array(arr.dropFirst(i + 1)), size - 1)
                        result.append(contentsOf: rest.map { [el] + $0 })
                    }
                    return result
                }

                for group in combinations(unqueenedRids, groupSize) {
                    // Union of all valid columns for this group
                    let claimedCols = group.reduce(Set<Int>()) { $0.union(regionValidCols[$1] ?? []) }
                    guard claimedCols.count == groupSize else { continue }

                    // Found a claiming group — find other regions' cells in those columns
                    let groupSet = Set(group)
                    var elimCells: [GridCoord] = []
                    for r in 0..<gridSize {
                        for c in claimedCols {
                            guard !groupSet.contains(regionMap[r][c]),  // not a claiming region
                                  board[r][c] == .empty                  // not already marked
                            else { continue }
                            elimCells.append(GridCoord(row: r, col: c))
                        }
                    }
                    guard !elimCells.isEmpty else { continue }

                    // Highlight the claiming regions' cells as context
                    let contextCells = group.flatMap { rid -> [GridCoord] in
                        (0..<gridSize).flatMap { r in
                            (0..<gridSize).compactMap { c -> GridCoord? in
                                guard regionMap[r][c] == rid, isValidCandidate(r, c) else { return nil }
                                return GridCoord(row: r, col: c)
                            }
                        }
                    }

                    let colList = claimedCols.sorted().map { "column \($0 + 1)" }.joined(separator: " and ")
                    let regionNames = group.compactMap { regionColorNames[$0] }.joined(separator: " and ")

                    self.hintsUsed += 1
                    self.startHintCooldown()
                    Haptics.soft()
                    self.activeHint = HintState(
                        mode: .elimination(regionCells: contextCells, eliminateCells: elimCells),
                        message: "The \(regionNames) regions can only place their crowns in \(colList). Other cells in those columns can't be crowns — mark them ✕."
                    )
                    return
                }

                // Row claiming: same logic applied to rows
                for group in combinations(unqueenedRids, groupSize) {
                    let claimedRows = group.reduce(Set<Int>()) { $0.union(regionValidRows[$1] ?? []) }
                    guard claimedRows.count == groupSize else { continue }

                    let groupSet = Set(group)
                    var elimCells: [GridCoord] = []
                    for c in 0..<gridSize {
                        for r in claimedRows {
                            guard !groupSet.contains(regionMap[r][c]),
                                  board[r][c] == .empty
                            else { continue }
                            elimCells.append(GridCoord(row: r, col: c))
                        }
                    }
                    guard !elimCells.isEmpty else { continue }

                    let contextCells = group.flatMap { rid -> [GridCoord] in
                        (0..<gridSize).flatMap { r in
                            (0..<gridSize).compactMap { c -> GridCoord? in
                                guard regionMap[r][c] == rid, isValidCandidate(r, c) else { return nil }
                                return GridCoord(row: r, col: c)
                            }
                        }
                    }

                    let rowList = claimedRows.sorted().map { "row \($0 + 1)" }.joined(separator: " and ")
                    let regionNames = group.compactMap { regionColorNames[$0] }.joined(separator: " and ")

                    self.hintsUsed += 1
                    self.startHintCooldown()
                    Haptics.soft()
                    self.activeHint = HintState(
                        mode: .elimination(regionCells: contextCells, eliminateCells: elimCells),
                        message: "The \(regionNames) regions can only place their crowns in \(rowList). Other cells in those rows can't be crowns — mark them ✕."
                    )
                    return
                }
            }

            // ── Mode 3: Region starvation ─────────────────────────────────────────
            //
            // For each empty cell that's a valid candidate, simulate placing a queen
            // there and count valid candidates for every other region.
            // If any region drops to zero, that cell cannot be a crown.
            // This catches the case: "placing here would strand the purple region."

            // Simulates placing a queen at (qr, qc) and returns valid candidate
            // counts for all regions, rows, and columns, using only local snapshots.
            struct StarvationResult {
                var regionCounts: [Int: Int]   // rid → remaining valid candidates
                var rowCounts: [Int: Int]       // row → remaining valid candidates
                var colCounts: [Int: Int]       // col → remaining valid candidates
            }

            func starvationAfterPlacing(qr: Int, qc: Int) -> StarvationResult {
                let qRegion = regionMap[qr][qc]
                var regionCounts: [Int: Int] = [:]
                var rowCounts: [Int: Int] = [:]
                var colCounts: [Int: Int] = [:]

                // Helper: returns true if (r,c) would be blocked after placing at (qr,qc)
                func wouldBeBlocked(_ r: Int, _ c: Int) -> Bool {
                    // Blocked by existing queens
                    for eq in 0..<gridSize {
                        for ec in 0..<gridSize where board[eq][ec] == .queen {
                            if eq == r || ec == c
                                || regionMap[eq][ec] == regionMap[r][c]
                                || (abs(eq - r) <= 1 && abs(ec - c) <= 1) { return true }
                        }
                    }
                    // Blocked by simulated queen
                    return qr == r || qc == c
                        || regionMap[qr][qc] == regionMap[r][c]
                        || (abs(qr - r) <= 1 && abs(qc - c) <= 1)
                }

                // Count remaining valid candidates per region
                for rid in allRegionIDs {
                    guard regionHasQueen[rid] == nil, rid != qRegion else { continue }
                    let count = (0..<gridSize).flatMap { r in
                        (0..<gridSize).filter { c in
                            regionMap[r][c] == rid && board[r][c] == .empty && !wouldBeBlocked(r, c)
                        }
                    }.count
                    regionCounts[rid] = count
                }

                // Count remaining valid candidates per row
                for r in 0..<gridSize where !rowHasQueen[r] && r != qr {
                    let count = (0..<gridSize).filter { c in
                        board[r][c] == .empty && !wouldBeBlocked(r, c)
                    }.count
                    rowCounts[r] = count
                }

                // Count remaining valid candidates per column
                for c in 0..<gridSize where !colHasQueen[c] && c != qc {
                    let count = (0..<gridSize).filter { r in
                        board[r][c] == .empty && !wouldBeBlocked(r, c)
                    }.count
                    colCounts[c] = count
                }

                return StarvationResult(regionCounts: regionCounts, rowCounts: rowCounts, colCounts: colCounts)
            }

            for r in 0..<gridSize {
                for c in 0..<gridSize where isValidCandidate(r, c) {
                    let result = starvationAfterPlacing(qr: r, qc: c)
                    let _ = regionColorNames[regionMap[r][c]] ?? "this"

                    // Region starved — collect ALL candidates that strand the same region
                    if let strandedRid = result.regionCounts.first(where: { $0.value == 0 })?.key {
                        let strandedColorName = regionColorNames[strandedRid] ?? "another"
                        let strandedCells = (0..<gridSize).flatMap { sr in
                            (0..<gridSize).compactMap { sc -> GridCoord? in
                                guard regionMap[sr][sc] == strandedRid,
                                      isValidCandidate(sr, sc)
                                else { return nil }
                                return GridCoord(row: sr, col: sc)
                            }
                        }
                        // Only useful when the stranded region is nearly exhausted (≤ 2 candidates)
                        // — more than that and the deduction is too complex to explain clearly.
                        guard strandedCells.count <= 3 else { continue }

                        let elimCells = (0..<gridSize).flatMap { er in
                            (0..<gridSize).compactMap { ec -> GridCoord? in
                                guard isValidCandidate(er, ec) else { return nil }
                                let sim = starvationAfterPlacing(qr: er, qc: ec)
                                return sim.regionCounts[strandedRid] == 0 ? GridCoord(row: er, col: ec) : nil
                            }
                        }
                        // Guard: elimCells must not overlap strandedCells
                        let strandedSet = Set(strandedCells)
                        let cleanElim = elimCells.filter { !strandedSet.contains($0) }
                        guard !cleanElim.isEmpty else { continue }

                        self.hintsUsed += 1
                        self.startHintCooldown()
                        Haptics.soft()
                        self.activeHint = HintState(
                            mode: .elimination(regionCells: strandedCells, eliminateCells: cleanElim),
                            message: "Any crown in the highlighted cells would leave the \(strandedColorName) region with nowhere to go. Mark them ✕."
                        )
                        return
                    }

                    // Row starved — collect ALL candidates that strand the same row
                    if let strandedRow = result.rowCounts.first(where: { $0.value == 0 })?.key {
                        let strandedCells = (0..<gridSize).compactMap { sc -> GridCoord? in
                            guard board[strandedRow][sc] == .empty,
                                  isValidCandidate(strandedRow, sc)
                            else { return nil }
                            return GridCoord(row: strandedRow, col: sc)
                        }
                        guard strandedCells.count <= 3 else { continue }

                        let elimCells = (0..<gridSize).flatMap { er in
                            (0..<gridSize).compactMap { ec -> GridCoord? in
                                guard isValidCandidate(er, ec) else { return nil }
                                let sim = starvationAfterPlacing(qr: er, qc: ec)
                                return sim.rowCounts[strandedRow] == 0 ? GridCoord(row: er, col: ec) : nil
                            }
                        }
                        let strandedSet = Set(strandedCells)
                        let cleanElim = elimCells.filter { !strandedSet.contains($0) }
                        guard !cleanElim.isEmpty else { continue }

                        self.hintsUsed += 1
                        self.startHintCooldown()
                        Haptics.soft()
                        self.activeHint = HintState(
                            mode: .elimination(regionCells: strandedCells, eliminateCells: cleanElim),
                            message: "Any crown in the highlighted cells would leave row \(strandedRow + 1) with no valid cells. Mark them ✕."
                        )
                        return
                    }

                    // Column starved — collect ALL candidates that strand the same column
                    if let strandedCol = result.colCounts.first(where: { $0.value == 0 })?.key {
                        let strandedCells = (0..<gridSize).compactMap { sr -> GridCoord? in
                            guard board[sr][strandedCol] == .empty,
                                  isValidCandidate(sr, strandedCol)
                            else { return nil }
                            return GridCoord(row: sr, col: strandedCol)
                        }
                        guard strandedCells.count <= 3 else { continue }

                        let elimCells = (0..<gridSize).flatMap { er in
                            (0..<gridSize).compactMap { ec -> GridCoord? in
                                guard isValidCandidate(er, ec) else { return nil }
                                let sim = starvationAfterPlacing(qr: er, qc: ec)
                                return sim.colCounts[strandedCol] == 0 ? GridCoord(row: er, col: ec) : nil
                            }
                        }
                        let strandedSet = Set(strandedCells)
                        let cleanElim = elimCells.filter { !strandedSet.contains($0) }
                        guard !cleanElim.isEmpty else { continue }

                        self.hintsUsed += 1
                        self.startHintCooldown()
                        Haptics.soft()
                        self.activeHint = HintState(
                            mode: .elimination(regionCells: strandedCells, eliminateCells: cleanElim),
                            message: "Any crown in the highlighted cells would leave column \(strandedCol + 1) with no valid cells. Mark them ✕."
                        )
                        return
                    }
                }
            }

            // ── No hint available ─────────────────────────────────────────────────
            // No forced placement or elimination can be logically justified yet.
            // Show a message without consuming a hint use or starting a cooldown.
            self.activeHint = HintState(
                mode: .noHint,
                message: "No clear hint available yet — try placing more crowns to unlock one."
            )
        }
    }

    // MARK: - Solve Handler

    private func handleSolved() {
        stopTimer()
        Haptics.success()
        showCompletion = true
        activeHint = nil
        UserStatsManager.shared.recordCompletion(
            level: level,
            elapsedSeconds: elapsedSeconds,
            hintsUsed: hintsUsed
        )
    }

    // MARK: - Invalid Positions

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
        activeHint = nil
        Task {
            let changes = await engine.resetBoard()
            for ch in changes { board[ch.row][ch.col] = ch.newState }
            elapsedSeconds = 0
            invalidPositions = []
            undoStack.removeAll()
            canUndo = false
            hintsUsed = 0
            hintCooldownRemaining = 0
            cooldownTask?.cancel()
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

    func stopTimer() { timerTask?.cancel(); timerTask = nil }

    func formattedElapsed() -> String {
        String(format: "%d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)
    }

    // MARK: - Region Colors

    private func buildRegionColors() {
        let ids = Set(regionMap.flatMap { $0 }).sorted()
        var colors: [Int: Color] = [:]
        var names:  [Int: String] = [:]

        let palette: [(Color, String)] = [
            (Color(.displayP3, red: 205/255, green: 190/255, blue: 245/255), "purple"),
            (Color(.displayP3, red: 245/255, green: 195/255, blue: 215/255), "pink"),
            (Color(.displayP3, red: 191/255, green: 224/255, blue: 187/255), "green"),
            (Color(.displayP3, red: 188/255, green: 211/255, blue: 247/255), "blue"),
            (Color(.displayP3, red: 250/255, green: 242/255, blue: 185/255), "yellow"),
            (Color(.displayP3, red: 240/255, green: 160/255, blue: 160/255), "red"),
            (Color(.displayP3, red: 250/255, green: 195/255, blue: 155/255), "orange"),
            (Color(.displayP3, red: 190/255, green: 190/255, blue: 190/255), "gray"),
            (Color(.displayP3, red: 185/255, green: 235/255, blue: 235/255), "teal"),
        ]

        for (i, id) in ids.enumerated() {
            let (color, name) = palette[i % palette.count]
            colors[id] = color.opacity(0.75)
            names[id]  = name
        }

        regionColors     = colors
        regionColorNames = names
    }

    var size: Int { gridSize }
}
