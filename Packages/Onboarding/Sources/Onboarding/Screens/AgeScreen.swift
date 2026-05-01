import Core
import SwiftUI

struct AgeScreen: View {
    @Bindable var viewModel: OnboardingViewModel

    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 240), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(AgeOption.allCases) { option in
                    MultiSelectButton(
                        emoji: option.emoji,
                        label: option.label,
                        isSelected: viewModel.data.age == option
                    ) {
                        viewModel.selectAge(option)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}
