//
//  HomeViewModel.swift
//  RestIQ
//
//  Created by Alfin Baby on 12/10/25.
//

import SwiftUI
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    @Published var levels: [String] = ["Easy", "Medium", "Hard", "Expert"]
    @Published var selectedLevel: String = ""
    @Published var navigateToPuzzle: Bool = false
    @Published var streak: Int = 0
    @Published var lastPlayed: Date? = nil

    var lastPlayedDisplay: String {
        guard let date = lastPlayed else { return "Never" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    func selectLevel(_ level: String) {
        if level == "Expert" {
            // Placeholder for future purchase logic
            print("Expert level is locked.")
        } else {
            selectedLevel = level
            navigateToPuzzle = true
            updateStreak()
        }
    }

    private func updateStreak() {
        // Simplified placeholder logic
        streak += 1
        lastPlayed = Date()
    }
}
