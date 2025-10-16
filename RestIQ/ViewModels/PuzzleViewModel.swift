//
//  PuzzleViewModel.swift
//  RestIQ
//
//  Created by Alfin Baby on 16/10/25.
//
// Central view model orchestrating PuzzleEngine, timer, and UI-friendly derived data.
// Marked @MainActor to be safely called from SwiftUI.

import Foundation
import SwiftUI
import Combine

@MainActor
final class PuzzleViewModel: ObservableObject {
    @Published private(set) var engine: PuzzleEngine
    @Published var isTimerRunning: Bool = false
    @State var elapsedSeconds: Int = 0
    @Published var regionColors: [Int: Color] = [:]
    @Published var showCompletion: Bool = false

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
        // Engine created synchronously from manager (deterministic)
        self.engine = DailyChallengeManager.shared.generatePuzzle(for: level)
        buildRegionColors()
    }

    // UI actions forwarded from the view
    func tapCell(row: Int, col: Int) {
        engine.tapCell(row: row, col: col)
        // check immediately for completion
        if engine.checkIfSolved() {
            stopTimer()
            showCompletion = true
        }
    }

    func resetBoard() {
        engine.resetBoard()
    }

    // Timer control using Swift concurrency Task
    func startTimer() {
        guard timerTask == nil else { return }
        isTimerRunning = true
        elapsedSeconds = 0

        // Run the timer loop on the main actor (this type is @MainActor)
        timerTask = Task { [weak self] in
            // Since this closure executes on the MainActor (because the enclosing type is @MainActor),
            // UI state mutations are safe.
            while let self, !Task.isCancelled {
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

    // Build stable color map for regions. Uses hue distribution.
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

    // Convenience accessors for views
    var size: Int { gridSize }
}
