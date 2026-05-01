import Servicing
import SwiftUI

struct TransactionMetadataSection: View {
    let metadata: Servicing.TransactionMetadata

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(icon: "gearshape.fill", title: "Metadata")

            LabeledContent("Type", value: metadata.type)

            if let userAgent = metadata.userAgent, !userAgent.isEmpty {
                LabeledContent("User Agent", value: userAgent)
            }
            if let ipAddress = metadata.ipAddress, !ipAddress.isEmpty {
                LabeledContent("IP Address", value: ipAddress)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
