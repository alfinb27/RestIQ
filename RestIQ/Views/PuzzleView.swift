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
    @State private var gridSize: Int = 6
    @StateObject private var engine: PuzzleEngine

    @State private var regionColorMap: [Int: Color] = [:]

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
        let engine = DailyChallengeManager.shared.generatePuzzle(for: level)
        _engine = StateObject(wrappedValue: engine)
    }

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()

            VStack(spacing: 12) {
                headerView
                gridView
                controlView
                Spacer()
            }
            .padding(.top)
            .onAppear { buildRegionColorMap() }
            .alert("Puzzle Completed!", isPresented: $showCompletion) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You finished in \(formattedTime()).")
            }
        }
        .navigationTitle(level)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Label("\(formattedTime())", systemImage: "clock")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text("Difficulty \(level.uppercased())")
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.15))
                .clipShape(Capsule())

            Spacer()

            Button {
                engine.resetBoard()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Grid
    private var gridView: some View {
        VStack(spacing: 0) {
            ForEach(0..<gridSize, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<gridSize, id: \.self) { col in
                        let cell = engine.board[row][col]
                        let regionID = engine.regionMap[row][col]
                        let color = regionColor(for: regionID)
                        let isInvalid = (cell == .queen && !engine.isValidPlacement(row: row, col: col))

                        ZStack {
                            Rectangle()
                                .fill(color)
                                .overlay(lightGridLines(row: row, col: col)) // light separators
                                .overlay(regionBorders(row: row, col: col))   // dark region borders

                            if cell == .markedX {
                                Text("×")
                                    .font(.title3)
                                    .foregroundColor(.gray)
                            } else if cell == .queen {
                                Image(systemName: "crown.fill")
                                    .font(.title3)
                                    .foregroundColor(.yellow)
                                    .shadow(radius: 1)
                            }
                        }
                        .overlay(
                            Rectangle()
                                .stroke(isInvalid ? Color.red : .clear, lineWidth: isInvalid ? 2 : 0)
                        )
                        .onTapGesture {
                            engine.tapCell(row: row, col: col)
                            if engine.checkIfSolved() {
                                showCompletion = true
                            }
                        }
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .cornerRadius(12)
        .shadow(radius: 4)
        .padding(.horizontal, 20)
    }

    // MARK: - Controls
    private var controlView: some View {
        Button(timerRunning ? "Finish" : "Start") {
            if timerRunning {
                timerRunning = false
                showCompletion = true
            } else {
                startTimer()
            }
        }
        .buttonStyle(.borderedProminent)
        .padding(.top, 10)
    }

    // MARK: - Timer
    private func startTimer() {
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

    private func formattedTime() -> String {
        let minutes = timeElapsed / 60
        let seconds = timeElapsed % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Colors
    private func buildRegionColorMap() {
        var ids = Set<Int>()
        for r in 0..<gridSize {
            for c in 0..<gridSize {
                ids.insert(engine.regionMap[r][c])
            }
        }
        let sorted = ids.sorted()
        let total = max(sorted.count, 1)
        var map: [Int: Color] = [:]

        for (index, id) in sorted.enumerated() {
            let hue = Double(index) / Double(total)
            let color = Color(hue: hue, saturation: 0.5, brightness: 0.95).opacity(0.35)
            map[id] = color
        }
        regionColorMap = map
    }

    private func regionColor(for id: Int) -> Color {
        regionColorMap[id] ?? Color(hue: Double(id) * 0.15.truncatingRemainder(dividingBy: 1.0),
                                    saturation: 0.5,
                                    brightness: 0.95)
                                    .opacity(0.35)
    }

    // MARK: - Grid Lines
    private func lightGridLines(row: Int, col: Int) -> some View {
        Rectangle()
            .stroke(Color.black.opacity(1.0), lineWidth: 0.5) // subtle separators between all cells
    }

    // MARK: - Region Borders
    private func regionBorders(row: Int, col: Int) -> some View {
        let current = engine.regionMap[row][col]
        var top = false, bottom = false, left = false, right = false

        if row > 0 && engine.regionMap[row-1][col] != current { top = true }
        if row < gridSize-1 && engine.regionMap[row+1][col] != current { bottom = true }
        if col > 0 && engine.regionMap[row][col-1] != current { left = true }
        if col < gridSize-1 && engine.regionMap[row][col+1] != current { right = true }

        return Rectangle()
            .strokeBorder(Color.black.opacity(0.7), lineWidth: 2)
            .mask(
                RegionBorderMask(top: top, bottom: bottom, left: left, right: right)
            )
    }
}

// MARK: - Region Border Mask
private struct RegionBorderMask: Shape {
    let top: Bool
    let bottom: Bool
    let left: Bool
    let right: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let lw: CGFloat = 2
        if top { path.addRect(CGRect(x: 0, y: 0, width: rect.width, height: lw)) }
        if bottom { path.addRect(CGRect(x: 0, y: rect.height - lw, width: rect.width, height: lw)) }
        if left { path.addRect(CGRect(x: 0, y: 0, width: lw, height: rect.height)) }
        if right { path.addRect(CGRect(x: rect.width - lw, y: 0, width: lw, height: rect.height)) }
        return path
    }
}

#Preview("Easy") {
    NavigationStack {
        PuzzleView(level: "Easy")
    }
}

#Preview("Medium - Dark") {
    NavigationStack {
        PuzzleView(level: "Medium")
            .preferredColorScheme(.dark)
    }
}

#Preview("Hard - Larger Dynamic Type") {
    NavigationStack {
        PuzzleView(level: "Hard")
            .environment(\.sizeCategory, .accessibilityExtraLarge)
    }
}

#Preview("Expert") {
    NavigationStack {
        PuzzleView(level: "Expert")
    }
}
