import SwiftUI

public struct LegalFooter: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Link("Terms & Conditions", destination: URL(string: "https://dibba.ai/terms")!)
                Link("Privacy Policy", destination: URL(string: "https://dibba.ai/privacy")!)
            }
            .font(.footnote)
            Text("Dibba.ai \u{00A9} 2026")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
