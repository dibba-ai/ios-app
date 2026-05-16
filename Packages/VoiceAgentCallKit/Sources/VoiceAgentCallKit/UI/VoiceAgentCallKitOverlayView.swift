import SwiftUI
import VoiceAgent

public struct VoiceAgentCallKitOverlayView: View {
    @Bindable public var model: VoiceAgentCallKitController

    public init(model: VoiceAgentCallKitController) {
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

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                if model.outputTranscriptVisible, !model.assistantTranscript.isEmpty {
                    transcriptBanner
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity.combined(with: .scale(scale: 0.96))
                            )
                        )
                }

                controls
                    .padding(.horizontal, 32)
                    .padding(.bottom, 56)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(.smooth(duration: 0.3), value: model.assistantTranscript.isEmpty)
        .animation(.smooth(duration: 0.25), value: model.outputTranscriptVisible)
        .animation(.smooth(duration: 0.3), value: model.phase)
    }

    private var backgroundLayer: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            if case .live = model.phase {
                EdgeGlowView(level: model.level)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            voiceBadge
            VStack(alignment: .leading, spacing: 4) {
                captionView
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(model.displayName)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
    }

    private var voiceBadge: some View {
        Text(model.voiceEmoji ?? "🎙️")
            .font(.system(size: 32))
            .frame(width: 48, height: 48)
    }

    @ViewBuilder
    private var captionView: some View {
        if case .live = model.phase, let connectedAt = model.connectedAt {
            ConnectedTimer(connectedAt: connectedAt)
        } else {
            Text(captionText)
        }
    }

    private var captionText: String {
        switch model.phase {
        case .idle: return ""
        case .connecting: return "Connecting…"
        case .requestingPermission: return "Requesting permission…"
        case .live: return "Connected"
        case .error(let msg): return msg
        }
    }

    private var transcriptBanner: some View {
        Text(model.assistantTranscript)
            .font(.system(size: 17, weight: .medium, design: .rounded))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .lineLimit(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .glassBackground(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var controls: some View {
        HStack(spacing: 32) {
            callButton(
                label: "Mute",
                systemImage: model.isMuted ? "mic.slash.fill" : "mic.fill",
                isOn: model.isMuted,
                action: { model.toggleMute() }
            )
            endButton
            callButton(
                label: "Captions",
                systemImage: "captions.bubble.fill",
                isOn: model.outputTranscriptVisible,
                action: { model.toggleOutputTranscript() }
            )
        }
    }

    @ViewBuilder
    private func callButton(label: String, systemImage: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            if #available(iOS 26.0, *) {
                if isOn {
                    Button(action: action) {
                        Image(systemName: systemImage)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 68, height: 68)
                    }
                    .tint(.white)
                    .buttonStyle(.glassProminent)
                    .clipShape(Circle())
                    .accessibilityLabel(label)
                } else {
                    Button(action: action) {
                        Image(systemName: systemImage)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 68, height: 68)
                    }
                    .buttonStyle(.glass)
                    .clipShape(Circle())
                    .accessibilityLabel(label)
                }
            } else {
                Button(action: action) {
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isOn ? Color.black : Color.white)
                        .frame(width: 68, height: 68)
                        .background(
                            Circle().fill(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.ultraThinMaterial))
                        )
                        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var endButton: some View {
        VStack(spacing: 8) {
            if #available(iOS 26.0, *) {
                Button(role: .destructive, action: { model.stop() }) {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 68, height: 68)
                }
                .tint(.red)
                .buttonStyle(.glassProminent)
                .clipShape(Circle())
                .accessibilityLabel("End voice session")
            } else {
                Button(action: { model.stop() }) {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 68, height: 68)
                        .background(Circle().fill(Color.red))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("End voice session")
            }
            Text("End")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ConnectedTimer: View {
    let connectedAt: Date

    var body: some View {
        TimelineView(.periodic(from: connectedAt, by: 1)) { context in
            Text(format(elapsed: context.date.timeIntervalSince(connectedAt)))
                .monospacedDigit()
        }
    }

    private func format(elapsed: TimeInterval) -> String {
        let total = max(0, Int(elapsed))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

private extension View {
    @ViewBuilder
    func glassBackground<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self
                .background(shape.fill(.ultraThinMaterial))
                .overlay(shape.stroke(Color.white.opacity(0.18), lineWidth: 0.5))
                .clipShape(shape)
        }
    }
}
