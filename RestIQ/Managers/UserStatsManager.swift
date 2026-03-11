//
//  UserStatsManager.swift
//  RestIQ
//
//  Persistent storage for streak, per-level completion history, and IAP unlock state.
//  All data is stored in UserDefaults locally. iCloud (CloudKit) sync layers on top later
//  without changing this interface — just swap the read/write calls.
//
//  Android mirror: identical schema in Firebase Firestore under users/{uid}/stats
//

import Foundation
import Combine

// MARK: - Data Models

struct LevelCompletion: Codable {
    let level: String
    let dateKey: String       // "YYYYMMDD"
    let elapsedSeconds: Int
    let hintsUsed: Int
    let completedAt: Date
}

// MARK: - UserStatsManager

@MainActor
final class UserStatsManager: ObservableObject {
    static let shared = UserStatsManager()

    // Published so views can react
    @Published private(set) var streak: Int = 0
    @Published private(set) var lastCompletedDate: Date? = nil
    @Published private(set) var isExpertUnlocked: Bool = false
    @Published private(set) var completionHistory: [LevelCompletion] = []

    private let defaults = UserDefaults.standard
    private let calendar = Calendar.current

    // UserDefaults keys
    private enum Key {
        static let streak = "stats.streak"
        static let lastCompletedDate = "stats.lastCompletedDate"
        static let isExpertUnlocked = "stats.isExpertUnlocked"
        static let completionHistory = "stats.completionHistory"
    }

    private init() {
        load()
        validateStreak()
    }

    // MARK: - Public Interface

    /// Returns true if the given level has already been completed today.
    func hasCompletedToday(level: String) -> Bool {
        let today = dayKey()
        return completionHistory.contains { $0.level == level && $0.dateKey == today }
    }

    /// Call this when a puzzle is solved. Updates streak and saves the completion record.
    func recordCompletion(level: String, elapsedSeconds: Int, hintsUsed: Int) {
        let today = dayKey()

        // Don't double-record the same level on the same day
        guard !hasCompletedToday(level: level) else { return }

        let record = LevelCompletion(
            level: level,
            dateKey: today,
            elapsedSeconds: elapsedSeconds,
            hintsUsed: hintsUsed,
            completedAt: Date()
        )
        completionHistory.append(record)
        saveCompletionHistory()

        updateStreak()
    }

    /// Returns completion record for a level on a given day key, or nil if not completed.
    func completion(for level: String, on dateKey: String? = nil) -> LevelCompletion? {
        let key = dateKey ?? self.dayKey()
        return completionHistory.first { $0.level == level && $0.dateKey == key }
    }

    /// Unlocks Expert. Call this after a successful IAP transaction.
    func unlockExpert() {
        isExpertUnlocked = true
        defaults.set(true, forKey: Key.isExpertUnlocked)
    }

    /// Call on app launch after restoring purchases to re-apply unlock.
    func restoreExpertUnlock() {
        unlockExpert()
    }

    // MARK: - Streak Logic

    private func updateStreak() {
        let today = dayKey()

        if let last = lastCompletedDate {
            let lastKey = dayKeyFor(last)
            let yesterday = dayKeyFor(calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date())

            if lastKey == today {
                // Already incremented today — no change
                return
            } else if lastKey == yesterday {
                // Completed yesterday → extend streak
                streak += 1
            } else {
                // Gap in days → reset streak
                streak = 1
            }
        } else {
            // First ever completion
            streak = 1
        }

        lastCompletedDate = Date()
        defaults.set(streak, forKey: Key.streak)
        defaults.set(lastCompletedDate, forKey: Key.lastCompletedDate)
    }

    /// On launch, check if the streak has been broken (no completion yesterday or today).
    private func validateStreak() {
        guard let last = lastCompletedDate else { return }
        let lastKey = dayKeyFor(last)
        let today = dayKey()
        let yesterday = dayKeyFor(calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date())

        if lastKey != today && lastKey != yesterday {
            // Streak broken — reset without touching history
            streak = 0
            defaults.set(0, forKey: Key.streak)
        }
    }

    // MARK: - Persistence

    private func load() {
        streak = defaults.integer(forKey: Key.streak)
        lastCompletedDate = defaults.object(forKey: Key.lastCompletedDate) as? Date
        isExpertUnlocked = defaults.bool(forKey: Key.isExpertUnlocked)

        if let data = defaults.data(forKey: Key.completionHistory),
           let decoded = try? JSONDecoder().decode([LevelCompletion].self, from: data) {
            completionHistory = decoded
        }
    }

    private func saveCompletionHistory() {
        if let data = try? JSONEncoder().encode(completionHistory) {
            defaults.set(data, forKey: Key.completionHistory)
        }
    }

    // MARK: - Helpers

    func dayKey(for date: Date = Date()) -> String {
        dayKeyFor(date)
    }

    private func dayKeyFor(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }
}
