//
//  Haptics.swift
//  RestIQ
//
//  Created by Alfin Baby on 16/10/25.
//  Updated: Safe, reusable haptic generators.
//

import UIKit

enum Haptics {
    private static let impactSoft = UIImpactFeedbackGenerator(style: .soft)
    private static let impactLight = UIImpactFeedbackGenerator(style: .light)
    private static let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private static let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notifier = UINotificationFeedbackGenerator()

    private static var hapticsAvailable: Bool {
        // On iOS devices without Taptic Engine, the generators no-op anyway,
        // but we can early-out in simulators / older devices if needed later.
        true
    }

    static func soft() {
        guard hapticsAvailable else { return }
        impactSoft.prepare()
        impactSoft.impactOccurred()
    }

    static func light() {
        guard hapticsAvailable else { return }
        impactLight.prepare()
        impactLight.impactOccurred()
    }

    static func medium() {
        guard hapticsAvailable else { return }
        impactMedium.prepare()
        impactMedium.impactOccurred()
    }

    static func heavy() {
        guard hapticsAvailable else { return }
        impactHeavy.prepare()
        impactHeavy.impactOccurred()
    }

    static func success() {
        guard hapticsAvailable else { return }
        notifier.prepare()
        notifier.notificationOccurred(.success)
    }

    static func warning() {
        guard hapticsAvailable else { return }
        notifier.prepare()
        notifier.notificationOccurred(.warning)
    }

    static func error() {
        guard hapticsAvailable else { return }
        notifier.prepare()
        notifier.notificationOccurred(.error)
    }
}
