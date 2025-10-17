//
//  PuzzleView.swift
//  RestIQ
//
//  Created by Alfin Baby on 12/10/25.
//

import SwiftUI
import Foundation

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

    // MARK: Background
    private var adaptiveBackground: some View {
        LinearGradient(
            colors: colorScheme == .light
            ? [Color.orange.opacity(0.5), Color.red.opacity(0.4)]
            : [Color.black.opacity(0.8), Color.gray.opacity(0.5)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: Loading Overlay
    private var loadingOverlay: some View {
        Group {
            if viewModel.isLoading {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
                    ProgressView("Generating Puzzle…")
                        .tint(.orange)
                        .font(.headline)
                }
            }
        }
    }

    // MARK: Toast
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
        }
    }

    // MARK: Header
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

    // MARK: Grid Container
    private var gridContainer: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.black, lineWidth: isPad ? 4 : 3)
            gridView.padding(8)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.1),
                radius: 12, x: 0, y: 4)
        .padding(.horizontal, isPad ? 80 : 20)
        .frame(maxWidth: isPad ? 720 : .infinity)
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: Grid View
    private var gridView: some View {
        let size = viewModel.size
        return VStack(spacing: 0) {
            ForEach(0..<size, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<size, id: \.self) { col in
                        let cell = viewModel.board[safe: row]?[safe: col] ?? .empty
                        let regionID = viewModel.regionMap[safe: row]?[safe: col] ?? 0
                        let color = viewModel.regionColors[regionID] ?? .gray.opacity(0.25)

                        PuzzleCellView(cell: cell, regionColor: color, isPad: isPad)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.tapCell(row: row, col: col)
                            }
                            .overlay(Rectangle().strokeBorder(.black.opacity(0.15), lineWidth: 0.5))
                    }
                }
            }
        }
    }
}

// MARK: - Safe subscript
private extension Array {
    subscript(safe index: Int) -> Element? {
        (0..<count).contains(index) ? self[index] : nil
    }
}

// MARK: - Cell View
private struct PuzzleCellView: View {
    let cell: CellState
    let regionColor: Color
    let isPad: Bool

    var body: some View {
        ZStack {
            Rectangle().fill(regionColor)
            switch cell {
            case .queen:
                Image(systemName: "crown.fill")
                    .font(.system(size: isPad ? 30 : 20))
                    .foregroundColor(.yellow)
            case .markedX:
                Text("×")
                    .font(.system(size: isPad ? 32 : 22))
                    .foregroundColor(.gray)
            default:
                EmptyView()
            }
        }
    }
}

#Preview("Easy") {
    NavigationStack { PuzzleView(level: "Easy") }
}
