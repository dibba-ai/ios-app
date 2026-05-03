import ApiClient
import Foundation

enum IntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case unauthorized
    case network
    case invalidAmount
    case server(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .unauthorized:
            "Sign in to Dibba to log transactions."
        case .network:
            "Couldn't reach Dibba. Try again."
        case .invalidAmount:
            "Amount must be greater than zero."
        case .server(let message):
            "Couldn't log transaction: \(message)"
        }
    }

    static func from(_ error: Error) -> IntentError {
        if let apiError = error as? APIClientError {
            switch apiError {
            case .unauthorized: return .unauthorized
            case .client: return .network
            default: return .server(apiError.localizedDescription)
            }
        }
        if (error as NSError).domain == NSURLErrorDomain {
            return .network
        }
        return .server(error.localizedDescription)
    }
}
