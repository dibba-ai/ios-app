import Analytics
import Core
import Dependencies
import SwiftUI

struct OnboardingHostView: View {
    @State private var viewModel: OnboardingViewModel
    @State private var backTapTick = 0
    @State private var showLogoutConfirm = false
    @Dependency(\.analytics) private var analytics

    private let onLogout: () -> Void

    init(viewModel: OnboardingViewModel, onLogout: @escaping () -> Void) {
        self._viewModel = State(wrappedValue: viewModel)
        self.onLogout = onLogout
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                backButton
                OnboardingProgressBar(progress: viewModel.progress)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .animation(.easeInOut(duration: 0.2), value: viewModel.canGoBack)

            if viewModel.step != .finish {
                StepHeader(title: viewModel.step.title, subtitle: viewModel.step.subtitle)
                    .padding(.bottom, 12)
            }

            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(viewModel.step)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            OnboardingFooterButton(
                title: viewModel.primaryButtonTitle,
                isLoading: viewModel.isSaving,
                isEnabled: viewModel.canAdvance,
                action: handlePrimaryTap
            )
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .animation(.easeInOut(duration: 0.25), value: viewModel.step)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: viewModel.step)
        .sensoryFeedback(.error, trigger: viewModel.errorMessage) { _, new in new != nil }
        .sensoryFeedback(.success, trigger: viewModel.isSaving) { old, new in old && !new && viewModel.errorMessage == nil }
        .onAppear {
            analytics.capture(.onboardingPageOpened)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.step {
        case .goals: GoalsScreen(viewModel: viewModel)
        case .occupation: OccupationScreen(viewModel: viewModel)
        case .housing: HousingScreen(viewModel: viewModel)
        case .transport: TransportScreen(viewModel: viewModel)
        case .currency: CurrencyScreen(viewModel: viewModel)
        case .age: AgeScreen(viewModel: viewModel)
        case .finish: FinishScreen(viewModel: viewModel)
        }
    }

    private func handlePrimaryTap() {
        if viewModel.step == .finish {
            Task { await viewModel.submit() }
        } else {
            viewModel.advance()
        }
    }

    @ViewBuilder
    private var backButton: some View {
        Button {
            backTapTick &+= 1
            if viewModel.canGoBack {
                viewModel.goBack()
            } else {
                showLogoutConfirm = true
            }
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
                .background(
                    Circle().fill(Color(uiColor: .secondarySystemBackground))
                )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSaving)
        .sensoryFeedback(.impact(weight: .light), trigger: backTapTick)
        .accessibilityLabel(viewModel.canGoBack ? "Back" : "Sign out")
        .confirmationDialog(
            "Sign out and return to login?",
            isPresented: $showLogoutConfirm,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) { onLogout() }
            Button("Cancel", role: .cancel) {}
        }
    }

}
