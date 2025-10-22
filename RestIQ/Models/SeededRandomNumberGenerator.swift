//
//  SeededRandomNumberGenerator.swift
//  RestIQ
//
//  Created by Alfin Baby on 12/10/25.
//


import Foundation

// Small LCG RNG for deterministic behavior.
@preconcurrency
struct SeededRandomNumberGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1
        return state
    }
}

