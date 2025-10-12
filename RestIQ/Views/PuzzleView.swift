//
//  PuzzleView.swift
//  RestIQ
//
//  Created by Alfin Baby on 12/10/25.
//


import SwiftUI

struct PuzzleView: View {
    let level: String
    @State private var timerRunning = false
    @State private var timeElapsed: Int = 0
    @State private var showCompletion = false
    @State private var gridSize: Int = 6  // easy starts at 6x6
    @StateObject private var engine: PuzzleEngine

    init(level: String) {
        self.level = level
        var size = 6
        switch level {
        case "Easy": size = 6
        case "Medium": size = 7
        case "Hard": size = 8
        case "Expert": size = 9
        default: size = 6
        }

        _gridSize = State(initialValue: size)
        let generated = DailyChallengeManager.shared.generatePuzzle(for: level)
        _engine = StateObject(wrappedValue: generated)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label("\(timeElapsed)s", systemImage: "clock")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Difficulty \(level.uppercased())")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Capsule())
            }

            // 2D colored grid
            VStack(spacing: 4) {
                ForEach(0..<gridSize, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(0..<gridSize, id: \.self) { col in
                            let hasQueen = engine.board[row][col]
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(regionColor(row: row, col: col))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                    )
                                    .frame(width: 44, height: 44)

                                if hasQueen {
                                    Image(systemName: "crown.fill")
                                        .font(.title3)
                                        .foregroundColor(.yellow)
                                }
                            }
                            .onTapGesture {
                                engine.toggleQueen(atRow: row, column: col)
                                if engine.checkIfSolved() {
                                    showCompletion = true
                                }
                            }
                        }
                    }
                }
            }
            .padding(.vertical)

            Button(timerRunning ? "Finish Puzzle" : "Start") {
                if timerRunning {
                    showCompletion = true
                    timerRunning = false
                } else {
                    startTimer()
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 10)

            Spacer()
        }
        .padding()
        .navigationTitle(level)
        .alert("Puzzle Completed!", isPresented: $showCompletion) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You finished in \(timeElapsed) seconds.")
        }
        .onAppear {
            configureGridSize(for: level)
        }
    }

    func startTimer() {
        timerRunning = true
        timeElapsed = 0
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if !timerRunning {
                timer.invalidate()
            } else {
                timeElapsed += 1
            }
        }
    }

    func configureGridSize(for level: String) {
        switch level {
        case "Easy": gridSize = 6
        case "Medium": gridSize = 7
        case "Hard": gridSize = 8
        case "Expert": gridSize = 9
        default: gridSize = 6
        }
    }

    func regionColor(row: Int, col: Int) -> Color {
        // alternating pastel color palette for region look
        let colors: [Color] = [
            .mint.opacity(0.5),
            .orange.opacity(0.4),
            .pink.opacity(0.4),
            .yellow.opacity(0.4),
            .purple.opacity(0.4),
            .blue.opacity(0.4)
        ]
        return colors[(row + col) % colors.count]
    }
}
