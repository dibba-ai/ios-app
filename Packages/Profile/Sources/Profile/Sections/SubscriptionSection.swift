import Paywall
import Servicing
import SwiftUI

struct SubscriptionSection: View {
    let profile: Servicing.Profile

    var body: some View {
        Section("Subscription") {
            LabeledContent("Plan") {
                HStack(spacing: 4) {
                    if profile.isPremium {
                        Text("⭐️")
                    }
                    Text(profile.plan.displayName)
                }
            }

            if let expiresAt = profile.planExpiresAt {
                LabeledContent("Expires", value: formatProfileDate(expiresAt))
            }

            if !profile.isPremium {
                UpgradePremiumButton()
            }
        }
    }
}
