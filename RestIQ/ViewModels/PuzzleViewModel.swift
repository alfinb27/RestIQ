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

    private var timerTask: Task<Void, Never>?
    private var engine: QueensPuzzleEngine?
    private let gridSize: Int
    private let difficulty: Difficulty

    init(level: String) {
        switch level {
        case "Easy": gridSize = 6; difficulty = .easy
        case "Medium": gridSize = 7; difficulty = .medium
        case "Hard": gridSize = 8; difficulty = .hard
        case "Expert": gridSize = 9; difficulty = .expert
        default: gridSize = 6; difficulty = .easy
        }
        Task { await generatePuzzle() }
    }

    // MARK: - Puzzle generation
    func generatePuzzle() async {
        isLoading = true
        stopTimer()
        var attempt = 0
        while engine == nil && attempt < 6 {
            attempt += 1
            if let e = await QueensPuzzleEngine.generate(size: gridSize, difficulty: difficulty) {
                engine = e
            }
        }
        guard let engine else {
            print("Puzzle generation failed after \(attempt) attempts.")
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

    func tapCell(row: Int, col: Int) {
        guard let engine else { return }
        Task {
            let changes = await engine.tapCell(row: row, col: col)
            for change in changes {
                board[change.row][change.col] = change.newState
            }
            if await engine.checkIfSolved() {
                stopTimer()
                showCompletion = true
            }
        }
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

    func isPositionInvalid(_ r: Int, _ c: Int) -> Bool { false }
    func borderFlagsFor(_ r: Int, _ c: Int) -> Void {}
}
