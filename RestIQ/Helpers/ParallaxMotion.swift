//
//  ParallaxMotion.swift
//  RestIQ
//
//  Created by Alfin Baby on 14/10/25.
//


import Foundation
import CoreMotion
import SwiftUI
import Combine

@available(iOS 18.0, *)
final class ParallaxMotion: ObservableObject {
    static let shared = ParallaxMotion()

    private let manager = CMMotionManager()
    @Published var x: Double = 0
    @Published var y: Double = 0

    private init() { }

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let m = motion, let self = self else { return }
            // small scale multipliers for subtle parallax
            self.x = m.attitude.pitch * 10
            self.y = m.attitude.roll * 10
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        x = 0
        y = 0
    }
}