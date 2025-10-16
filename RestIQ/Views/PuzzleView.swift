//
//  PuzzleView.swift
//  RestIQ
//
//  Created by Alfin Baby on 12/10/25.
//  Optimized for Swift 6 & SwiftUI performance (Equatable cells, lightweight redraws).
//

import SwiftUI

@available(iOS 18.0, *)
struct PuzzleView: View {
    let level: String
    @StateObject private var viewModel: PuzzleViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    init(level: String) {
        _viewModel = StateObject(wrappedValue: PuzzleViewModel(level: level))
        self.level = level
    }

    var body: some View {
        ZStack {
            // background
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
            .overlay(Rectangle().fill(.ultraThinMaterial).ignoresSafeArea())

            VStack(spacing: isPad ? 20 : 12) {
                headerView
                gridContainer
                controlView
                Spacer(minLength: isPad ? 60 : 20)
            }
            .padding(.top, isPad ? 40 : 16)
            .alert("Puzzle Completed!", isPresented: $viewModel.showCompletion) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You finished in \(viewModel.formattedElapsed()).")
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
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.12),
                            radius: 6, x: 0, y: 3)
            }
        }
    }

    // MARK: Header
    private var headerView: some View {
        HStack {
            Label(viewModel.formattedElapsed(), systemImage: "clock")
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
                withAnimation(.easeInOut) { viewModel.resetBoard() }
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

    // MARK: Grid Container
    private var gridContainer: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.regularMaterial)
            .overlay(gridView.padding(8))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.1),
                    radius: 12, x: 0, y: 4)
            .padding(.horizontal, isPad ? 80 : 20)
            .frame(maxWidth: isPad ? 720 : .infinity)
            .aspectRatio(1, contentMode: .fit)
    }

    // MARK: Grid
    private var gridView: some View {
        let size = viewModel.size
        return VStack(spacing: 0) {
            ForEach(0..<size, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<size, id: \.self) { col in
                        let cell = viewModel.engine.board[row][col]
                        let regionID = viewModel.engine.regionMap[row][col]
                        let color = viewModel.regionColors[regionID] ?? .gray.opacity(0.2)
                        let isInvalid = (cell == .queen && !viewModel.engine.isValidPlacement(row: row, col: col))

                        EquatableView(
                            content: PuzzleCellView(
                                cell: cell,
                                regionColor: color,
                                isInvalid: isInvalid,
                                isPad: isPad
                            )
                        )
                        .overlay(regionBorders(row: row, col: col, size: size))
                        .onTapGesture {
                            viewModel.tapCell(row: row, col: col)
                        }
                    }
                }
            }
        }
    }

    // MARK: Controls
    private var controlView: some View {
        Button(viewModel.isTimerRunning ? "Finish" : "Start") {
            if viewModel.isTimerRunning {
                viewModel.stopTimer()
                viewModel.showCompletion = true
            } else {
                viewModel.startTimer()
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

    // MARK: Region Borders
    private func regionBorders(row: Int, col: Int, size: Int) -> some View {
        let current = viewModel.engine.regionMap[row][col]
        var top = false, bottom = false, left = false, right = false

        if row > 0 && viewModel.engine.regionMap[row - 1][col] != current { top = true }
        if row < size - 1 && viewModel.engine.regionMap[row + 1][col] != current { bottom = true }
        if col > 0 && viewModel.engine.regionMap[row][col - 1] != current { left = true }
        if col < size - 1 && viewModel.engine.regionMap[row][col + 1] != current { right = true }

        return Rectangle()
            .strokeBorder(.black.opacity(0.7), lineWidth: isPad ? 3 : 2)
            .mask(RegionBorderMask(top: top, bottom: bottom, left: left, right: right))
    }
}

// MARK: - Cell View (Equatable)
private struct PuzzleCellView: View, Equatable {
    static func == (lhs: PuzzleCellView, rhs: PuzzleCellView) -> Bool {
        lhs.cell == rhs.cell && lhs.isInvalid == rhs.isInvalid
    }

    let cell: CellState
    let regionColor: Color
    let isInvalid: Bool
    let isPad: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(regionColor)
                .border(.black.opacity(0.1), width: 0.5)
            if cell == .queen {
                Image(systemName: "crown.fill")
                    .font(.system(size: isPad ? 30 : 20))
                    .foregroundColor(.yellow)
                    .shadow(radius: 1)
            } else if cell == .markedX {
                Text("×")
                    .font(.system(size: isPad ? 32 : 22))
                    .foregroundColor(.gray)
            }
        }
        .overlay(
            Rectangle()
                .stroke(isInvalid ? Color.red : .clear,
                        lineWidth: isInvalid ? 2 : 0)
        )
    }
}

// MARK: - Region Border Mask
@available(iOS 18.0, *)
struct RegionBorderMask: Shape {
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
