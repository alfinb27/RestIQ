//
//  PuzzleView.swift
//  RestIQ
//
//  Created by Alfin Baby on 12/10/25.
//  Updated: drag-to-toggle crosses with accurate grid mapping and fixed tap handling.
//

import SwiftUI

@available(iOS 18.0, *)
struct PuzzleView: View {
    let level: String
    @StateObject private var viewModel: PuzzleViewModel
    @Environment(\.colorScheme) private var colorScheme
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
            // Themed background
            ZStack {
                AppTheme.backgroundGradient(colorScheme)
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(AppTheme.backgroundMaterialOpacity(colorScheme))
                    .blendMode(.overlay)
            }
            .blur(radius: 45)
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

    // MARK: - Toasts
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

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 12) {
            if viewModel.showClock {
                Label(viewModel.formattedElapsed(), systemImage: "clock")
                    .font(.system(size: isPad ? 22 : 16))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AppTheme.liquidInk(colorScheme))
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

    // MARK: - Grid Container
    private var gridContainer: some View {
        GeometryReader { geo in
            let gridSize = viewModel.size
            let availableWidth = min(geo.size.width, UIScreen.main.bounds.width - (isPad ? 160 : 40))
            let side = min(availableWidth, geo.size.height)
            let cell = side / CGFloat(gridSize)

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black, lineWidth: isPad ? 10 : 8)

                gridView(cellSize: cell)
                    .frame(width: side, height: side)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                handleDrag(location: value.location,
                                           gridSize: gridSize,
                                           cellSize: cell,
                                           in: CGSize(width: side, height: side))
                            }
                            .onEnded { _ in
                                isDragging = false
                                lastDragCell = nil
                            }
                    )
            }
            .frame(width: side, height: side, alignment: .center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, isPad ? 80 : 20)
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.1),
                    radius: 12, x: 0, y: 4)
        }
        .frame(height: UIScreen.main.bounds.width - (isPad ? 160 : 40))
    }

    // MARK: - Grid View
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

                        PuzzleCellView(
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

    // MARK: - Drag Handling
    private func handleDrag(location: CGPoint, gridSize: Int, cellSize: CGFloat, in grid: CGSize) {
        let x = max(0, min(location.x, grid.width - 1))
        let y = max(0, min(location.y, grid.height - 1))
        let col = Int(x / cellSize)
        let row = Int(y / cellSize)
        guard row >= 0, row < gridSize, col >= 0, col < gridSize else { return }

        let current = PuzzleViewModel.BoardPos(r: row, c: col)
        guard current != lastDragCell else { return }

        let currentState = viewModel.board[row][col]
        if !isDragging {
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

    // MARK: - Liquid Controls
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

    // MARK: - Settings Sheet
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

// MARK: - Liquid Glass Button Style
struct LiquidGlassButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    var accent: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.9)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.45), Color.white.opacity(0.08)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            .overlay(
                LinearGradient(
                    colors: [Color.white.opacity(0.25), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blur(radius: 1.2)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            )
            .shadow(color: .black.opacity(0.18), radius: 6, x: 2, y: 3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .foregroundStyle(AppTheme.liquidInk(colorScheme, accent: accent))
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

#Preview("Easy") {
    NavigationStack { PuzzleView(level: "Easy") }
}
