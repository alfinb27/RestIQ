//
//  Coord.swift
//  RestIQ
//
//  Created by Alfin Baby on 15/10/25.
//

import Foundation

/// Small Hashable coordinate wrapper. Use instead of (Int,Int) to allow Sets and Dictionary keys.
struct Coord: Hashable, Sendable {
    let r: Int
    let c: Int
}
