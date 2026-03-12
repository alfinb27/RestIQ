//
//  PuzzleCompleteView.swift
//  RestIQ
//
//  Full-screen completion view shown when the puzzle is solved.
//  Presented as a sheet from PuzzleView.
//  Share button captures just the board grid via ImageRenderer.
//

import SwiftUI

// MARK: - Standalone board view used only for the share screenshot

struct BoardSnapshotView: View {
    let board: [[CellState]]
    let regionMap: [[Int]]
    let regionColors: [Int: Color]
    let size: Int

    private let cellSize: CGFloat = 36

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<size, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<size, id: \.self) { c in
                        let rid   = regionMap[r][c]
                        let color = regionColors[rid] ?? Color.gray.opacity(0.3)
                        ZStack {
                            Rectangle().fill(color)
                            switch board[r][c] {
                            case .queen:
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.yellow)
                            case .markedX:
                                Text("×")
                                    .font(.system(size: 20))
                                    .fontWeight(.thin)
                                    .foregroundColor(.black)
                            default:
                                EmptyView()
                            }
                        }
                        .frame(width: cellSize, height: cellSize)
                        .overlay(Rectangle().stroke(Color.black.opacity(0.25), lineWidth: 0.5))
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.black, lineWidth: 6)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Completion View

struct PuzzleCompleteView: View {
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.colorScheme)  private var colorScheme

    let level:          String
    let elapsedSeconds: Int
    let hintsUsed:      Int
    let board:          [[CellState]]
    let regionMap:      [[Int]]
    let regionColors:   [Int: Color]
    let size:           Int

    @State private var isSharing = false

    var body: some View {
        ZStack {
            // Background
            ZStack {
                AppTheme.backgroundGradient(colorScheme)
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(AppTheme.backgroundMaterialOpacity(colorScheme))
                    .blendMode(.overlay)
            }
            .blur(radius: 45)
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {

                    // MARK: Header
                    VStack(spacing: 6) {
                        Text("👑")
                            .font(.system(size: 56))

                        Text("Puzzle Solved!")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.titleGradient(colorScheme))

                        Text(level)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)

                    // MARK: Stats card
                    HStack(spacing: 0) {
                        statCell(
                            icon:  "clock.fill",
                            value: formattedTime,
                            label: "Time"
                        )
                        Divider().frame(height: 48)
                        statCell(
                            icon:  "lightbulb.fill",
                            value: "\(hintsUsed)",
                            label: hintsUsed == 1 ? "Hint used" : "Hints used"
                        )
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                            )
                    )
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)

                    // MARK: Board preview
                    BoardSnapshotView(
                        board: board,
                        regionMap: regionMap,
                        regionColors: regionColors,
                        size: size
                    )
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

                    // MARK: Share button
                    Button {
                        Haptics.medium()
                        shareResults()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Share Result")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: colorScheme == .light
                                            ? [AppTheme.Palette.roseLightA, AppTheme.Palette.roseLightB]
                                            : [AppTheme.Palette.purpleA,    AppTheme.Palette.purpleB],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)

                    // Dismiss — player uses the system back button or this link
                    Button("Back to Levels") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 28)
            }
        }
    }

    // MARK: - Helpers

    private var formattedTime: String {
        String(format: "%d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)
    }

    private func statCell(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(AppTheme.liquidInk(colorScheme))
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    // MARK: - Share

    @MainActor
    private func shareResults() {
        // Render board snapshot to UIImage
        let snapshotView = BoardSnapshotView(
            board: board,
            regionMap: regionMap,
            regionColors: regionColors,
            size: size
        )
        let renderer = ImageRenderer(content: snapshotView)
        renderer.scale = UIScreen.main.scale * 2   // crisp on all device scales

        let timeStr   = formattedTime
        let hintStr: String
        switch hintsUsed {
        case 0: hintStr = "no hints"
        case 1: hintStr = "1 hint"
        default: hintStr = "\(hintsUsed) hints"
        }
        let shareText = "I solved today's \(level) Queens puzzle in \(timeStr) using \(hintStr)! 👑 #RestIQ"

        var items: [Any] = [shareText]
        if let image = renderer.uiImage { items.append(image) }

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }

        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        // On iPad, popover source
        vc.popoverPresentationController?.sourceView = rootVC.view
        rootVC.present(vc, animated: true)
    }
}

#Preview {
    PuzzleCompleteView(
        level:          "Easy",
        elapsedSeconds: 102,
        hintsUsed:      1,
        board:          Array(repeating: Array(repeating: CellState.empty, count: 6), count: 6),
        regionMap:      Array(repeating: Array(repeating: 0, count: 6), count: 6),
        regionColors:   [0: Color.purple.opacity(0.5)],
        size:           6
    )
}
