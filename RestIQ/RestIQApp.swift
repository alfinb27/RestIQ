//
//  RestIQApp.swift
//  RestIQ
//
//  Created by Alfin Baby on 12/10/25.
//  Updated: Pre-generates all daily puzzles at launch using PuzzleRegistry.
//

import SwiftUI

@main
struct RestIQApp: App {
    @State private var showLaunchScreen = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showLaunchScreen {
                    LaunchScreenView()
                        .transition(.opacity)
                } else {
                    HomeView()
                        .transition(.opacity)
                }
            }
            .task {
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { await preloadDailyPuzzles() }
                    group.addTask { try? await Task.sleep(for: .seconds(2.5)) }
                    await group.waitForAll()
                }
                withAnimation(.easeOut(duration: 0.6)) {
                    showLaunchScreen = false
                }
            }
        }
    }

    /// Pre-generates all registered levels in parallel so puzzles are cached before the user taps a card.
    private func preloadDailyPuzzles() async {
        let levels = await PuzzleRegistry.shared.allLevels
        await withTaskGroup(of: Void.self) { group in
            for level in levels {
                group.addTask {
                    _ = await DailyChallengeManager.shared.generateDailyPuzzle(for: level)
                }
            }
        }
    }
}
