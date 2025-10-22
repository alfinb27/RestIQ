//
//  HomeViewModel.swift
//  RestIQ
//
//  Created by Alfin Baby on 12/10/25.
//  VM for HomeView. Keeps simple navigation state and streaks.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var levels: [String] = ["Easy", "Medium", "Hard", "Expert"]
    @Published var selectedLevel: String?
    @Published var streak: Int = 0
    @Published var lastPlayed: Date? = nil

    var lastPlayedDisplay: String {
        guard let date = lastPlayed else { return "Never" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    func selectLevel(_ level: String) {
        selectedLevel = level
        updateStreak()
    }

    private func updateStreak() {
        // Simplified streak update for now.
        streak += 1
        lastPlayed = Date()
    }
}
