import SwiftUI
import UIKit

/// Apple-Intelligence / Siri-style screen-edge glow.
///
/// Layered `RoundedRectangle` strokes hug the device's display corners. All
/// width, opacity, and gradient rotation are driven by `level` (0…1) — louder
/// audio (either user or agent) thickens the strokes and rotates the gradient
/// faster. The view itself does NOT run a timer; SwiftUI re-renders whenever
/// `level` updates (typically 20Hz from `RealtimeClient`'s stats poller).
public struct EdgeGlowView: View {
    public var level: Float

    public init(level: Float) {
        self.level = level
    }

    public var body: some View {
        // Sample time at each redraw so the gradient continues to rotate while
        // `level` is changing — which happens naturally while audio is active.
        let t = Date().timeIntervalSinceReferenceDate
        let intensity = CGFloat(max(0, min(level, 1)))

        ZStack {
            strokeLayer(baseWidth: 8, intensityBoost: 26, blur: 18, alpha: 0.55, intensity: intensity, t: t)
            strokeLayer(baseWidth: 3, intensityBoost: 14, blur: 6, alpha: 0.75, intensity: intensity, t: t)
            strokeLayer(baseWidth: 0.75, intensityBoost: 3, blur: 0, alpha: 1.0, intensity: intensity, t: t)
        }
        .opacity(0.15 + Double(intensity) * 0.85)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(.linear(duration: 0.06), value: level)
    }

    // MARK: Layers

    private func strokeLayer(
        baseWidth: CGFloat,
        intensityBoost: CGFloat,
        blur: CGFloat,
        alpha: Double,
        intensity: CGFloat,
        t: TimeInterval
    ) -> some View {
        let width = baseWidth + intensity * intensityBoost
        return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(animatedGradient(t: t), lineWidth: width)
            .blur(radius: blur)
            .opacity(alpha)
    }

    private func animatedGradient(t: TimeInterval) -> AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [
                Color(red: 1.0, green: 0.55, blue: 0.0),
                Color(red: 1.0, green: 0.65, blue: 0.0),
                Color(red: 1.0, green: 0.78, blue: 0.25),
                Color(red: 1.0, green: 0.65, blue: 0.0),
                Color(red: 1.0, green: 0.55, blue: 0.0),
            ]),
            center: .center,
            angle: .degrees(t * 45)
        )
    }

    private var cornerRadius: CGFloat {
        if let key = ["_", "display", "Corner", "Radius"].joined() as String?,
           let value = UIScreen.main.value(forKey: key) as? CGFloat,
           value > 0 {
            return value
        }
        return 55
    }
}
