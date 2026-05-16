import ApiClient
import Core
import Dependencies
import Servicing
import SwiftUI

struct AgentSection: View {
    let profile: Servicing.Profile
    let onUpdate: (UpdateProfileInput) async -> Void

    @State private var voices: [RealtimeVoice] = []

    @Dependency(\.apiClient) private var apiClient

    private var selectedVoice: RealtimeVoice? {
        guard let id = profile.favoriteRealtimeVoice else { return nil }
        return voices.first { $0.voice == id }
    }

    private var selectedVibe: VibeOption? {
        guard let raw = profile.favoriteVibe else { return nil }
        return VibeOption(rawValue: raw)
    }

    var body: some View {
        Section("Voice AI Agent") {
            voiceRow
            vibeRow
        }
        .task {
            if voices.isEmpty {
                await loadVoices()
            }
        }
    }

    @ViewBuilder
    private var voiceRow: some View {
        NavigationLink {
            RealtimeVoiceSelectView(
                selected: profile.favoriteRealtimeVoice,
                voices: voices,
                onUpdate: { newValue in
                    await onUpdate(UpdateProfileInput(favoriteRealtimeVoice: newValue))
                }
            )
        } label: {
            LabeledContent("Voice") {
                if let voice = selectedVoice {
                    Text(voiceLabel(voice))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if let id = profile.favoriteRealtimeVoice, !id.isEmpty {
                    Text(id)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Not Set")
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    @ViewBuilder
    private var vibeRow: some View {
        NavigationLink {
            VibeSelectView(
                selected: profile.favoriteVibe,
                onUpdate: { newValue in
                    await onUpdate(UpdateProfileInput(favoriteVibe: newValue))
                }
            )
        } label: {
            LabeledContent("Vibe") {
                if let vibe = selectedVibe {
                    Text("\(vibe.emoji) \(vibe.label)")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if let raw = profile.favoriteVibe, !raw.isEmpty {
                    Text(raw)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Not Set")
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func voiceLabel(_ voice: RealtimeVoice) -> String {
        if let emoji = voice.emoji, !emoji.isEmpty {
            return "\(emoji) \(voice.name)"
        }
        return voice.name
    }

    private func loadVoices() async {
        do {
            let dto = try await apiClient.getRealtimeOptions()
            voices = dto.voices.map { RealtimeVoice(from: $0) }
        } catch {
            // Silent fail — label falls back to raw voice id.
        }
    }
}
