import SwiftUI
import UI

struct MultiSelectButton: View {
    let emoji: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(emoji)
                    .font(.system(size: 32))
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(backgroundFill)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.clear : Color(uiColor: .separator),
                        lineWidth: 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    @ViewBuilder
    private var backgroundFill: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        if isSelected {
            shape.fill(LinearGradient.brand)
        } else {
            shape.fill(Color(uiColor: .secondarySystemBackground))
        }
    }
}
