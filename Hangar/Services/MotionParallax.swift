import Foundation
import Combine
import CoreMotion
import SwiftUI

@MainActor
final class MotionParallax: ObservableObject {
    @Published var pitch: Double = 0
    @Published var roll: Double = 0

    private let manager = CMMotionManager()

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let data else { return }
            self?.pitch = Self.clamp(data.attitude.pitch)
            self?.roll = Self.clamp(data.attitude.roll)
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, -0.45), 0.45)
    }
}
