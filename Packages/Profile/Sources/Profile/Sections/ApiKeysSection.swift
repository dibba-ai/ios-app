import Servicing
import SwiftUI

struct ApiKeysSection: View {
    let apiKeys: [Servicing.ApiKey]
    let isCreatingApiKey: Bool
    let onSelectApiKey: (String) -> Void
    let onAddDevice: () -> Void

    var body: some View {
        Section("Devices") {
            ForEach(apiKeys) { apiKey in
                Button {
                    onSelectApiKey(apiKey.id)
                } label: {
                    HStack {
                        Image(systemName: "iphone")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(apiKey.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text(apiKey.formattedCreatedAt)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if apiKey.isActive {
                            Text("Active")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Text("Inactive")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Button(action: onAddDevice) {
                HStack {
                    Label("Add Device", systemImage: "plus.circle")
                    if isCreatingApiKey {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isCreatingApiKey)
        }
    }
}
