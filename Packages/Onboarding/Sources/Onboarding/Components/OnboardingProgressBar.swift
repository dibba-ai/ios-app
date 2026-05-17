import SwiftUI
import UI

struct OnboardingProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            let clamped = max(0, min(progress, 1))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(uiColor: .systemGray5))
                Capsule()
                    .fill(LinearGradient.brandHorizontal)
                    .frame(width: geo.size.width * clamped)
            }
        }
        .frame(height: 6)
        .animation(.easeInOut(duration: 0.25), value: progress)
    }
}
