//
//  LevelCardLiquid.swift
//  RestIQ
//
//  Created by Alfin Baby on 16/10/25.
//  Updated: True Liquid Glass visual with depth, refraction and shimmer (static)
//

import SwiftUI

@available(iOS 18.0, *)
struct LevelCardLiquid: View {
    let level: String
    let isLocked: Bool

    var body: some View {
        ZStack {
            // MARK: - Glass Base
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.20),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(.displayP3, red: 1.00, green: 0.75, blue: 0.45).opacity(0.10),
                                    Color(.displayP3, red: 0.96, green: 0.28, blue: 0.36).opacity(0.10)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    // Inner shimmer highlight
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.45),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.9
                        )
                )
                .shadow(color: .white.opacity(0.10), radius: 2, x: -1, y: -1)
                .shadow(color: .black.opacity(0.15), radius: 6, x: 2, y: 2)
                .overlay(
                    // Static light sheen to simulate liquid reflection
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.25),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .blur(radius: 1.8)
                    .mask(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(LinearGradient(
                                colors: [Color.white.opacity(0.9), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    )
                )

            // MARK: - Card Content
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(level)
                        .font(.title3.weight(.semibold))
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

                    Text(isLocked ? "Unlock to play Expert mode" : "Play now")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 10)
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(.displayP3, red: 1.00, green: 0.64, blue: 0.40),
                                    Color(.displayP3, red: 0.96, green: 0.28, blue: 0.36)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.trailing, 10)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .frame(height: 84)
        .background(
            // Subtle back blur for frosted glass illusion
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
        )
        .compositingGroup()
    }
}

struct LevelCardLiquid_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            LevelCardLiquid(level: "Beginner", isLocked: false)
            LevelCardLiquid(level: "Expert", isLocked: true)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [
                    Color(.displayP3, red: 1.00, green: 0.75, blue: 0.40).opacity(0.35),
                    Color(.displayP3, red: 0.96, green: 0.3, blue: 0.36).opacity(0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}
