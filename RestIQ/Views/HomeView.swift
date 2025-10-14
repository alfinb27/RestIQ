//
//  HomeView.swift
//  RestIQ
//
//  Created by Alfin Baby on 12/10/25.
//  Updated: Liquid Glass unified with PuzzleView style (iOS 18+)
//

import SwiftUI

@available(iOS 18.0, *)
struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var motion = ParallaxMotion.shared

    private var warmGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(.displayP3, red: 1.00, green: 0.74, blue: 0.40).opacity(colorScheme == .dark ? 0.18 : 0.35),
                Color(.displayP3, red: 1.00, green: 0.56, blue: 0.36).opacity(colorScheme == .dark ? 0.18 : 0.42),
                Color(.displayP3, red: 0.96, green: 0.28, blue: 0.36).opacity(colorScheme == .dark ? 0.16 : 0.44)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                warmGradient
                    .ignoresSafeArea()
                    .blur(radius: 40)
                    .overlay(Rectangle().fill(.ultraThinMaterial).ignoresSafeArea())

                VStack(spacing: 8) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 8) {
                            titleSection
                                .padding(.top, 10)
                                .padding(.bottom, 4)
                            levelStack
                        }
                        .padding(.horizontal, 20)
                    }

                    footerSection           // pinned
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .task { motion.start() }
            .onDisappear { motion.stop() }
        }
    }

    // MARK: - Title Section
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                // Gentle blurred light glow behind text
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.05 : 0.15),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blur(radius: 12)
                .offset(y: 2)

                // App Title
                Text("RestIQ")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(.displayP3, red: 1.0, green: 0.7, blue: 0.4),
                                Color(.displayP3, red: 0.96, green: 0.3, blue: 0.36)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12),
                            radius: 8, x: 0, y: 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 2)

            Text("Daily puzzles to refresh your mind")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.leading, 2)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Levels List
    private var levelStack: some View {
        VStack(spacing: 16) {
            ForEach(viewModel.levels, id: \.self) { level in
                NavigationLink(value: level) {
                    LevelCardLiquid(level: level, isLocked: level == "Expert")
                        .rotation3DEffect(.degrees(motion.x * 2), axis: (x: 0, y: 1, z: 0))
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded {
                    if level != "Expert" {
                        viewModel.selectLevel(level)
                    } else {
                        Haptics.soft()
                    }
                })
            }
        }
        .navigationDestination(for: String.self) { level in
            PuzzleView(level: level)
        }
        .padding(.vertical, 10)
    }

    // MARK: - Footer (Glass Pane)
    private var footerSection: some View {
        VStack(spacing: 6) {
            Text("Streak: \(viewModel.streak) days")
                .font(.footnote)
                .foregroundColor(.secondary)
            Text("Last Played: \(viewModel.lastPlayedDisplay)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.08), radius: 8, x: 0, y: 6)
    }
}

// MARK: - Level Card
@available(iOS 18.0, *)
private struct LevelCardLiquid: View {
    let level: String
    let isLocked: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var subtitle: String {
        isLocked ? "Unlock to play Expert mode" : "Play now"
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.regularMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.6)
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.1), radius: 8, x: 0, y: 4)

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(level)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if isLocked {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                        .padding(.trailing, 16)
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundStyle(
                            Color(.displayP3, red: 1.00, green: 0.64, blue: 0.40),
                            Color(.displayP3, red: 0.96, green: 0.28, blue: 0.36)
                        )
                        .font(.title2)
                        .padding(.trailing, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .frame(height: 84)
    }
}

// MARK: - Haptics
private enum Haptics {
    static func soft() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
    }
}

// MARK: - Preview
@available(iOS 18.0, *)
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            HomeView().preferredColorScheme(.light)
            HomeView().preferredColorScheme(.dark)
        }
    }
}
