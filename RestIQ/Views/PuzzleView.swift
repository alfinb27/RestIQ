//
//  PuzzleView.swift
//  RestIQ
//
//  Created by Alfin Baby on 12/10/25.
//  Refined for iOS 18+ Liquid Glass aesthetic, preserving classic grid visuals.
//

import SwiftUI

@available(iOS 18.0, *)
struct PuzzleView: View {
    let level: String
    @State private var timerRunning = false
    @State private var timeElapsed: Int = 0
    @State private var showCompletion = false
    @State private var gridSize: Int = 6
    @StateObject private var engine: PuzzleEngine
    @Environment(\.colorScheme) private var colorScheme

    @State private var regionColorMap: [Int: Color] = [:]

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

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
            // MARK: - Warm Liquid Glass Background
            LinearGradient(
                colors: [
                    Color(.displayP3, red: 1.00, green: 0.74, blue: 0.40),
                    Color(.displayP3, red: 1.00, green: 0.56, blue: 0.36),
                    Color(.displayP3, red: 0.96, green: 0.28, blue: 0.36)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.35)
            .blur(radius: 60)
            .ignoresSafeArea()
            .overlay(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
            )

            VStack(spacing: isPad ? 20 : 12) {
                headerView

                // MARK: - Frosted Grid Container (Glass Pane)
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .overlay(
                        gridView
                            .padding(8)
                    )
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.1),
                            radius: 12, x: 0, y: 4)
                    .padding(.horizontal, isPad ? 80 : 20)
                    .frame(maxWidth: isPad ? 720 : .infinity)
                    .aspectRatio(1, contentMode: .fit)

                controlView
                Spacer(minLength: isPad ? 60 : 20)
            }
            .padding(.top, isPad ? 40 : 16)
            .onAppear { buildRegionColorMap() }
            .alert("Puzzle Completed!", isPresented: $showCompletion) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You finished in \(formattedTime()).")
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(level.uppercased())
                    .font(.system(size: isPad ? 22 : 18, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(.displayP3, red: 1.0, green: 0.7, blue: 0.4),
                                Color(.displayP3, red: 0.96, green: 0.3, blue: 0.36)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12),
                            radius: 6, x: 0, y: 3)
                    .padding(.top, 4)
            }
        }

    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Label("\(formattedTime())", systemImage: "clock")
                .font(.system(size: isPad ? 22 : 16))
                .foregroundColor(.secondary)

            Spacer()

            Text(level.uppercased())
                .font(.system(size: isPad ? 16 : 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.thinMaterial)
                .cornerRadius(10)

            Spacer()

            Button {
                withAnimation(.easeInOut) {
                    engine.resetBoard()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: isPad ? 24 : 18))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, isPad ? 100 : 20)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(radius: 3)
    }

    // MARK: - Grid (unchanged visuals)
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
                                .overlay(lightGridLines())
                                .overlay(regionBorders(row: row, col: col))

                            if cell == .markedX {
                                Text("×")
                                    .font(.system(size: isPad ? 32 : 22))
                                    .foregroundColor(.gray)
                            } else if cell == .queen {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: isPad ? 30 : 20))
                                    .foregroundColor(.yellow)
                                    .shadow(radius: 1)
                            }
                        }
                        .overlay(
                            Rectangle()
                                .stroke(isInvalid ? Color.red : .clear,
                                        lineWidth: isInvalid ? 2 : 0)
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
        .font(.system(size: isPad ? 20 : 16))
        .buttonStyle(.borderedProminent)
        .tint(Color(.displayP3, red: 0.96, green: 0.28, blue: 0.36))
        .padding(.top, isPad ? 20 : 10)
        .background(.thinMaterial)
        .cornerRadius(12)
        .shadow(radius: 3)
    }

    // MARK: - Timer
    private func startTimer() {
        timerRunning = true
        timeElapsed = 0
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if !timerRunning { timer.invalidate() }
            else { timeElapsed += 1 }
        }
    }

    private func formattedTime() -> String {
        String(format: "%d:%02d", timeElapsed / 60, timeElapsed % 60)
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
        regionColorMap[id] ??
        Color(hue: Double(id) * 0.15.truncatingRemainder(dividingBy: 1.0),
              saturation: 0.5, brightness: 0.95)
        .opacity(0.35)
    }

    private func lightGridLines() -> some View {
        Rectangle()
            .stroke(Color.black.opacity(1.0), lineWidth: 0.5)
    }

    private func regionBorders(row: Int, col: Int) -> some View {
        let current = engine.regionMap[row][col]
        var top = false, bottom = false, left = false, right = false

        if row > 0 && engine.regionMap[row - 1][col] != current { top = true }
        if row < gridSize - 1 && engine.regionMap[row + 1][col] != current { bottom = true }
        if col > 0 && engine.regionMap[row][col - 1] != current { left = true }
        if col < gridSize - 1 && engine.regionMap[row][col + 1] != current { right = true }

        return Rectangle()
            .strokeBorder(Color.black.opacity(0.7), lineWidth: isPad ? 3 : 2)
            .mask(RegionBorderMask(top: top, bottom: bottom, left: left, right: right))
    }
}

// MARK: - Region Border Mask
@available(iOS 18.0, *)
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
    NavigationStack { PuzzleView(level: "Easy") }
}
