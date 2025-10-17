//
//  PuzzleView.swift
//  RestIQ
//
//  Created by Alfin Baby on 12/10/25.
//  Updated: Tight black border (no gap) and adaptive background.
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
            .overlay(loadingOverlay)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(level.uppercased())
                    .font(.system(size: isPad ? 22 : 18, weight: .bold, design: .rounded))
            }
        }
    }

    // MARK: - Background (as requested)
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

    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        Group {
            if viewModel.isLoading {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView().tint(.orange)
                        Text("Generating Puzzle…")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Completion Toast
    @ViewBuilder
    private var toastView: some View {
        if viewModel.showCompletion {
            VStack {
                HStack {
                    Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
                    Text("Puzzle Completed!").font(.headline)
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
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Label(viewModel.formattedElapsed(), systemImage: "clock")
                .font(.system(size: isPad ? 22 : 16))
                .foregroundColor(.secondary)
            Spacer()
            Button {
                Task { await MainActor.run { withAnimation(.easeInOut) { viewModel.resetBoard() } } }
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

    // MARK: - Grid Container (no gap, thick black border)
    private var gridContainer: some View {
        GeometryReader { geo in
            ZStack {
                // Outer thick black frame with zero padding
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black, lineWidth: isPad ? 10 : 8)

                // Grid fills the interior exactly
                gridView
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(isPad ? 5 : 4)
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(.horizontal, isPad ? 80 : 20)
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.1),
                    radius: 12, x: 0, y: 4)
        }
        .frame(maxWidth: isPad ? 720 : .infinity)
    }

    // MARK: - Grid View (internal black separators)
    private var gridView: some View {
        let size = viewModel.size
        return GeometryReader { geo in
            let cellSize = min(geo.size.width, geo.size.height) / CGFloat(size)
            VStack(spacing: 0) {
                ForEach(0..<size, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<size, id: \.self) { col in
                            let cell = viewModel.board[safe: row]?[safe: col] ?? .empty
                            let regionID = viewModel.regionMap[safe: row]?[safe: col] ?? 0
                            let color = viewModel.regionColors[regionID] ?? .gray.opacity(0.25)
                            let isInvalid = viewModel.isPositionInvalid(row, col)

                            PuzzleCellView(
                                cell: cell,
                                regionColor: color,
                                isInvalid: isInvalid,
                                isPad: isPad
                            )
                            .frame(width: cellSize, height: cellSize)
                            .contentShape(Rectangle())
                            .onTapGesture { viewModel.tapCell(row: row, col: col) }
                            // thin black grid lines
                            .overlay(Rectangle().stroke(Color.black.opacity(0.25), lineWidth: 0.6))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Safe Subscript
private extension Array {
    subscript(safe index: Int) -> Element? {
        (0..<count).contains(index) ? self[index] : nil
    }
}

// MARK: - Puzzle Cell View
private struct PuzzleCellView: View {
    let cell: CellState
    let regionColor: Color
    let isInvalid: Bool
    let isPad: Bool

    var body: some View {
        ZStack {
            Rectangle().fill(regionColor)
            switch cell {
            case .queen:
                Image(systemName: "crown.fill")
                    .font(.system(size: isPad ? 30 : 20))
                    .foregroundColor(.yellow)
                    .shadow(radius: 1)
            case .markedX:
                Text("×")
                    .font(.system(size: isPad ? 32 : 22))
                    .foregroundColor(.gray)
            default:
                EmptyView()
            }
        }
        .overlay(
            Rectangle()
                .stroke(isInvalid ? Color.red : .clear, lineWidth: isInvalid ? 2 : 0)
        )
    }
}

// MARK: - Preview
#Preview("Easy") {
    NavigationStack { PuzzleView(level: "Easy") }
}
