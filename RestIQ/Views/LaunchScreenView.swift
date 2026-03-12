//
//  LaunchScreenView.swift
//  RestIQ
//

import SwiftUI

struct LaunchScreenView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 12) {
                // Both lines visible from frame 1 — no animation gates
                Text("RestIQ")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(titleColor)
                    .shadow(color: shadowColor, radius: 10, x: 0, y: 4)

                Text("Daily puzzles to refresh your mind")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(subtitleColor)
            }
        }
    }

    // MARK: - Adaptive Colours

    private var backgroundGradient: LinearGradient {
        colorScheme == .dark
            ? LinearGradient(
                colors: [
                    Color(.displayP3, red: 0.22, green: 0.20, blue: 0.28),
                    Color(.displayP3, red: 0.18, green: 0.16, blue: 0.22),
                    Color(.displayP3, red: 0.12, green: 0.10, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            : LinearGradient(
                colors: [
                    Color(.displayP3, red: 1.00, green: 0.74, blue: 0.40),
                    Color(.displayP3, red: 1.00, green: 0.56, blue: 0.36),
                    Color(.displayP3, red: 0.96, green: 0.28, blue: 0.36)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
    }

    // Light: white reads well on the warm orange gradient
    // Dark: purple gradient matches AppTheme.liquidInk used on all other headings
    private var titleColor: AnyShapeStyle {
        colorScheme == .dark
            ? AnyShapeStyle(LinearGradient(
                colors: [
                    Color(.displayP3, red: 0.75, green: 0.55, blue: 0.95),
                    Color(.displayP3, red: 0.55, green: 0.40, blue: 0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            : AnyShapeStyle(Color.white)
    }

    private var subtitleColor: AnyShapeStyle {
        colorScheme == .dark
            ? AnyShapeStyle(Color.white.opacity(0.55))
            : AnyShapeStyle(Color.white.opacity(0.85))
    }

    private var shadowColor: Color {
        colorScheme == .dark ? .black.opacity(0.5) : .black.opacity(0.2)
    }
}

#Preview("Light") { LaunchScreenView().preferredColorScheme(.light) }
#Preview("Dark")  { LaunchScreenView().preferredColorScheme(.dark)  }
