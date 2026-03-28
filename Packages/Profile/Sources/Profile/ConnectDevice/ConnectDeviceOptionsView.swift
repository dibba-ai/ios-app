import SwiftUI

struct ConnectDeviceOptionsView: View {
    let apiKeyId: String

    @State private var includeLocation = true

    var body: some View {
        List {
            Section {
                ForEach(DeviceSetupMethod.allCases) { method in
                    NavigationLink {
                        ConnectDeviceInstructionsView(
                            method: method,
                            apiKeyId: apiKeyId,
                            includeLocation: includeLocation
                        )
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: method.icon)
                                .font(.title2)
                                .foregroundStyle(.blue)
                                .frame(width: 36)

                            Text(method.title)
                                .font(.body)
                                .fontWeight(.medium)
                        }
                        .padding(.vertical, 6)
                    }
                }
            } header: {
                Text("Choose how to capture transactions")
            }

            Section {
                Toggle(isOn: $includeLocation) {
                    Label("Include Location", systemImage: "location.fill")
                }
            }

        }
        .listStyle(.insetGrouped)
        .navigationTitle("Add Device")
    }
}
