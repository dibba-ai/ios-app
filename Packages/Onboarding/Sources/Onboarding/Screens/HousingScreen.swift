import Core
import SwiftUI

struct HousingScreen: View {
    @Bindable var viewModel: OnboardingViewModel

    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 240), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(HousingOption.allCases) { option in
                    MultiSelectButton(
                        emoji: option.emoji,
                        label: option.label,
                        isSelected: viewModel.data.housing.contains(option)
                    ) {
                        viewModel.toggleHousing(option)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}
