import SwiftUI

struct NotificationToggle: View {
    let title: String
    let isOn: Bool
    let onUpdate: (Bool) async -> Void

    @State private var localIsOn: Bool = false
    @State private var isUpdating = false

    init(title: String, isOn: Bool, onUpdate: @escaping (Bool) async -> Void) {
        self.title = title
        self.isOn = isOn
        self.onUpdate = onUpdate
        self._localIsOn = State(initialValue: isOn)
    }

    var body: some View {
        Toggle(isOn: $localIsOn) {
            HStack(spacing: 8) {
                if isUpdating {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                Text(title)
            }
        }
        .disabled(isUpdating)
        .onChange(of: localIsOn) { _, newValue in
            guard newValue != isOn, !isUpdating else { return }
            Task {
                isUpdating = true
                await onUpdate(newValue)
                isUpdating = false
            }
        }
        .onChange(of: isOn) { _, newValue in
            localIsOn = newValue
        }
    }
}
