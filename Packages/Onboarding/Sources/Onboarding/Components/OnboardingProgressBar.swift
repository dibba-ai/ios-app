import SwiftUI

struct OnboardingProgressBar: View {
    let progress: Double

    var body: some View {
        ProgressView(value: max(0, min(progress, 1)))
            .progressViewStyle(.linear)
            .tint(.accentColor)
            .animation(.easeInOut(duration: 0.25), value: progress)
    }
}
