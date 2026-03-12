//
//  PuzzleView.swift
//  RestIQ
//

import SwiftUI

// MARK: - HintCellRole
// Describes how a cell should be visually treated when a hint is active.

enum HintCellRole {
    case forcedTarget    // Mode 1 — place your crown here (amber)
    case regionContext   // Mode 2 — this region is locked to a line (teal)
    case eliminateTarget // Mode 2 — mark this cell ✕ (red-orange)
    case wrongMark       // Scenario B — you marked a correct cell ✕ (red)
}

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
            ZStack {
                AppTheme.backgroundGradient(colorScheme)
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(AppTheme.backgroundMaterialOpacity(colorScheme))
                    .blendMode(.overlay)
            }
            .blur(radius: 45)
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: isPad ? 20 : 12) {
                    headerBar
                    gridContainer
                    liquidControls
                    HowToPlayAccordion(
                        activeHint: viewModel.activeHint,
                        onShowMe: { viewModel.applyShowMe() }
                    )
                    .frame(maxWidth: isPad ? 720 : .infinity)
                    .padding(.horizontal, isPad ? 80 : 20)
                    Spacer(minLength: isPad ? 40 : 16)
                }
                .padding(.top, isPad ? 40 : 16)
            }
            .scrollBounceBehavior(.basedOnSize)
            .overlay(loadingOverlay)
        }
        .sheet(isPresented: $showSettingsSheet) {
            settingsSheet
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(20)
        }
        .navigationDestination(isPresented: $viewModel.showCompletion) {
            PuzzleCompleteView(
                level: level,
                elapsedSeconds: viewModel.elapsedSeconds,
                hintsUsed: viewModel.hintsUsed,
                board: viewModel.board,
                regionMap: viewModel.regionMap,
                regionColors: viewModel.regionColors,
                size: viewModel.size
            )
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
            } else if viewModel.generationFailed {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(AppTheme.liquidInk(colorScheme))
                        Text("Couldn't load puzzle")
                            .font(.headline)
                        Text("This can happen on slower devices.\nTap below to try again.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Try Again") {
                            Haptics.soft()
                            Task { await viewModel.generateDailyPuzzle() }
                        }
                        .buttonStyle(LiquidGlassButtonStyle())
                        .padding(.top, 4)
                    }
                    .padding(32)
                }
            }
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
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
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
                    .allowsHitTesting(!viewModel.showCompletion)
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
                                viewModel.endCrossDrag()
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
                        let cell      = viewModel.board[safe: r]?[safe: c] ?? .empty
                        let regionID  = viewModel.regionMap[safe: r]?[safe: c] ?? 0
                        let color     = viewModel.regionColors[regionID] ?? .gray.opacity(0.25)
                        let isInvalid = viewModel.isPositionInvalid(r, c)
                        let role      = hintRole(row: r, col: c)

                        PuzzleCellView(
                            cell: cell,
                            regionColor: color,
                            isInvalid: isInvalid,
                            hintRole: role,
                            isPad: isPad
                        )
                        .frame(width: cellSize, height: cellSize)
                        .contentShape(Rectangle())
                        .onTapGesture { viewModel.tapCell(row: r, col: c) }
                        .overlay(Rectangle().stroke(Color.black.opacity(0.25), lineWidth: 0.6))
                    }
                }
            }
        }
    }

    // Returns the hint role for a cell, given the current activeHint.
    private func hintRole(row: Int, col: Int) -> HintCellRole? {
        guard let hint = viewModel.activeHint else { return nil }
        switch hint.mode {
        case .forcedPlacement(let r, let c):
            return (r == row && c == col) ? .forcedTarget : nil
        case .wrongMark(let r, let c):
            return (r == row && c == col) ? .wrongMark : nil
        case .elimination(let regionCells, let elimCells):
            let coord = GridCoord(row: row, col: col)
            if elimCells.contains(coord)   { return .eliminateTarget }
            if regionCells.contains(coord) { return .regionContext }
            return nil
        case .noHint:
            return nil  // no cell highlighting for this state
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

        if !isDragging {
            dragActionIsPlacing = (viewModel.board[row][col] != .markedX)
            isDragging = true
            viewModel.beginCrossDrag()
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
        let cooldown = viewModel.hintCooldownRemaining

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
            .disabled(!viewModel.canUndo || viewModel.showCompletion)

            Button {
                viewModel.revealHint()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: cooldown > 0 ? "hourglass" : "lightbulb")
                        .font(.system(size: isPad ? 18 : 16, weight: .semibold))
                        .symbolEffect(.pulse, isActive: cooldown > 0)
                    Text(cooldown > 0 ? "Hint in \(cooldown)s" : "Hint (\(viewModel.hintsUsed) used)")
                        .font(.system(size: isPad ? 18 : 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(LiquidGlassButtonStyle())
            .frame(height: controlHeight)
            .disabled(cooldown > 0 || viewModel.activeHint != nil || viewModel.isLoading || viewModel.showCompletion)
        }
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

// MARK: - Safe Subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        (0..<count).contains(index) ? self[index] : nil
    }
}

// MARK: - Puzzle Cell View

struct PuzzleCellView: View {
    let cell: CellState
    let regionColor: Color
    let isInvalid: Bool
    let hintRole: HintCellRole?
    let isPad: Bool

    var body: some View {
        ZStack {
            Rectangle().fill(regionColor)

            // Hint overlay — very faint tint so region colour stays legible.
            // The border carries the visual weight; the fill is just a subtle wash.
            if let role = hintRole {
                Rectangle().fill(overlayColor(for: role))
            }

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
        // Inset the hint border slightly so it doesn't bleed into the grid lines
        .overlay(
            Rectangle()
                .inset(by: borderWidth() > 0 ? 1 : 0)
                .stroke(borderColor(), lineWidth: borderWidth())
        )
    }

    private func overlayColor(for role: HintCellRole) -> Color {
        switch role {
        case .forcedTarget:    return Color.orange.opacity(0.12)
        case .regionContext:   return Color.teal.opacity(0.10)
        case .eliminateTarget: return Color.red.opacity(0.12)
        case .wrongMark:       return Color.red.opacity(0.14)
        }
    }

    private func borderColor() -> Color {
        if isInvalid { return .red }
        switch hintRole {
        case .forcedTarget:    return Color.orange
        case .regionContext:   return Color.teal
        case .eliminateTarget: return Color.red
        case .wrongMark:       return Color.red
        case nil:              return .clear
        }
    }

    private func borderWidth() -> CGFloat {
        guard !isInvalid else { return 2 }
        switch hintRole {
        case .forcedTarget, .eliminateTarget, .wrongMark: return 3
        case .regionContext:                               return 2
        case nil:                                         return 0
        }
    }
}

#Preview("Easy") {
    NavigationStack { PuzzleView(level: "Easy") }
}
