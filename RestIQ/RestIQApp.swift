//
//  RestIQApp.swift
//  RestIQ
//
//  Created by Alfin Baby on 12/10/25.
//  Updated: Adds SwiftUI Launch Screen with smooth fade transition
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
                        .onAppear {
                            // Fade out launch screen after 2 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
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
}
