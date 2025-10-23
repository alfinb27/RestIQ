//
//  PuzzleView.swift
//  RestIQ
//
//  Created by Alfin Baby on 12/10/25.
//  Updated: scheme-aware gradients (purple in dark, orange in light) via AppTheme.
//           Make Undo & Hint buttons exactly the same size.
//
import SwiftUI

@available(iOS 18.0, *)
struct PuzzleView: View {
    let level: String
    @StateObject private var viewModel: PuzzleViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showSettingsSheet = false

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
            .overlay(conflictToast, alignment: .top)
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

    // MARK: - Conflict Toast
    @ViewBuilder
    private var conflictToast: some View {
        if let msg = viewModel.conflictMessage {
            VStack {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.yellow)
                    Text(msg).font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .padding()
                .background(.thinMaterial)
                .cornerRadius(12)
                .shadow(radius: 6)
                .padding(.top, viewModel.showCompletion ? 84 : 32)
                .padding(.horizontal, 32)
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Header Bar (matches grid width)
    private var headerBar: some View {
        HStack(spacing: 12) {
            if viewModel.showClock {
                // Timer label gets scheme-aware liquid ink (purple in dark / orange in light)
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
        GeometryReader { _ in
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black, lineWidth: isPad ? 10 : 8)

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

    // MARK: - Grid View
    private var gridView: some View {
        let size = viewModel.size
        return GeometryReader { geo in
            let cellSize = min(geo.size.width, geo.size.height) / CGFloat(max(size, 1))
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
                            .overlay(Rectangle().stroke(Color.black.opacity(0.25), lineWidth: 0.6))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Liquid Glass Controls (below grid)
    private var liquidControls: some View {
        let controlHeight: CGFloat = isPad ? 48 : 44

        return HStack(spacing: 14) {
            Button {
                Haptics.soft()
                viewModel.undo()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
                    .font(.system(size: isPad ? 18 : 16, weight: .semibold))
                    .frame(maxWidth: .infinity)              // equal width
            }
            .buttonStyle(LiquidGlassButtonStyle())
            .frame(height: controlHeight)                     // equal height
            .disabled(!viewModel.canUndo)

            Button {
                Haptics.light()
                viewModel.revealHint()
            } label: {
                Label("Hint \(viewModel.hintsUsed)/\(viewModel.maxHints)", systemImage: "lightbulb")
                    .font(.system(size: isPad ? 18 : 16, weight: .semibold))
                    .frame(maxWidth: .infinity)              // equal width
            }
            .buttonStyle(LiquidGlassButtonStyle())
            .frame(height: controlHeight)                     // equal height
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
                    Text("Auto-place crosses will help by marking likely invalid cells automatically (coming soon).")
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
private struct LiquidGlassButtonStyle: ButtonStyle {
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
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .blur(radius: 1.2)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            )
            .shadow(color: .black.opacity(0.18), radius: 6, x: 2, y: 3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            // Use purple in dark mode for ALL text/icons; orange in light.
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
