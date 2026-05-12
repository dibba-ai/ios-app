import Auth
import Servicing
import UIKit

enum SupportMailComposer {
    static func openMail(subject: String, profile: Servicing.Profile?, authUser: AuthUser?) {
        let body = mailBody(profile: profile, authUser: authUser)
        let allowed = CharacterSet.urlQueryAllowed
        guard
            let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: allowed),
            let encodedBody = body.addingPercentEncoding(withAllowedCharacters: allowed),
            let url = URL(string: "mailto:support@dibba.ai?subject=\(encodedSubject)&body=\(encodedBody)")
        else { return }
        UIApplication.shared.open(url)
    }

    private static func mailBody(profile: Servicing.Profile?, authUser: AuthUser?) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        func format(_ date: Date?) -> String {
            guard let date else { return "—" }
            return isoFormatter.string(from: date)
        }

        let bundle = Bundle.main
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "—"

        let device = UIDevice.current
        let locale = Locale.current
        let country = locale.region?.identifier ?? "—"
        let localeId = locale.identifier
        let language = locale.language.languageCode?.identifier ?? "—"
        let currency = locale.currency?.identifier ?? "—"
        let appLanguage = Locale.preferredLanguages.first ?? "—"
        let timeZone = TimeZone.current.identifier
        let gmtOffsetSeconds = TimeZone.current.secondsFromGMT()
        let gmtOffsetHours = Double(gmtOffsetSeconds) / 3600
        let gmtOffset = String(format: "GMT%+.2f", gmtOffsetHours)

        var lines: [String] = []
        lines.append("")
        lines.append("")
        lines.append("---")
        lines.append("User / App Information")
        lines.append("---")
        lines.append("User ID: \(authUser?.id ?? "—")")
        lines.append("Email: \(authUser?.email ?? profile?.email ?? "—")")
        lines.append("Name: \(authUser?.name ?? profile?.name ?? "—")")
        lines.append("Created At: \(format(profile?.createdAt))")
        lines.append("Plan: \(profile?.plan.rawValue ?? "—")")
        lines.append("Plan Starts At: \(format(profile?.planStartsAt))")
        lines.append("Plan Expires At: \(format(profile?.planExpiresAt))")
        lines.append("App Version: \(version)")
        lines.append("App Build: \(build)")
        lines.append("Device: \(device.model) (\(hardwareIdentifier))")
        lines.append("OS: \(device.systemName) \(device.systemVersion)")
        lines.append("Country: \(country)")
        lines.append("Locale: \(localeId)")
        lines.append("Language: \(language)")
        lines.append("Currency: \(currency)")
        lines.append("App Language: \(appLanguage)")
        lines.append("Timezone: \(timeZone) (\(gmtOffset))")
        return lines.joined(separator: "\n")
    }

    private static let hardwareIdentifier: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce("") { partial, element in
            guard let value = element.value as? Int8, value != 0 else { return partial }
            return partial + String(UnicodeScalar(UInt8(value)))
        }
        return identifier.isEmpty ? "—" : identifier
    }()
}
