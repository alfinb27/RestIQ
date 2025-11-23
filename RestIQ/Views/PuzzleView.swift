//
//  PuzzleView.swift
//  RestIQ
//
//  Updated to work with QueensPuzzleEngineV2 and CellStateV2
//  Created: ChatGPT
//

import SwiftUI

@available(iOS 18.0, *)
struct PuzzleView: View {
    let level: String
    @StateObject private var viewModel: PuzzleViewModel
    @State private var showSettingsSheet = false

    // Drag state
    @State private var isDragging = false
    @State private var lastDragCell: PuzzleViewModel.BoardPos?
    @State private var dragActionIsPlacing = true

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    init(level: String) {
        _viewModel = StateObject(wrappedValue: PuzzleViewModel(level: level))
        self.level = level
    }

    var body: some View {
        ZStack {
            AppBackground()
                .ignoresSafeArea()

            VStack(spacing: isPad ? 20 : 12) {
                headerBar
                gridContainer
                liquidControls
                Spacer(minLength: isPad ? 40 : 16)
            }
            .padding(.top, isPad ? 40 : 16)
            .overlay(toastView, alignment: .top)
            .overlay(loadingOverlay)
        }
        .sheet(isPresented: $showSettingsSheet) {
            settingsSheet
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(20)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(level.uppercased())
                    .font(.system(size: isPad ? 22 : 18, weight: .bold, design: .rounded))
            }
        }
    }

    // Loading overlay
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

    // Toast
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

    // Header Bar
    private var headerBar: some View {
        HStack(spacing: 12) {
            if viewModel.showClock {
                Label(viewModel.formattedElapsed(), systemImage: "clock")
                    .font(.system(size: isPad ? 22 : 16))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AppTheme.liquidInk())
            } else {
                Spacer().frame(width: isPad ? 80 : 60)
            }

            Spacer()

            Button {
                Haptics.soft()
                showSettingsSheet = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: isPad ? 20 : 18, weight: .semibold))
            }
            .buttonStyle(LiquidGlassButtonStyle())

            Button {
                withAnimation(.easeInOut) { viewModel.resetBoard() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: isPad ? 20 : 18))
            }
            .buttonStyle(LiquidGlassButtonStyle())
            .disabled(viewModel.isLoading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(radius: 3)
        .frame(maxWidth: isPad ? 720 : .infinity)
        .padding(.horizontal, isPad ? 80 : 20)
    }

    // Grid Container
    private var gridContainer: some View {
        GeometryReader { geo in
            let gridSize = viewModel.size
            let side = geo.size.width
            let cellSize = side / CGFloat(max(1, gridSize))

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black, lineWidth: isPad ? 10 : 8)

                gridView(cellSize: cellSize)
                    .frame(width: side, height: side)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                handleDrag(location: value.location,
                                           gridSize: gridSize,
                                           cellSize: cellSize,
                                           in: geo.size)
                            }
                            .onEnded { _ in
                                viewModel.endCrossDrag()
                                isDragging = false
                                lastDragCell = nil
                            }
                    )
            }
            .frame(width: side, height: side, alignment: .center)
        }
        .aspectRatio(1.0, contentMode: .fit)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, isPad ? 80 : 20)
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
    }

    // Grid View
    private func gridView(cellSize: CGFloat) -> some View {
        let gridSize = viewModel.size
        return VStack(spacing: 0) {
            ForEach(0..<gridSize, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<gridSize, id: \.self) { c in
                        let cell = viewModel.board[safe: r]?[safe: c] ?? .empty
                        let regionID = viewModel.regionMap[safe: r]?[safe: c] ?? 0
                        let color = viewModel.regionColors[regionID] ?? .gray.opacity(0.25)
                        let isInvalid = viewModel.isPositionInvalid(r, c)

                        PuzzleCellViewV2(
                            cell: cell,
                            regionColor: color,
                            isInvalid: isInvalid,
                            isPad: isPad
                        )
                        .frame(width: cellSize, height: cellSize)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.tapCell(row: r, col: c)
                        }
                        .overlay(Rectangle().stroke(Color.black.opacity(0.25), lineWidth: 0.6))
                    }
                }
            }
        }
    }

    // Drag handling
    private func handleDrag(location: CGPoint, gridSize: Int, cellSize: CGFloat, in grid: CGSize) {
        let x = max(0, min(location.x, grid.width - 1))
        let y = max(0, min(location.y, grid.height - 1))
        let col = Int(x / cellSize)
        let row = Int(y / cellSize)
        guard row >= 0, row < gridSize, col >= 0, col < gridSize else { return }

        let current = PuzzleViewModel.BoardPos(r: row, c: col)
        guard current != lastDragCell else { return }

        if !isDragging {
            let currentState = viewModel.board[row][col]
            viewModel.beginCrossDrag()
            dragActionIsPlacing = (currentState != .markedX)
            isDragging = true
        }

        if dragActionIsPlacing {
            viewModel.setCross(row: row, col: col, state: .markedX)
        } else {
            viewModel.setCross(row: row, col: col, state: .empty)
        }

        lastDragCell = current
    }

    // Liquid controls
    private var liquidControls: some View {
        let controlHeight: CGFloat = isPad ? 48 : 44

        return HStack(spacing: 14) {
            Button {
                Haptics.soft()
                viewModel.undo()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
                    .font(.system(size: isPad ? 18 : 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LiquidGlassButtonStyle())
            .frame(height: controlHeight)
            .disabled(!viewModel.canUndo)

            Button {
                Haptics.light()
                viewModel.revealHint()
            } label: {
                Label("Hint \(viewModel.hintsUsed)/\(viewModel.maxHints)", systemImage: "lightbulb")
                    .font(.system(size: isPad ? 18 : 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LiquidGlassButtonStyle())
            .frame(height: controlHeight)
            .disabled(viewModel.hintsUsed >= viewModel.maxHints || viewModel.isLoading)
        }
        .padding(.bottom, 120)
        .frame(maxWidth: isPad ? 720 : .infinity)
        .padding(.horizontal, isPad ? 80 : 20)
    }

    // Settings sheet
    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("Display")) {
                    Toggle("Show clock", isOn: $viewModel.showClock)
                }
                Section(header: Text("Gameplay")) {
                    Toggle("Auto-place crosses", isOn: $viewModel.autoPlaceCrosses)
                        .tint(.orange)
                    Text("Drag across the grid to toggle crosses (X) on or off accurately.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Options")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showSettingsSheet = false }
                        .buttonStyle(LiquidGlassButtonStyle())
                }
            }
        }
    }
}

// MARK: - PuzzleCellViewV2
private struct PuzzleCellViewV2: View {
    let cell: CellStateV2
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
                    .fontWeight(.thin)
                    .foregroundColor(.black)
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

// Safe subscript
private extension Array {
    subscript(safe index: Int) -> Element? {
        (0..<count).contains(index) ? self[index] : nil
    }
}


// Preview
#Preview {
    NavigationStack { PuzzleView(level: "Easy") }
}
