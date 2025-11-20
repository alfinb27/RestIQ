//
//  AppTheme.swift
//  RestIQ
//
//  Created by Alfin Baby on 24/10/25.
//  Centralized color & gradient system for RestIQ (light/dark aware).
//

import SwiftUI

/// Global theme namespace for colors, gradients, and reusable styles.
enum AppTheme {

    // MARK: - Base Palette (Display P3-safe)
    private enum Palette {
        // Brand oranges/rose used across the app (light mode)
        static let orangeLight  = Color(.displayP3, red: 0.98, green: 0.65, blue: 0.30)
        static let orange       = Color(.displayP3, red: 0.98, green: 0.50, blue: 0.25)
        static let coral        = Color(.displayP3, red: 0.90, green: 0.35, blue: 0.30)

        // Light title gradient
        static let roseLightA   = Color(.displayP3, red: 1.00, green: 0.70, blue: 0.40)
        static let roseLightB   = Color(.displayP3, red: 0.96, green: 0.30, blue: 0.36)

        // Dark-mode background tints
        static let darkA        = Color(.displayP3, red: 0.22, green: 0.20, blue: 0.28)
        static let darkB        = Color(.displayP3, red: 0.18, green: 0.16, blue: 0.22)
        static let darkC        = Color(.displayP3, red: 0.12, green: 0.10, blue: 0.16)

        // Dark-mode purple/rose for text/accents
        static let purpleA      = Color(.displayP3, red: 0.75, green: 0.55, blue: 0.95)
        static let purpleB      = Color(.displayP3, red: 0.55, green: 0.40, blue: 0.95)

        // Dark title gradient (slightly warmer purple/rose mix)
        static let roseDarkA    = Color(.displayP3, red: 0.95, green: 0.60, blue: 0.50)
        static let roseDarkB    = Color(.displayP3, red: 0.90, green: 0.40, blue: 0.60)

        // Footer gradient for dark (purple family)
        static let footerDarkA  = Color(.displayP3, red: 0.90, green: 0.60, blue: 0.50)
        static let footerDarkB  = Color(.displayP3, red: 0.70, green: 0.40, blue: 0.80)
    }

    /// A helper that resolves a gradient based on the current color scheme.
    /// It conforms to both View and ShapeStyle to be used in any context.
    private struct ThemedGradient: View, ShapeStyle {
        @Environment(\.colorScheme) private var colorScheme
        let light: LinearGradient
        let dark: LinearGradient

        // ShapeStyle conformance
        func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
            if environment.colorScheme == .light {
                return light
            } else {
                return dark
            }
        }
        
        // View conformance
        var body: some View {
            if colorScheme == .light {
                light
            } else {
                dark
            }
        }
    }

    /// The primary brand gradient for light mode, used in multiple places.
    private static let lightBrandGradient = LinearGradient(
        colors: [Palette.roseLightA, Palette.roseLightB],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Backgrounds

    /// App background gradient behind material overlay.
    static func backgroundGradient() -> some View {
        ThemedGradient(
            light: LinearGradient(
                colors: [
                    Palette.orangeLight.opacity(0.55),
                    Palette.orange.opacity(0.60),
                    Palette.coral.opacity(0.55)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            dark: LinearGradient(
                colors: [Palette.darkA, Palette.darkB, Palette.darkC],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
    }

    /// A thin material overlay opacity tuned per scheme for the frosted effect.
    static func backgroundMaterialOpacity(_ scheme: ColorScheme) -> Double {
        scheme == .light ? 0.85 : 0.80
    }

    // MARK: - Title / Headline Gradients

    /// Big “RestIQ” title gradient.
    static func titleGradient() -> some ShapeStyle {
        ThemedGradient(
            light: lightBrandGradient,
            dark: LinearGradient(
                colors: [Palette.roseDarkA, Palette.roseDarkB],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
    }

    /// Footer “Streak” text gradient.
    static func footerTextGradient() -> some ShapeStyle {
        ThemedGradient(
            light: lightBrandGradient,
            dark: LinearGradient(
                colors: [Palette.footerDarkA, Palette.footerDarkB],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
    }

    // MARK: - Liquid Accent (for buttons / icons / labels)

    /// Scheme-aware liquid gradient ink.
    /// - Light mode: orange/rose (brand)
    /// - Dark mode: purple tint (as requested)
    /// - accent: An optional override color for light mode only.
    static func liquidInk(accent: Color? = nil) -> some ShapeStyle {
        let darkGradient = LinearGradient(
            colors: [Palette.purpleA, Palette.purpleB],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        let themed: ThemedGradient
        if let accent {
            themed = ThemedGradient(
                light: LinearGradient(
                    colors: [accent, accent.opacity(0.7)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                dark: darkGradient
            )
        } else {
            themed = ThemedGradient(light: lightBrandGradient, dark: darkGradient)
        }
        return themed
    }
}

// MARK: - Reusable Background View

/// A reusable view that displays the app's standard themed background.
struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient()
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(AppTheme.backgroundMaterialOpacity(colorScheme))
                .blendMode(.overlay)
        }
        .blur(radius: 45)
        .ignoresSafeArea()
    }
}
