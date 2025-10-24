//
//  DebugConfig.swift
//  RestIQ
//
//  Created by Alfin Baby on 24/10/25.
//


import Foundation
import SwiftUI
import Combine

@MainActor
final class DebugConfig: ObservableObject {
    static let shared = DebugConfig()
    @Published var debugMode = false
}
