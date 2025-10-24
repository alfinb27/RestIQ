//
//  UserDashboardView.swift
//  RestIQ
//
//  Created by Alfin Baby on 17/10/25.
//  Updated: Added Debug Mode toggle to regenerate puzzles anytime.
//

import SwiftUI

@available(iOS 18.0, *)
struct UserDashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var debugConfig = DebugConfig.shared

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                adaptiveBackground

                VStack(spacing: 30) {
                    headerBar
                        .padding(.top, 18)
                        .padding(.horizontal, 20)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            profileSection
                            dashboardOptions
                            debugSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
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

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack {
            Spacer()

            Text("Account")
                .font(.system(size: 30, weight: .bold, design: .rounded))
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
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer()

            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 46, height: 46)
                        .shadow(color: .black.opacity(0.25), radius: 6, x: 2, y: 3)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                    Image(systemName: "xmark")
                        .font(.system(size: 28, weight: .medium))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(
                            LinearGradient(
                                colors: colorScheme == .light
                                ? [
                                    Color(.displayP3, red: 0.96, green: 0.3, blue: 0.36),
                                    Color(.displayP3, red: 0.98, green: 0.5, blue: 0.25)
                                ]
                                : [
                                    Color(.displayP3, red: 0.9, green: 0.5, blue: 0.7),
                                    Color(.displayP3, red: 0.7, green: 0.4, blue: 0.9)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Profile Section
    private var profileSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 60, height: 60)
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 1, y: 2)
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .foregroundStyle(
                        LinearGradient(
                            colors: colorScheme == .light
                            ? [
                                Color(.displayP3, red: 0.96, green: 0.3, blue: 0.36),
                                Color(.displayP3, red: 0.98, green: 0.5, blue: 0.25)
                            ]
                            : [
                                Color(.displayP3, red: 0.9, green: 0.5, blue: 0.7),
                                Color(.displayP3, red: 0.7, green: 0.4, blue: 0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Alfin Baby")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("alfinb27@gmail.com")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.25), radius: 6, x: 2, y: 3)
        .padding(.top, 10)
    }

    // MARK: - Dashboard Options
    private var dashboardOptions: some View {
        VStack(spacing: 14) {
            dashboardRow(title: "Notifications", icon: "bell.badge.fill")
            dashboardRow(title: "Subscriptions", icon: "creditcard.fill")
            dashboardRow(title: "Settings", icon: "gearshape.fill")
        }
    }

    private func dashboardRow(title: String, icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.25), radius: 6, x: 2, y: 3)
    }

    // MARK: - Debug Section
    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Enable Debug Mode", isOn: $debugConfig.debugMode)
                .tint(.orange)
            Text("When enabled, daily puzzles regenerate each time you open them.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.25), radius: 6, x: 2, y: 3)
    }
}

#Preview {
    UserDashboardView()
}
