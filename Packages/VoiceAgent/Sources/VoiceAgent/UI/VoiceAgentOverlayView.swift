import SwiftUI

public struct VoiceAgentOverlayView: View {
    @Bindable public var model: VoiceAgentOverlayModel

    public init(model: VoiceAgentOverlayModel) {
        self.model = model
    }

    public var body: some View {
        if model.visible {
            content
        }
    }

    private var content: some View {
        ZStack {
            backgroundLayer
            VStack(spacing: 24) {
                statusPill
                transcriptArea
                Spacer()
                stopButton
                    .padding(.bottom, 80)
            }
            .padding(.top, 60)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        switch model.phase {
        case .live:
            ZStack {
                Color.black.opacity(0.55).ignoresSafeArea()
                EdgeGlowView(level: model.level)
            }
        default:
            Color.black.opacity(0.55).ignoresSafeArea()
        }
    }

    private var statusPill: some View {
        Text(statusText)
            .font(.callout)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Capsule().fill(statusColor))
    }

    private var statusText: String {
        switch model.phase {
        case .idle: return "Idle"
        case .connecting: return "Connecting…"
        case .requestingPermission: return "Requesting permission…"
        case .live: return "Listening"
        case .error(let msg): return msg
        }
    }

    private var statusColor: Color {
        switch model.phase {
        case .error: return .red.opacity(0.85)
        case .live: return .orange
        default: return .orange.opacity(0.7)
        }
    }

    @ViewBuilder
    private var transcriptArea: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !model.userTranscript.isEmpty {
                transcriptBubble(label: "You", text: model.userTranscript, align: .trailing)
            }
            if !model.assistantTranscript.isEmpty {
                transcriptBubble(label: "Dibba", text: model.assistantTranscript, align: .leading)
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func transcriptBubble(label: String, text: String, align: HorizontalAlignment) -> some View {
        VStack(alignment: align, spacing: 4) {
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.7))
            Text(text)
                .font(.body)
                .foregroundStyle(.white)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.thinMaterial)
                )
        }
        .frame(maxWidth: .infinity, alignment: align == .trailing ? .trailing : .leading)
    }

    @ViewBuilder
    private var stopButton: some View {
        switch model.phase {
        case .live, .connecting, .requestingPermission:
            Button(action: { model.stop() }) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 80, height: 80)
                    .background(Circle().fill(Color.red))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("End voice session")
        case .error, .idle:
            EmptyView()
        }
    }
}
