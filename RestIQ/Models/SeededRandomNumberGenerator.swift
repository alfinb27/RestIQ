//
//  SeededRandomNumberGenerator.swift
//  RestIQ
//
//  Created by Alfin Baby on 12/10/25.
//


// Models/SeededRandomNumberGenerator.swift
// Deterministic RNG used to make daily puzzles identical across devices.

import Foundation

/// Small LCG RNG for deterministic behavior. Sendable for Swift 6 concurrency.
struct SeededRandomNumberGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        // LCG constants chosen for simple, deterministic sequence.
        state = state &* 6364136223846793005 &+ 1
        return state
    }
}

