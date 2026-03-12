//
//  HomeView.swift
//  RestIQ
//
//  Updated: Expert lock driven by UserStatsManager, real streak display,
//  completed-today indicator on level cards, paywall sheet for Expert.
//

import SwiftUI

@available(iOS 18.0, *)
struct HomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var vm = HomeViewModel()
    @State private var showUserDashboard = false
    @State private var showExpertPaywall = false

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
            .sheet(isPresented: $showExpertPaywall) {
                ExpertPaywallView()
                    .presentationDetents([.large])
                    .presentationCornerRadius(24)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .task {
                // Restore purchases silently on launch
                await PurchaseManager.shared.checkCurrentEntitlements()
            }
        }
    }

    // MARK: - Header Bar

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
                    .foregroundStyle(AppTheme.liquidInk(colorScheme))
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
            AppTheme.backgroundGradient(colorScheme)
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(AppTheme.backgroundMaterialOpacity(colorScheme))
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
                .foregroundStyle(AppTheme.titleGradient(colorScheme))
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
            ForEach(vm.levels) { level in
                levelCard(for: level)
            }
        }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func levelCard(for level: LevelConfig) -> some View {
        let isLocked       = level.requiresPurchase && !vm.isExpertUnlocked
        let completedToday = vm.hasCompletedToday(level.id)
        let todayTime      = vm.todayTime(for: level.id)

        if isLocked {
            Button {
                Haptics.soft()
                showExpertPaywall = true
            } label: {
                LevelCardLiquid(
                    level: level.displayName,
                    isLocked: true,
                    completedToday: false,
                    todayTime: nil
                )
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(destination: PuzzleView(level: level.displayName)) {
                LevelCardLiquid(
                    level: level.displayName,
                    isLocked: false,
                    completedToday: completedToday,
                    todayTime: todayTime
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        VStack(spacing: 6) {
            Text(vm.streak > 0 ? "🔥 \(vm.streak) day streak" : "Start your streak today")
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.footerTextGradient(colorScheme))
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
