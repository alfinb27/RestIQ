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
    @State private var preloadDone = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showLaunchScreen {
                    LaunchScreenView()
                        .transition(.opacity)
                        .onAppear {
                            // Start puzzle pre-generation immediately
                            Task.detached(priority: .background) {
                                await preloadDailyPuzzles()
                                await MainActor.run {
                                    preloadDone = true
                                }
                            }

                            // Fade out launch screen after preload or 2.5s minimum
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                withAnimation(.easeOut(duration: 0.6)) {
                                    showLaunchScreen = false
                                }
                            }
                        }
                } else {
                    HomeView()
                        .transition(.opacity)
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
