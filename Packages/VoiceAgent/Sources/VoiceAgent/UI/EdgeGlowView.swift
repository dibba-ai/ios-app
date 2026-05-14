import SwiftUI
import UIKit

/// Apple-Intelligence / Siri-style screen-edge glow.
///
/// Draws layered `RoundedRectangle` strokes whose corner radius matches the
/// device's display so the glow hugs the actual screen bezel.
///
/// Stroke width + opacity respond to two drivers:
///   * `level` (0…1) — louder voice = thicker, brighter glow.
///   * idle breathing — gentle sine pulse (~0.5 Hz) that dominates when `level`
///     is low so the glow never sits perfectly static.
public struct EdgeGlowView: View {
    public var level: Float

    public init(level: Float) {
        self.level = level
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let breath = breathValue(t: t)                  // 0…1
            let quietWeight = 1 - CGFloat(level)            // 1 when silent, 0 when loud
            let intensity = CGFloat(level) + breath * quietWeight * 0.45

            ZStack {
                strokeLayer(baseWidth: 8, intensityBoost: 22, blur: 18, alpha: 0.55, intensity: intensity, t: t)
                strokeLayer(baseWidth: 3, intensityBoost: 12, blur: 6, alpha: 0.75, intensity: intensity, t: t)
                strokeLayer(baseWidth: 0.75, intensityBoost: 2.5, blur: 0, alpha: 1.0, intensity: intensity, t: t)
            }
            .opacity(0.3 + Double(intensity) * 0.7)
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    // MARK: Drivers

    /// Pseudo-random 0…1 breath value built from a sum of low-frequency sines
    /// with relatively prime periods, then re-modulated by a slower envelope so
    /// each in/out cycle differs slightly in both timing and amplitude.
    private func breathValue(t: TimeInterval) -> CGFloat {
        let s1 = sin(t * 0.62 + 0.7)
        let s2 = sin(t * 0.93 + 2.3)
        let s3 = sin(t * 1.41 + 4.1)
        let mixed = (s1 * 0.55 + s2 * 0.30 + s3 * 0.15)   // -1…+1
        let base = (mixed + 1) * 0.5                       // 0…1

        // Slow envelope (≈45 s period) shapes how "deep" each breath goes —
        // sometimes nearly flat, sometimes pronounced.
        let envelope = (sin(t * 0.14 + 1.2) + 1) * 0.5
        let amplitudeScale = 0.35 + envelope * 0.65

        return CGFloat(min(1, max(0, base * amplitudeScale)))
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
                Color(red: 1.0, green: 0.55, blue: 0.0),  // #FF8C00
                Color(red: 1.0, green: 0.65, blue: 0.0),  // #FFA500
                Color(red: 1.0, green: 0.78, blue: 0.25),
                Color(red: 1.0, green: 0.65, blue: 0.0),
                Color(red: 1.0, green: 0.55, blue: 0.0),
            ]),
            center: .center,
            angle: .degrees(t * 45)
        )
    }

    // MARK: Display corner radius

    private var cornerRadius: CGFloat {
        if let key = ["_", "display", "Corner", "Radius"].joined() as String?,
           let value = UIScreen.main.value(forKey: key) as? CGFloat,
           value > 0 {
            return value
        }
        return 55
    }
}
