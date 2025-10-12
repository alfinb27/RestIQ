//
//  HomeView.swift
//  RestIQ
//
//  Created by Alfin Baby on 12/10/25.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("RestIQ")
                    .font(.largeTitle.bold())
                    .padding(.top, 40)

                Text("Daily Puzzles to Refresh Your Mind")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                VStack(spacing: 16) {
                    ForEach(viewModel.levels, id: \.self) { level in
                        LevelCard(level: level, isLocked: level == "Expert")
                            .onTapGesture {
                                viewModel.selectLevel(level)
                            }
                    }
                }
                .padding(.top, 40)

                Spacer()

                VStack(spacing: 8) {
                    Text("Streak: \(viewModel.streak) days")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text("Last Played: \(viewModel.lastPlayedDisplay)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 20)
            }
            .padding()
            .navigationDestination(isPresented: $viewModel.navigateToPuzzle) {
                PuzzleView(level: viewModel.selectedLevel)
            }
        }
    }
}

struct LevelCard: View {
    let level: String
    let isLocked: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(isLocked ? Color.gray.opacity(0.2) : Color.blue.opacity(0.2))
                .frame(height: 80)

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(level)
                        .font(.title3.bold())
                    Text(isLocked ? "Unlock to play Expert mode" : "Play now")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if isLocked {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.gray)
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}
