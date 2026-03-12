//
//  UIUtilities.swift
//  RestIQ
//
//  Shared button styles and small UI helpers.
//

import SwiftUI

// MARK: - Liquid Glass Button Style

public struct LiquidGlassButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    var accent: Color? = nil

    public init(accent: Color? = nil) {
        self.accent = accent
    }

    public func makeBody(configuration: Configuration) -> some View {
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
                    colors: [Color.white.opacity(0.22), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blur(radius: 1.2)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            )
            .shadow(color: Color.black.opacity(0.18), radius: 6, x: 2, y: 3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .foregroundStyle(AppTheme.liquidInk(colorScheme, accent: accent))
    }
}

// MARK: - Liquid Pill Button

public struct LiquidPillButton<Label: View>: View {
    let action: () -> Void
    let accent: Color?
    let label: () -> Label

    public init(accent: Color? = nil, action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.accent = accent
        self.label = label
    }

    public var body: some View {
        Button(action: action) {
            label()
        }
        .buttonStyle(LiquidGlassButtonStyle(accent: accent))
    }
}
