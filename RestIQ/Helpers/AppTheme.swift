//
//  AppTheme.swift
//  RestIQ
//
//  Centralized color & gradient system for RestIQ (light/dark aware).
//

import SwiftUI

enum AppTheme {

    // MARK: - Base Palette

    enum Palette {
        static let orangeLight  = Color(.displayP3, red: 0.98, green: 0.65, blue: 0.30)
        static let orange       = Color(.displayP3, red: 0.98, green: 0.50, blue: 0.25)
        static let coral        = Color(.displayP3, red: 0.90, green: 0.35, blue: 0.30)

        static let roseLightA   = Color(.displayP3, red: 1.00, green: 0.70, blue: 0.40)
        static let roseLightB   = Color(.displayP3, red: 0.96, green: 0.30, blue: 0.36)

        static let darkA        = Color(.displayP3, red: 0.22, green: 0.20, blue: 0.28)
        static let darkB        = Color(.displayP3, red: 0.18, green: 0.16, blue: 0.22)
        static let darkC        = Color(.displayP3, red: 0.12, green: 0.10, blue: 0.16)

        static let purpleA      = Color(.displayP3, red: 0.75, green: 0.55, blue: 0.95)
        static let purpleB      = Color(.displayP3, red: 0.55, green: 0.40, blue: 0.95)

        static let roseDarkA    = Color(.displayP3, red: 0.95, green: 0.60, blue: 0.50)
        static let roseDarkB    = Color(.displayP3, red: 0.90, green: 0.40, blue: 0.60)

        static let footerDarkA  = Color(.displayP3, red: 0.90, green: 0.60, blue: 0.50)
        static let footerDarkB  = Color(.displayP3, red: 0.70, green: 0.40, blue: 0.80)
    }

    // MARK: - Backgrounds

    static func backgroundGradient(_ scheme: ColorScheme) -> LinearGradient {
        if scheme == .light {
            return LinearGradient(
                colors: [
                    Palette.orangeLight.opacity(0.55),
                    Palette.orange.opacity(0.60),
                    Palette.coral.opacity(0.55)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Palette.darkA, Palette.darkB, Palette.darkC],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    static func backgroundMaterialOpacity(_ scheme: ColorScheme) -> Double {
        scheme == .light ? 0.85 : 0.80
    }

    // MARK: - Title / Headline Gradients

    static func titleGradient(_ scheme: ColorScheme) -> LinearGradient {
        if scheme == .light {
            return LinearGradient(
                colors: [Palette.roseLightA, Palette.roseLightB],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Palette.roseDarkA, Palette.roseDarkB],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    static func footerTextGradient(_ scheme: ColorScheme) -> LinearGradient {
        if scheme == .light {
            return LinearGradient(
                colors: [Palette.roseLightA, Palette.roseLightB],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Palette.footerDarkA, Palette.footerDarkB],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Liquid Accent
    //
    // Single function replacing the previous two overloads.
    // Pass `accent` to override light-mode color; omit it (nil) for the default brand gradient.
    // Dark mode always uses purple regardless of accent.

    static func liquidInk(_ scheme: ColorScheme, accent: Color? = nil) -> LinearGradient {
        if scheme == .dark {
            return LinearGradient(
                colors: [Palette.purpleA, Palette.purpleB],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        if let accent {
            return LinearGradient(
                colors: [accent, accent.opacity(0.7)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [Palette.roseLightA, Palette.roseLightB],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}

// MARK: - Convenience Extensions

extension View {
    func appBackground(_ scheme: ColorScheme) -> some View {
        ZStack {
            AppTheme.backgroundGradient(scheme)
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(AppTheme.backgroundMaterialOpacity(scheme))
                .blendMode(.overlay)
        }
        .blur(radius: 45)
        .ignoresSafeArea()
    }
}
