//
//  RestIQApp.swift
//  RestIQ
//
//  Created by Alfin Baby on 12/10/25.
//  Updated: Pre-generates all daily puzzles at launch in background to avoid load delay.
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

    /// Generates all puzzles for each level asynchronously so that they are cached before user plays.
    private func preloadDailyPuzzles() async {
        let levels = ["Easy", "Medium", "Hard", "Expert"]
        await withTaskGroup(of: Void.self) { group in
            for level in levels {
                group.addTask {
                    _ = await DailyChallengeManager.shared.generateDailyPuzzle(for: level)
                }
            }
        }
    }
}
