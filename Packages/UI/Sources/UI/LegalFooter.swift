import SwiftUI

public struct LegalFooter: View {
    public init(showVersion: Bool = false) {
        self.showVersion = showVersion
    }

    public var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Link("Terms & Conditions", destination: URL(string: "https://dibba.ai/terms")!)
                Link("Privacy Policy", destination: URL(string: "https://dibba.ai/privacy")!)
            }
            .font(.footnote)
            .fontWeight(.bold)
            .underline()
            .foregroundStyle(.secondary)
            VStack(spacing: 2) {
                Text("Dibba.ai \u{00A9} 2026")
                if showVersion {
                    Text(versionLine)
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private let showVersion: Bool

    private var versionLine: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "v\(version) (\(build))"
    }
}
