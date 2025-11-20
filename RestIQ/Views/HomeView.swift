//
//  HomeView.swift
//  RestIQ
//
//  Created by Alfin Baby on 12/10/25.
//  Updated: use AppTheme for background and gradients; all text/icons use purple tint in dark mode, orange in light.
//
import SwiftUI

@available(iOS 18.0, *)
struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @State private var showUserDashboard = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AppBackground()
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
            .toolbar(.hidden, for: .navigationBar)
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
                    .foregroundStyle(AppTheme.liquidInk()) // scheme-aware
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

    // MARK: - Title Section
    private var titleSection: some View {
        VStack(alignment: .center, spacing: 6) {
            Text("RestIQ")
                .font(.system(size: 50, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.titleGradient()) // scheme-aware
                .shadow(color: .white.opacity(0.1), radius: 8, x: 0, y: 2)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 3)


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
                .foregroundStyle(AppTheme.footerTextGradient()) // scheme-aware
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
