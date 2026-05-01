import Analytics
import Core
import Dependencies
import SwiftUI

struct OnboardingHostView: View {
    @State private var viewModel: OnboardingViewModel
    @Dependency(\.analytics) private var analytics

    init(viewModel: OnboardingViewModel) {
        self._viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressBar(progress: viewModel.progress)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)

            StepHeader(title: viewModel.step.title, subtitle: viewModel.step.subtitle)
                .padding(.bottom, 12)

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
}
