//
//  DailyChallengeManager.swift
//  RestIQ
//
//  Generates and caches one puzzle per level per day.
//  Level configuration is sourced entirely from PuzzleRegistry —
//  no hardcoded level names or sizes here.
//

import Foundation

@MainActor
final class DailyChallengeManager {
    static let shared = DailyChallengeManager()
    private let calendar = Calendar.current
    private let defaults = UserDefaults.standard

    // In-memory cache keyed by stable level ID (e.g. "queens.Expert")
    private var cachedEngines: [String: PuzzleEngineResult] = [:]
    private var cachedDayKey: String?

    private init() {}

    // MARK: - Day Key

    private func dayKey(for date: Date = Date()) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    // MARK: - Daily Seed

    private func dailySeed(levelID: String) -> UInt64 {
        let key = dayKey() + ":\(levelID)"
        var hash: UInt64 = 0xcbf29ce484222325
        let prime: UInt64 = 0x100000001b3
        for b in key.utf8 { hash ^= UInt64(b); hash = hash &* prime }
        return hash
    }

    // MARK: - Persistence Keys

    // Keyed by stable level ID so adding new puzzle types never collides with existing keys.
    private func persistenceKey(levelID: String, dayKey: String) -> String {
        "puzzle.\(levelID).\(dayKey)"
    }

    // MARK: - Save / Load PuzzleRecord
    //
    // PuzzleRecord is Queens-specific. When future puzzle types ship, each type
    // will need its own Codable record type — DailyChallengeManager will need a
    // small extension at that point to handle the additional record types.

    private func savePuzzle(_ record: PuzzleRecord, levelID: String, dayKey: String) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        defaults.set(data, forKey: persistenceKey(levelID: levelID, dayKey: dayKey))
    }

    private func loadPuzzle(levelID: String, dayKey: String) -> PuzzleRecord? {
        guard let data = defaults.data(forKey: persistenceKey(levelID: levelID, dayKey: dayKey)),
              let record = try? JSONDecoder().decode(PuzzleRecord.self, from: data)
        else { return nil }
        return record
    }

    // MARK: - Pruning

    private func pruneOldRecords() {
        let today     = dayKey()
        let yesterday = dayKey(for: calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        let allIDs    = PuzzleRegistry.shared.allLevels.map { $0.id }

        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("puzzle.") {
            let keep = allIDs.contains(where: { id in
                key == persistenceKey(levelID: id, dayKey: today) ||
                key == persistenceKey(levelID: id, dayKey: yesterday)
            })
            if !keep { defaults.removeObject(forKey: key) }
        }
    }

    // MARK: - Public API
    //
    // Callers pass a LevelConfig from the registry.
    // Returns a PuzzleEngineResult so the caller can switch on the game type.

    func generateDailyPuzzle(for levelConfig: LevelConfig) async -> PuzzleEngineResult? {
        let today = dayKey()
        let debug = DebugConfig.shared.debugMode
        let levelID = levelConfig.id

        // Invalidate in-memory cache on day change
        if cachedDayKey != today && !debug {
            cachedEngines.removeAll()
            cachedDayKey = today
            pruneOldRecords()
        }

        // 1. In-memory cache
        if let existing = cachedEngines[levelID], !debug { return existing }

        // 2. Restore Queens puzzle from disk (Queens-specific restore path)
        if !debug,
           levelConfig.puzzleTypeID == "queens",
           let record = loadPuzzle(levelID: levelID, dayKey: today) {
            let engine = QueensPuzzleEngine.restore(from: record)
            let result = PuzzleEngineResult.queens(engine)
            cachedEngines[levelID] = result
            return result
        }

        // 3. Generate via the registry — no switch needed here
        let seed: UInt64? = debug ? nil : dailySeed(levelID: levelID)
        guard let result = await PuzzleRegistry.shared.makeEngine(
            for: levelConfig,
            seed: seed
        ) else { return nil }

        // 4. Persist Queens puzzles to disk for relaunch restore
        if !debug, case .queens(let engine) = result {
            let record = await engine.record()
            savePuzzle(record, levelID: levelID, dayKey: today)
        }

        cachedEngines[levelID] = result
        return result
    }

    // MARK: - Legacy String-Based Accessor
    //
    // Keeps PuzzleViewModel and RestIQApp working without changes for now.
    // This shim looks up the LevelConfig by display name from the Queens puzzle type.
    // Once PuzzleViewModel is updated to work with LevelConfig directly, remove this.

    func generateDailyPuzzle(for levelName: String) async -> QueensPuzzleEngine? {
        let levelID = "queens.\(levelName)"
        guard let config = PuzzleRegistry.shared.level(id: levelID) else { return nil }
        guard let result = await generateDailyPuzzle(for: config) else { return nil }
        if case .queens(let engine) = result { return engine }
        return nil
    }
}
