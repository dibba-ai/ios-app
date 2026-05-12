import SwiftUI

public struct VoiceCaptureOverlayView: View {
    @Bindable public var model: VoiceCaptureOverlayModel

    public init(model: VoiceCaptureOverlayModel) {
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
            VStack(alignment: .center, spacing: 28) {
                Spacer()
                statusPill
                controls
                Spacer().frame(height: 80)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        switch model.phase {
        case .recording:
            ZStack {
                Color.black.opacity(0.55).ignoresSafeArea()
                EdgeGlowView(level: model.level)
            }
        default:
            Color.black.opacity(0.45).ignoresSafeArea()
        }
    }

    private var statusPill: some View {
        Text(statusText)
            .font(.callout)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.orange))
    }

    private var statusText: String {
        switch model.phase {
        case .idle: return "Idle"
        case .requestingPermission: return "Requesting permission…"
        case .recording: return "Recording — tap stop"
        case .recorded: return "Recorded — tap play"
        case .error(let msg): return msg
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch model.phase {
        case .recording:
            Button(action: { model.toggle() }) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 88, height: 88)
                    .background(Circle().fill(Color.red))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop recording")
        case .recorded:
            HStack(spacing: 28) {
                Button(action: { model.togglePlayback() }) {
                    Image(systemName: model.isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(Circle().fill(Color.orange))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.isPlaying ? "Stop playback" : "Play recording")

                Button(action: { model.discard() }) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(Circle().fill(Color.red.opacity(0.85)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Discard recording")
            }
        case .error:
            Button("Close", action: { model.discard() })
                .buttonStyle(.borderedProminent)
                .tint(.orange)
        case .requestingPermission, .idle:
            EmptyView()
        }
    }
}
