import Foundation

public enum VoiceAgentMode: String, CaseIterable, Sendable {
    case overlay
    case callKit

    public var displayName: String {
        switch self {
        case .overlay: return "Custom Overlay"
        case .callKit: return "Native (CallKit)"
        }
    }
}

public enum VoiceAgentModePreference {
    public static let key = "ai.dibba.voiceAgentMode"

    public static var current: VoiceAgentMode {
        get {
            let raw = UserDefaults.standard.string(forKey: key) ?? VoiceAgentMode.overlay.rawValue
            return VoiceAgentMode(rawValue: raw) ?? .overlay
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }
}
