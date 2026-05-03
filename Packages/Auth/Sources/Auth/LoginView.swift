import Analytics
import Dependencies
import SwiftUI

public struct LoginView: View {
    public init() {}

    @Dependency(\.analytics) private var analytics

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.largeTitle)
            Text("Login")
        }
        .onAppear {
            analytics.capture(.landingPageOpened)
        }
    }
}
