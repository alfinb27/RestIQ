//
//  HomeViewModel.swift
//  RestIQ
//
//  Reads streak and last-played data from UserStatsManager.
//  No longer tracks state in-memory — UserStatsManager is the source of truth.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    let levels: [String] = ["Easy", "Medium", "Hard", "Expert"]

    private let stats = UserStatsManager.shared
    private var cancellables = Set<AnyCancellable>()

    // Forward UserStatsManager published values so views can bind directly to this VM
    @Published var streak: Int = 0
    @Published var lastCompletedDate: Date? = nil
    @Published var isExpertUnlocked: Bool = false

    init() {
        // Sync initial values
        streak = stats.streak
        lastCompletedDate = stats.lastCompletedDate
        isExpertUnlocked = stats.isExpertUnlocked

        // Keep in sync as stats change
        stats.$streak
            .receive(on: RunLoop.main)
            .assign(to: &$streak)

        stats.$lastCompletedDate
            .receive(on: RunLoop.main)
            .assign(to: &$lastCompletedDate)

        stats.$isExpertUnlocked
            .receive(on: RunLoop.main)
            .assign(to: &$isExpertUnlocked)
    }

    var lastPlayedDisplay: String {
        guard let date = lastCompletedDate else { return "Never" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    /// True if the given level has already been completed today.
    func hasCompletedToday(_ level: String) -> Bool {
        stats.hasCompletedToday(level: level)
    }

    /// Best time for a level today, formatted as m:ss. Nil if not completed today.
    func todayTime(for level: String) -> String? {
        guard let record = stats.completion(for: level) else { return nil }
        let m = record.elapsedSeconds / 60
        let s = record.elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
