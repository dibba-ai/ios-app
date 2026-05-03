import SwiftUI

public enum LegalLink: Sendable {
    case terms
    case privacy
}

public struct LegalFooter: View {
    public init(
        showVersion: Bool = false,
        onLinkTap: ((LegalLink) -> Void)? = nil
    ) {
        self.showVersion = showVersion
        self.onLinkTap = onLinkTap
    }

    @Environment(\.openURL) private var openURL

    public var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Button("Terms & Conditions") {
                    onLinkTap?(.terms)
                    openURL(URL(string: "https://dibba.ai/terms")!)
                }
                Button("Privacy Policy") {
                    onLinkTap?(.privacy)
                    openURL(URL(string: "https://dibba.ai/privacy")!)
                }
            }
            .buttonStyle(.plain)
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
    private let onLinkTap: ((LegalLink) -> Void)?

    private var versionLine: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "v\(version) (\(build))"
    }
}
