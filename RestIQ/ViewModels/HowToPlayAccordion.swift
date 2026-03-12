//
//  HowToPlayAccordion.swift
//  RestIQ
//

import SwiftUI

struct HowToPlayAccordion: View {
    let activeHint: HintState?
    let onShowMe: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded    = false
    @State private var manuallyOpened = false

    var body: some View {
        VStack(spacing: 0) {
            header
            if isExpanded {
                content
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)
        .animation(.easeInOut(duration: 0.25), value: isExpanded)
        .onChange(of: activeHint) { _, hint in
            if hint != nil {
                if !isExpanded { isExpanded = true; manuallyOpened = false }
            } else {
                if !manuallyOpened { isExpanded = false }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                isExpanded.toggle()
                manuallyOpened = isExpanded
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.liquidInk(colorScheme))

                VStack(alignment: .leading, spacing: 2) {
                    Text("How To Play")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    Capsule()
                        .fill(AppTheme.liquidInk(colorScheme).opacity(isExpanded ? 0.25 : 0.55))
                        .frame(height: 1.5)
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let hint = activeHint {
                hintBanner(hint)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
            }

            Divider().padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 10) {
                ruleRow(icon: "crown.fill",   text: "Place exactly one crown per row, column, and colour region.")
                ruleRow(icon: "xmark.circle", text: "Crowns cannot touch each other — not even diagonally.")
                ruleRow(icon: "hand.tap",     text: "Tap once to mark ✕, tap again to place a crown 👑, tap again to clear.")
            }
            .padding(16)
        }
    }

    // MARK: - Hint Banner

    private func hintBanner(_ hint: HintState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Icon + message row
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: hint.bannerIcon)
                    .font(.system(size: 14))
                    .foregroundColor(bannerAccent(hint))
                    .padding(.top, 1)

                Text(hint.message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Show me button — hidden for noHint since there's nothing to apply
            if case .noHint = hint.mode { } else {
                Button {
                    Haptics.medium()
                    onShowMe()
                } label: {
                    Text("Show me")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(bannerAccent(hint))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(bannerAccent(hint).opacity(0.12))
                                .overlay(
                                    Capsule()
                                        .stroke(bannerAccent(hint).opacity(0.3), lineWidth: 0.8)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(bannerAccent(hint).opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(bannerAccent(hint).opacity(0.22), lineWidth: 0.8)
                )
        )
    }

    private func bannerAccent(_ hint: HintState) -> Color {
        switch hint.mode {
        case .wrongMark:       return .red
        case .forcedPlacement: return .orange
        case .elimination:     return .teal
        case .noHint:          return Color.secondary
        }
    }

    // MARK: - Rule Row

    private func ruleRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.liquidInk(colorScheme))
                .frame(width: 20)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
