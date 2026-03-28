import Foundation

enum DeviceSetupMethod: String, CaseIterable, Identifiable {
    case applePay
    case sms

    var id: String { rawValue }

    var title: String {
        switch self {
        case .applePay: "Apple Pay"
        case .sms: "SMS"
        }
    }

    var icon: String {
        switch self {
        case .applePay: "creditcard.fill"
        case .sms: "message.fill"
        }
    }

    var description: String {
        switch self {
        case .applePay: "Forward Apple Pay transactions"
        case .sms: "Forward bank SMS notifications"
        }
    }

    var webhookPath: String {
        switch self {
        case .applePay: "apple_pay"
        case .sms: "sms"
        }
    }

    var tutorialUrl: URL? {
        switch self {
        case .applePay: URL(string: "https://youtube.com/shorts/eDboCJ5QD4I")
        case .sms: URL(string: "https://youtube.com/shorts/UgQLk7XmEGs")
        }
    }

    var tutorialUrlWithGeo: URL? {
        switch self {
        case .applePay: URL(string: "https://youtube.com/shorts/lNi0iYA0upw")
        case .sms: URL(string: "https://youtube.com/shorts/ZFRUwCtExnc")
        }
    }

    func webhookURL(apiKeyId: String) -> String {
        "https://api.dibba.ai/\(webhookPath)?x=\(apiKeyId)"
    }
}
