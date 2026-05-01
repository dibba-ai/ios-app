import SwiftUI

struct FeedJumpDateSheet: View {
    @Binding var jumpDate: Date
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                DatePicker(
                    "Scroll to Date",
                    selection: $jumpDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Scroll to Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Go", action: onConfirm)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
