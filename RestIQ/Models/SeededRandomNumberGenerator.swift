//
//  SeededRandomNumberGenerator.swift
//  RestIQ
//

import Foundation

@preconcurrency
struct SeededRandomNumberGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    nonisolated init(seed: UInt64) {
        self.state = seed
    }

    nonisolated mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1
        return state
    }
}
