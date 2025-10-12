//
//  RestIQApp.swift
//  RestIQ
//
//  Created by Alfin Baby on 12/10/25.
//

import SwiftUI

@main
struct RestIQApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGray6))
        }
        .windowResizability(.contentSize)
    }
}
