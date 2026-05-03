import Analytics
import Dependencies
import SwiftUI
import os.log

private let logger = Logger(subsystem: "ai.dibba.ios", category: "ConnectDeviceInstructions")

struct ConnectDeviceInstructionsView: View {
    let method: DeviceSetupMethod
    let apiKeyId: String
    let includeLocation: Bool

    @State private var showCopiedToast = false

    @Dependency(\.analytics) private var analytics

    private var webhookURL: String {
        method.webhookURL(apiKeyId: apiKeyId)
    }

    private var tutorialUrl: URL? {
        includeLocation ? method.tutorialUrlWithGeo : method.tutorialUrl
    }

    var body: some View {
        List {
            webhookSection
            triggerSection
            forwardingSection

            if let url = tutorialUrl {
                tutorialSection(url: url)
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(12)
        .navigationTitle("Setup \(method.title)")
        .onAppear {
            copyToClipboard(auto: true)
        }
        .overlay(alignment: .top) {
            if showCopiedToast {
                copiedToast
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showCopiedToast)
    }

    // MARK: - Webhook URL

    @ViewBuilder
    private var webhookSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Copy URL", systemImage: "1.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack {
                    Text(webhookURL)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button {
                        copyToClipboard(auto: false)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.body)
                    }
                }
                .padding(10)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.vertical, 4)
        } footer: {
            Text("Auto-copied to your clipboard")
        }
    }

    // MARK: - Trigger Section

    @ViewBuilder
    private var triggerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label("Create Automation", systemImage: "2.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                steps(for: triggerSteps)

                Link(destination: URL(string: "shortcuts://create-automation")!) {
                    Label("Open Shortcuts App", systemImage: "arrow.up.forward.app")
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.vertical, 4)
        }
    }

    private var triggerSteps: [InstructionStep] {
        switch method {
        case .applePay:
            [
                .init("Open **Shortcuts** app"),
                .init("Tap on **Wallet**"),
                .init("Scroll down"),
                .init("Tap on **Run Immediately**"),
                .init("Tap on **Next**"),
            ]
        case .sms:
            [
                .init("Open **Shortcuts** app"),
                .init("Tap on **Message**"),
                .init("Tap on **Message Contains**, enter your currency code"),
                .init("Enable **Run Immediately**"),
                .init("Tap On **Next**"),
            ]
        }
    }

    // MARK: - Forwarding Section

    @ViewBuilder
    private var forwardingSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label("Configure Forwardling", systemImage: "3.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                steps(for: forwardingSteps)
            }
            .padding(.vertical, 4)
        }
    }

    private var forwardingSteps: [InstructionStep] {
        var result: [InstructionStep] = [
            .init("Tap **Create New Shortcut**"),
            .init("Search **Get Contents of URL**, tap it"),
            .init("Paste the webhook URL"),
            .init("Tap expand, change Method to **POST**"),
        ]

        switch method {
        case .applePay:
            result += [
                .init("Add Text Field **merchant**, value **Shortcut Input** > Merchant"),
                .init("Add Text Field **amount**, value **Shortcut Input** > Amount"),
                .init("Add Text Field **card**, value **Shortcut Input** > Card or Pass"),
            ]
        case .sms:
            result += [
                .init("Add Text Field **text**, value **Shortcut Input**"),
                .init("Add Text Field **from**, value **Shortcut Input** > Sender"),
            ]
        }

        if includeLocation {
            result.append(.init("Add Text Field **location**, value **Current Location**"))
        }

        result.append(.init("Tap on **Done**"))
        return result
    }

    // MARK: - Tutorial

    @ViewBuilder
    private func tutorialSection(url: URL) -> some View {
        Section {
            Link(destination: url) {
                Label("Watch Video Tutorial", systemImage: "play.circle.fill")
            }
            .simultaneousGesture(TapGesture().onEnded {
                analytics.capture(.connectDeviceTutorialClicked, properties: [
                    "method": .string(method.title)
                ])
            })
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func steps(for items: [InstructionStep]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .trailing)

                    Text(LocalizedStringKey(step.text))
                        .font(.caption)
                }
            }
        }
    }

    private var copiedToast: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
            Text("URL copied")
        }
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.green.gradient, in: Capsule())
        .padding(.top, 8)
    }

    private func copyToClipboard(auto: Bool) {
        UIPasteboard.general.string = webhookURL
        logger.info("URL copied to clipboard (auto: \(auto))")
        if !auto {
            analytics.capture(.connectDeviceWebhookUrlCopied, properties: [
                "method": .string(method.title)
            ])
        }
        showCopiedToast = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            showCopiedToast = false
        }
    }
}

// MARK: - Instruction Step

private struct InstructionStep {
    let text: String
    init(_ text: String) { self.text = text }
}
