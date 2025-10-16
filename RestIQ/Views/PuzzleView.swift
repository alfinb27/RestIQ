//
//  PuzzleView.swift
//  RestIQ
//
//  Created by Alfin Baby on 12/10/25.
//  Updated: Use precomputed invalidPositions and borderFlags for fast renders.
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
            adaptiveBackground

            VStack(spacing: isPad ? 20 : 12) {
                headerView
                gridContainer
                Spacer(minLength: isPad ? 60 : 20)
            }
            .padding(.top, isPad ? 40 : 16)
            .overlay(toastView, alignment: .top)
            .onAppear {
                if !viewModel.isTimerRunning && !viewModel.showCompletion {
                    viewModel.startTimer()
                }
            }
            .onDisappear {
                viewModel.stopTimer()
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

    // MARK: - Adaptive Background
    private var adaptiveBackground: some View {
        ZStack {
            if colorScheme == .light {
                LinearGradient(
                    colors: [
                        Color(.displayP3, red: 0.98, green: 0.65, blue: 0.30).opacity(0.55),
                        Color(.displayP3, red: 0.98, green: 0.50, blue: 0.25).opacity(0.60),
                        Color(.displayP3, red: 0.90, green: 0.35, blue: 0.30).opacity(0.55)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(.displayP3, red: 0.22, green: 0.20, blue: 0.28),
                        Color(.displayP3, red: 0.18, green: 0.16, blue: 0.22),
                        Color(.displayP3, red: 0.12, green: 0.10, blue: 0.16)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(colorScheme == .light ? 0.85 : 0.8)
                .blendMode(.overlay)
        }
        .blur(radius: 45)
        .ignoresSafeArea()
    }

    // MARK: - Toast
    @ViewBuilder
    private var toastView: some View {
        if viewModel.showCompletion {
            VStack {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text("Puzzle Completed!")
                        .font(.headline)
                    Spacer()
                    Text(viewModel.formattedElapsed())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(.thinMaterial)
                .cornerRadius(14)
                .shadow(radius: 7)
                .padding(.top, 32)
                .padding(.horizontal, 32)
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                Haptics.success()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                    withAnimation { viewModel.showCompletion = false }
                }
            }
        }
    }

    // MARK: - Header
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

    // MARK: - Grid Container
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

    // MARK: - Grid
    private var gridView: some View {
        let size = viewModel.size
        return VStack(spacing: 0) {
            ForEach(0..<size, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<size, id: \.self) { col in
                        let cell = viewModel.engine.board[row][col]
                        let regionID = viewModel.engine.regionMap[row][col]
                        let color = viewModel.regionColors[regionID] ?? .gray.opacity(0.2)
                        let isInvalid = viewModel.isPositionInvalid(row, col)
                        let flags = viewModel.borderFlagsFor(row, col)

                        EquatableView(
                            content: PuzzleCellView(
                                cell: cell,
                                regionColor: color,
                                isInvalid: isInvalid,
                                isPad: isPad
                            )
                        )
                        .overlay(regionBorderOverlay(flags: flags))
                        .contentShape(Rectangle()) // cheap hit area
                        .onTapGesture {
                            // fast, minimal closure work
                            viewModel.tapCell(row: row, col: col)
                        }
                    }
                }
            }
        }
    }

    // Draw border using precomputed flags. Fast, simple stroke per cell.
    private func regionBorderOverlay(flags: PuzzleViewModel.BorderFlags) -> some View {
        Rectangle()
            .strokeBorder(.black.opacity(0.7), lineWidth: isPad ? 3 : 2)
            .mask(RegionBorderMask(top: flags.top, bottom: flags.bottom, left: flags.left, right: flags.right))
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
                .border(.black.opacity(0.08), width: 0.5)

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

// MARK: - Region Border Mask (unchanged)
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
