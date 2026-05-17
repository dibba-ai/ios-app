import SwiftUI
import UI

struct OnboardingFooterButton: View {
    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    @State private var tapTick = 0

    var body: some View {
        Button {
            tapTick &+= 1
            action()
        } label: {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .fontWeight(.semibold)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient.brand)
                    .opacity(isEnabled && !isLoading ? 1 : 0.4)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .sensoryFeedback(.impact(weight: .medium), trigger: tapTick)
    }
}
