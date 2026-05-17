import SwiftUI

public extension Color {
    /// Brand accent gradient start — DarkOrange (#ff8c00).
    static let brandOrangeStart = Color(red: 1.0, green: 0x8c / 255.0, blue: 0.0)

    /// Brand accent gradient end — Orange (#ffa500).
    static let brandOrangeEnd = Color(red: 1.0, green: 0xa5 / 255.0, blue: 0.0)

    /// Single-swatch brand accent — midpoint between gradient stops, used where
    /// a gradient is impractical (e.g. tab bar tint, semantic .accentColor).
    static let brandOrange = Color(red: 1.0, green: 0x98 / 255.0, blue: 0.0)
}

public extension LinearGradient {
    /// Standard diagonal brand gradient: top-leading (dark) → bottom-trailing (light).
    static let brand = LinearGradient(
        colors: [.brandOrangeStart, .brandOrangeEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Horizontal brand gradient — useful for progress bars.
    static let brandHorizontal = LinearGradient(
        colors: [.brandOrangeStart, .brandOrangeEnd],
        startPoint: .leading,
        endPoint: .trailing
    )
}
