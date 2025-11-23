//
// UIUtilities.swift
// RestIQ
//
// Common UI utilities and shared button style used across the app.
// Place this file in your app target (remove duplicates if you already have similar types).
//

import SwiftUI

// MARK: - LiquidGlassButtonStyle
// Matches the look used across the project; supports optional accent color.
public struct LiquidGlassButtonStyle: ButtonStyle {
    public var accent: Color? = nil

    public init(accent: Color? = nil) {
        self.accent = accent
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                // frosted glass base
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.98)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.45), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            .overlay(
                // subtle sheen
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
            .foregroundStyle(accent == nil ? AppTheme.liquidInk() : AppTheme.liquidInk(accent: accent))
    }
}

// MARK: - Small helper view for consistent pill-like buttons
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

// MARK: - Small common modifiers/extensions

public extension View {
    /// Apply a subtle rounded glass card look used across the app.
    func glassCard(cornerRadius: CGFloat = 18, shadowRadius: CGFloat = 6) -> some View {
        self
            .padding()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
            )
            .shadow(color: Color.black.opacity(0.25), radius: shadowRadius, x: 2, y: 3)
    }
}

// MARK: - Preview (quick visual check)
#if DEBUG
struct UIUtilities_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            LiquidPillButton(accent: nil, action: {}) {
                Label("Default", systemImage: "arrow.uturn.backward")
                    .font(.system(size: 16, weight: .semibold))
            }

            LiquidPillButton(accent: .orange, action: {}) {
                Label("Accent", systemImage: "lightbulb")
                    .font(.system(size: 16, weight: .semibold))
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [
                    Color(.displayP3, red: 1.00, green: 0.75, blue: 0.45).opacity(0.35),
                    Color(.displayP3, red: 0.96, green: 0.3, blue: 0.36).opacity(0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .previewLayout(.sizeThatFits)
    }
}
#endif
