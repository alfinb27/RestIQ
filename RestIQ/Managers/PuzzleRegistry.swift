//
//  PuzzleRegistry.swift
//  RestIQ
//
//  Single source of truth for all puzzle types in the app.
//
//  Adding a new game:
//    1. Create a new struct conforming to PuzzleTypeDescriptor
//    2. Add one line to PuzzleRegistry.register() at the bottom of this file
//    3. Done — DailyChallengeManager, HomeViewModel, and HomeView all pick it up automatically
//
//  Nothing else needs to change.
//

import Foundation

// MARK: - Level Configuration

/// Everything the app needs to know about one level of one puzzle type.
struct LevelConfig: Identifiable {
    /// Unique stable identifier — used as a UserDefaults/CloudKit key.
    /// Format: "<puzzleTypeID>.<levelName>" e.g. "queens.Expert"
    let id: String

    /// Display name shown on level cards and in the nav bar. e.g. "Expert"
    let displayName: String

    /// The puzzle type this level belongs to.
    let puzzleTypeID: String

    /// Whether this level requires an IAP unlock.
    let requiresPurchase: Bool

    /// Opaque config bag — interpreted by the puzzle type's engine factory.
    /// For Queens this holds size + difficulty; future games can put whatever they need here.
    let engineConfig: AnyPuzzleEngineConfig
}

// MARK: - Engine Config

/// Type-erased wrapper so LevelConfig can carry game-specific config without generics.
struct AnyPuzzleEngineConfig {
    let value: Any

    func unwrap<T>(as type: T.Type) -> T? { value as? T }
}

// MARK: - Engine Factory Result

/// What DailyChallengeManager gets back when it asks the registry to generate an engine.
/// Today this is always a QueensPuzzleEngine; future games return their own engine type.
enum PuzzleEngineResult {
    case queens(QueensPuzzleEngine)
    // case wordSearch(WordSearchEngine)   ← future games add a case here
}

// MARK: - Puzzle Type Descriptor

/// Conform to this protocol to register a new puzzle type.
protocol PuzzleTypeDescriptor {
    /// Stable unique ID. Never change this after shipping — it's used in persistence keys.
    var id: String { get }

    /// Ordered list of levels for this puzzle type.
    var levels: [LevelConfig] { get }

    /// Generates an engine for the given level. Returns nil if generation fails.
    func makeEngine(for level: LevelConfig, seed: UInt64?) async -> PuzzleEngineResult?
}

// MARK: - PuzzleRegistry

/// Singleton. Holds all registered puzzle types.
/// Call PuzzleRegistry.shared.register() at app start if you need lazy registration,
/// but the default implementation pre-registers everything in init().
@MainActor
final class PuzzleRegistry {
    static let shared = PuzzleRegistry()

    private var descriptors: [String: any PuzzleTypeDescriptor] = [:]

    private init() {
        register(QueensPuzzleType())
        // register(WordSearchPuzzleType())   ← add future games here
    }

    func register(_ descriptor: some PuzzleTypeDescriptor) {
        descriptors[descriptor.id] = descriptor
    }

    // MARK: - Querying

    /// All levels across all registered puzzle types, in registration order.
    var allLevels: [LevelConfig] {
        descriptors.values.flatMap { $0.levels }
    }

    /// Levels for a specific puzzle type.
    func levels(for puzzleTypeID: String) -> [LevelConfig] {
        descriptors[puzzleTypeID]?.levels ?? []
    }

    /// Look up a level config by its stable ID.
    func level(id: String) -> LevelConfig? {
        allLevels.first { $0.id == id }
    }

    /// Generate an engine for a level config.
    func makeEngine(for level: LevelConfig, seed: UInt64?) async -> PuzzleEngineResult? {
        guard let descriptor = descriptors[level.puzzleTypeID] else { return nil }
        return await descriptor.makeEngine(for: level, seed: seed)
    }
}

// MARK: - Queens Puzzle Type

/// Configuration for the Queens game — the only puzzle type in v1.
struct QueensPuzzleEngineConfig {
    let size: Int
    let difficulty: Difficulty
}

struct QueensPuzzleType: PuzzleTypeDescriptor {
    let id = "queens"

    let levels: [LevelConfig] = [
        LevelConfig(
            id: "queens.Easy",
            displayName: "Easy",
            puzzleTypeID: "queens",
            requiresPurchase: false,
            engineConfig: AnyPuzzleEngineConfig(value: QueensPuzzleEngineConfig(size: 6, difficulty: .easy))
        ),
        LevelConfig(
            id: "queens.Medium",
            displayName: "Medium",
            puzzleTypeID: "queens",
            requiresPurchase: false,
            engineConfig: AnyPuzzleEngineConfig(value: QueensPuzzleEngineConfig(size: 7, difficulty: .medium))
        ),
        LevelConfig(
            id: "queens.Hard",
            displayName: "Hard",
            puzzleTypeID: "queens",
            requiresPurchase: false,
            engineConfig: AnyPuzzleEngineConfig(value: QueensPuzzleEngineConfig(size: 8, difficulty: .hard))
        ),
        LevelConfig(
            id: "queens.Expert",
            displayName: "Expert",
            puzzleTypeID: "queens",
            requiresPurchase: true,
            engineConfig: AnyPuzzleEngineConfig(value: QueensPuzzleEngineConfig(size: 9, difficulty: .expert))
        ),
    ]

    func makeEngine(for level: LevelConfig, seed: UInt64?) async -> PuzzleEngineResult? {
        guard let config = level.engineConfig.unwrap(as: QueensPuzzleEngineConfig.self) else { return nil }
        guard let engine = await QueensPuzzleEngine.generate(
            size: config.size,
            difficulty: config.difficulty,
            seed: seed
        ) else { return nil }
        return .queens(engine)
    }
}
