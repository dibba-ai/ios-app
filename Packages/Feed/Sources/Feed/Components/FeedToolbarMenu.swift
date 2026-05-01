import Servicing
import SwiftUI

struct FeedToolbarMenu: View {
    @Binding var filterType: Servicing.TransactionType?
    let onShowDateJump: () -> Void
    let onScrollToEnd: () -> Void

    var body: some View {
        Menu {
            Picker("Type", selection: $filterType) {
                Text("All Types").tag(Servicing.TransactionType?.none)
                ForEach(Servicing.TransactionType.allCases, id: \.self) { type in
                    Text("\(type.emoji) \(type.displayName)").tag(Servicing.TransactionType?.some(type))
                }
            }

            Section("Jump") {
                Button(action: onShowDateJump) {
                    Label("Scroll to Date", systemImage: "calendar")
                }
                Button(action: onScrollToEnd) {
                    Label("Scroll to End", systemImage: "arrow.down.to.line")
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle\(filterType == nil ? "" : ".fill")")
        }
    }
}
