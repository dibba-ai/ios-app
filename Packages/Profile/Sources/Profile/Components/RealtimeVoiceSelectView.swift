import Servicing
import SwiftUI

struct RealtimeVoiceSelectView: View {
    let selected: String?
    let voices: [RealtimeVoice]
    let onUpdate: (String?) async -> Void

    @State private var localSelected: String?
    @State private var isUpdating = false

    init(
        selected: String?,
        voices: [RealtimeVoice],
        onUpdate: @escaping (String?) async -> Void
    ) {
        self.selected = selected
        self.voices = voices
        self.onUpdate = onUpdate
        self._localSelected = State(initialValue: selected)
    }

    var body: some View {
        List {
            ForEach(voices) { voice in
                voiceRow(voice)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Voice")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isUpdating {
                    ProgressView()
                }
            }
        }
        .onChange(of: selected) { _, newValue in
            localSelected = newValue
        }
    }

    @ViewBuilder
    private func voiceRow(_ voice: RealtimeVoice) -> some View {
        let isSelected = localSelected == voice.voice
        Button {
            localSelected = voice.voice
            Task {
                isUpdating = true
                await onUpdate(voice.voice)
                isUpdating = false
            }
        } label: {
            HStack(spacing: 12) {
                if let emoji = voice.emoji, !emoji.isEmpty {
                    Text(emoji)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(voice.name)
                    if let gender = voice.gender, !gender.isEmpty {
                        Text(gender.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .disabled(isUpdating)
    }
}
