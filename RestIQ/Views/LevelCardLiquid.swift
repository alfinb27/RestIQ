//
//  LevelCardLiquid.swift
//  RestIQ
//
//  Updated: shows completed-today checkmark and time, locked state for Expert.
//

import SwiftUI

@available(iOS 18.0, *)
struct LevelCardLiquid: View {
    let level: String
    let isLocked: Bool
    let completedToday: Bool
    let todayTime: String?

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
                    LinearGradient(
                        colors: [Color.white.opacity(0.25), Color.clear],
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
                VStack(alignment: .leading, spacing: 5) {
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

                    subtitleText
                }

                Spacer()

                trailingIcon
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .frame(height: 84)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
        )
        .compositingGroup()
        .opacity(completedToday ? 0.7 : 1.0)
    }

    // MARK: - Subtitle

    @ViewBuilder
    private var subtitleText: some View {
        if isLocked {
            Text("Unlock to play Expert mode")
                .font(.caption)
                .foregroundColor(.secondary)
        } else if completedToday, let time = todayTime {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                Text("Done · \(time)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } else {
            Text("Play now")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Trailing Icon

    @ViewBuilder
    private var trailingIcon: some View {
        if isLocked {
            Image(systemName: "lock.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
                .padding(.trailing, 10)
        } else if completedToday {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(.green)
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
}

struct LevelCardLiquid_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            LevelCardLiquid(level: "Easy", isLocked: false, completedToday: false, todayTime: nil)
            LevelCardLiquid(level: "Medium", isLocked: false, completedToday: true, todayTime: "2:34")
            LevelCardLiquid(level: "Expert", isLocked: true, completedToday: false, todayTime: nil)
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
