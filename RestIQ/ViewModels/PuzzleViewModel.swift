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
    @Published var board: [[CellState]] = []
    @Published var regionMap: [[Int]] = []
    @Published var regionColors: [Int: Color] = [:]
    @Published var showCompletion = false
    @Published var isLoading = true
    @Published var elapsedSeconds = 0
    @Published var conflictMessage: String? = nil

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
        startTimer()
    }

    // MARK: - Cell Interaction
    func tapCell(row: Int, col: Int) {
        guard let engine else { return }
        Task {
            let changes = await engine.tapCell(row: row, col: col)
            for change in changes {
                board[change.row][change.col] = change.newState
            }

            // Conflict detection for toast
            if board[row][col] == .queen {
                let conflicts = await engine.conflictTypesForQueen(at: row, col: col)
                if !conflicts.isEmpty {
                    await MainActor.run {
                        Haptics.warning()
                    }
                }
            }

            // 🔴 Recompute red highlight invalids
            await computeInvalidPositions()

            if await engine.checkIfSolved() {
                stopTimer()
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

        await MainActor.run { self.invalidPositions = invalid }
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
        }
    }

    // MARK: - Conflict Toast
    private func showConflictToast(with conflicts: [String]) {
        conflictMessage = "Conflict: " + conflicts.joined(separator: ", ")
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
                await MainActor.run { self.elapsedSeconds += 1 }
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
            let hue = Double(id % 10) / 10.0
            colors[id] = Color(hue: hue, saturation: 0.5, brightness: 0.9).opacity(0.35)
        }
        regionColors = colors
    }

    var size: Int { gridSize }
}
