//
//  LaunchScreenView.swift
//  RestIQ
//
//  Created by Alfin Baby on 16/10/25.
//


//
//  LaunchScreenView.swift
//  RestIQ
//
//  Created by Alfin Baby on 17/10/25.
//

import SwiftUI

struct LaunchScreenView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var fadeIn: Bool = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(.displayP3, red: 1.00, green: 0.74, blue: 0.40),
                    Color(.displayP3, red: 1.00, green: 0.56, blue: 0.36),
                    Color(.displayP3, red: 0.96, green: 0.28, blue: 0.36)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                Text("RestIQ")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
                    .opacity(fadeIn ? 1 : 0)
                    .scaleEffect(fadeIn ? 1.0 : 0.8)
                    .animation(.easeOut(duration: 1.0), value: fadeIn)

                Text("Daily puzzles to refresh your mind")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .opacity(fadeIn ? 1 : 0)
                    .animation(.easeOut(duration: 1.2).delay(0.4), value: fadeIn)
            }
        }
        .onAppear {
            fadeIn = true
        }
    }
}

#Preview {
    LaunchScreenView()
        .preferredColorScheme(.dark)
}
