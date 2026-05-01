import SwiftUI

struct TransactionMessageBubble: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(icon: "message.fill", title: "Message")
            HStack {
                Text(text)
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 18))
                Spacer(minLength: 48)
            }
        }
    }
}
