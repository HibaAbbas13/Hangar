import SwiftUI

enum FDMotion {
    static let press = Animation.spring(response: 0.28, dampingFraction: 0.72)
    static let card = Animation.spring(response: 0.42, dampingFraction: 0.86)
    static let sheet = Animation.spring(response: 0.48, dampingFraction: 0.9)
    static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.82)
    static let slow = Animation.spring(response: 0.7, dampingFraction: 0.9)

    static func stagger(_ index: Int, base: Double = 0.04) -> Double {
        Double(index) * base
    }
}

struct FDPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var depth: CGFloat = 5

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            
            
            .scaleEffect(configuration.isPressed ? (reduceMotion ? 1 : 0.97) : 1)
            .opacity(configuration.isPressed && reduceMotion ? 0.72 : 1)
            .offset(y: configuration.isPressed && !reduceMotion ? depth / 2 : 0)
            .animation(reduceMotion ? .easeOut(duration: 0.12) : FDMotion.press,
                       value: configuration.isPressed)
    }
}

struct FDParallaxTilt: ViewModifier {
    var pitch: Double
    var roll: Double
    var enabled: Bool

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(enabled ? pitch * 8 : 0),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.65
            )
            .rotation3DEffect(
                .degrees(enabled ? roll * 8 : 0),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.65
            )
            .animation(FDMotion.card, value: pitch)
            .animation(FDMotion.card, value: roll)
    }
}

extension View {
    func fdParallax(pitch: Double, roll: Double, enabled: Bool) -> some View {
        modifier(FDParallaxTilt(pitch: pitch, roll: roll, enabled: enabled))
    }
}
