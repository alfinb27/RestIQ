//
//  HomeView.swift
//  RestIQ
//
//  Created by Alfin Baby on 12/10/25.
//  Updated: minor tidy; profile button haptic.
//

import SwiftUI

@available(iOS 18.0, *)
struct HomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var vm = HomeViewModel()
    @State private var showUserDashboard = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                adaptiveBackground
                    .allowsHitTesting(false)

                VStack(spacing: 8) {
                    headerBar
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 8) {
                            titleSection
                                .padding(.top, 4)
                                .padding(.bottom, 4)
                            levelStack
                        }
                        .padding(.horizontal, 20)
                    }

                    footerSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                }
            }
            .sheet(isPresented: $showUserDashboard) {
                UserDashboardView()
                    .presentationDetents([.large])
                    .presentationCornerRadius(24)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }

    // MARK: - Top Right Profile Button
    private var headerBar: some View {
        HStack {
            Spacer()
            Button {
                Haptics.soft()
                showUserDashboard = true
            } label: {
                Image(systemName: "person")
                    .font(.system(size: 30))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(
                        colorScheme == .light
                        ? Color(.displayP3, red: 0.96, green: 0.3, blue: 0.36)
                        : Color(.displayP3, red: 0.9, green: 0.6, blue: 0.9)
                    )
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 42, height: 42)
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 1, y: 2)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Adaptive Background
    private var adaptiveBackground: some View {
        ZStack {
            if colorScheme == .light {
                LinearGradient(
                    colors: [
                        Color(.displayP3, red: 0.98, green: 0.65, blue: 0.30).opacity(0.55),
                        Color(.displayP3, red: 0.98, green: 0.50, blue: 0.25).opacity(0.60),
                        Color(.displayP3, red: 0.90, green: 0.35, blue: 0.30).opacity(0.55)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(.displayP3, red: 0.22, green: 0.20, blue: 0.28),
                        Color(.displayP3, red: 0.18, green: 0.16, blue: 0.22),
                        Color(.displayP3, red: 0.12, green: 0.10, blue: 0.16)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(colorScheme == .light ? 0.85 : 0.8)
                .blendMode(.overlay)
        }
        .blur(radius: 45)
        .ignoresSafeArea()
    }

    // MARK: - Title Section
    private var titleSection: some View {
        VStack(alignment: .center, spacing: 6) {
            Text("RestIQ")
                .font(.system(size: 50, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(
                    LinearGradient(
                        colors: colorScheme == .light
                        ? [
                            Color(.displayP3, red: 1.0, green: 0.7, blue: 0.4),
                            Color(.displayP3, red: 0.96, green: 0.3, blue: 0.36)
                        ]
                        : [
                            Color(.displayP3, red: 0.95, green: 0.6, blue: 0.5),
                            Color(.displayP3, red: 0.9, green: 0.4, blue: 0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .white.opacity(colorScheme == .light ? 0.25 : 0.1), radius: 8, x: 0, y: 2)
                .shadow(color: .black.opacity(colorScheme == .light ? 0.15 : 0.5), radius: 4, x: 0, y: 3)

            Text("Daily puzzles to refresh your mind")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    // MARK: - Level Stack
    private var levelStack: some View {
        VStack(spacing: 16) {
            ForEach(vm.levels, id: \.self) { level in
                NavigationLink(destination: PuzzleView(level: level)) {
                    LevelCardLiquid(level: level, isLocked: false)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(spacing: 6) {
            Text("Streak: \(vm.streak) days")
                .font(.footnote.weight(.medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: colorScheme == .light
                        ? [
                            Color(.displayP3, red: 1.0, green: 0.7, blue: 0.4),
                            Color(.displayP3, red: 0.96, green: 0.3, blue: 0.36)
                        ]
                        : [
                            Color(.displayP3, red: 0.9, green: 0.6, blue: 0.5),
                            Color(.displayP3, red: 0.7, green: 0.4, blue: 0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("Last Played: \(vm.lastPlayedDisplay)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.25), radius: 8, x: 2, y: 3)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            HomeView().preferredColorScheme(.light)
            HomeView().preferredColorScheme(.dark)
        }
    }
}
